package services

import (
	"bytes"
	"context"
	"encoding/json"
	"fmt"
	"net/http"
	"strings"
	"time"

	"pepinillo/backend/internal/domain"
	"pepinillo/backend/internal/ports"
)

type AIService struct {
	users        ports.UserRepository
	insightRepo  ports.AIInsightRepository
	taskRepo     ports.TaskRepository
	pomodoroRepo ports.PomodoroRepository
	llm          ports.LLMProvider
	mlServiceURL string
	httpClient   *http.Client
}

type AnalyzeInput struct {
	Days    int    `json:"days"`
	Context string `json:"context"`
}

// ReportPayload mirrors the Android ReportPayload contract sent to POST /ai/report
// (see android .../domain/report/ReportDataBuilder.kt). The client builds it
// on-device from local focus sessions and posts it for server-side LLM enrichment.
type ReportPayload struct {
	Period            string                         `json:"period"`
	PeriodStart       string                         `json:"periodStart"`
	PeriodEnd         string                         `json:"periodEnd"`
	Summary           ReportSummary                  `json:"summary"`
	Trends            ReportTrends                   `json:"trends"`
	Patterns          ReportPatterns                 `json:"patterns"`
	TaskBreakdown     []ReportTaskBreakdownEntry     `json:"taskBreakdown"`
	DailyDistribution []ReportDailyDistributionEntry `json:"dailyDistribution"`
}

type ReportSummary struct {
	TotalMinutes       int `json:"totalMinutes"`
	TotalSessions      int `json:"totalSessions"`
	CompletedSessions  int `json:"completedSessions"`
	AvgSessionMinutes  int `json:"avgSessionMinutes"`
	TotalInterruptions int `json:"totalInterruptions"`
	TotalPauses        int `json:"totalPauses"`
}

type ReportTrends struct {
	MinutesChange         int `json:"minutesChange"`
	SessionsChange        int `json:"sessionsChange"`
	PreviousTotalMinutes  int `json:"previousTotalMinutes"`
	PreviousTotalSessions int `json:"previousTotalSessions"`
}

type ReportPatterns struct {
	DominantMode    string         `json:"dominantMode"`
	PeakHourRange   string         `json:"peakHourRange"`
	BestDayOfWeek   string         `json:"bestDayOfWeek"`
	ModeDistribution map[string]int `json:"modeDistribution"`
}

type ReportTaskBreakdownEntry struct {
	TaskID       string `json:"taskId"`
	TotalMinutes int    `json:"totalMinutes"`
	Sessions     int    `json:"sessions"`
}

type ReportDailyDistributionEntry struct {
	DayLabel string `json:"dayLabel"`
	Minutes  int    `json:"minutes"`
	Sessions int    `json:"sessions"`
}

// AIReportResponse mirrors the Android AIReportResponse contract expected from
// POST /ai/report (see android .../core/network/ApiModels.kt).
type AIReportResponse struct {
	Title           string          `json:"title"`
	Highlights      []string        `json:"highlights"`
	Insights        []ReportInsight `json:"insights"`
	Recommendations []string        `json:"recommendations"`
}

type ReportInsight struct {
	Category string `json:"category"`
	Text     string `json:"text"`
}

func NewAIService(
	users ports.UserRepository,
	insightRepo ports.AIInsightRepository,
	taskRepo ports.TaskRepository,
	pomodoroRepo ports.PomodoroRepository,
	llm ports.LLMProvider,
	mlServiceURL string,
) *AIService {
	return &AIService{
		users:        users,
		insightRepo:  insightRepo,
		taskRepo:     taskRepo,
		pomodoroRepo: pomodoroRepo,
		llm:          llm,
		mlServiceURL: strings.TrimSuffix(mlServiceURL, "/"),
		httpClient:   &http.Client{Timeout: 5 * time.Second},
	}
}

func (s *AIService) ListInsights(ctx context.Context, userID string, limit, offset int) ([]domain.AIInsight, error) {
	return s.insightRepo.ListByUser(ctx, userID, limit, offset)
}

func (s *AIService) GenerateWeeklyReport(ctx context.Context, userID string) (*domain.AIInsight, error) {
	if err := s.ensureAiAccess(ctx, userID); err != nil {
		return nil, err
	}

	summary, err := s.buildDataSummary(ctx, userID, 7)
	if err != nil {
		return nil, err
	}

	userPrompt := fmt.Sprintf("Datos de la semana:\n%s\n\nGenera el reporte semanal.", summaryToPromptContext(summary))

	content, err := s.generateWithRefund(ctx, userID, systemWeeklyReport, userPrompt)
	if err != nil {
		content = fmt.Sprintf("Esta semana completaste %d pomodoros con %d minutos de enfoque. %d de %d tareas fueron completadas. Mantén la constancia.",
			summary.TotalPomodoros, summary.TotalFocusMin, summary.CompletedTasks, summary.TotalTasks)
	}

	source := "gemini"
	if err != nil || content == "" {
		source = "fallback"
	}
	dataMap := map[string]any{"source": source, "window": "7d", "summary": summary}
	jsonData, _ := json.Marshal(dataMap)
	now := time.Now().UTC()

	insight := &domain.AIInsight{
		UserID:      userID,
		Type:        "weekly_report",
		Title:       "Reporte semanal",
		Content:     content,
		DataJSON:    string(jsonData),
		GeneratedAt: now,
		ExpiresAt:   ptrTime(now.Add(7 * 24 * time.Hour)),
	}
	if err := s.insightRepo.Create(ctx, insight); err != nil {
		return nil, err
	}
	return insight, nil
}

func (s *AIService) Analyze(ctx context.Context, userID string, input AnalyzeInput) (*domain.AIInsight, error) {
	if err := s.ensureAiAccess(ctx, userID); err != nil {
		return nil, err
	}

	if input.Days <= 0 {
		input.Days = 30
	}
	// A7: cap the analysis window — buildDataSummary fans out per day.
	if input.Days > 365 {
		input.Days = 365
	}
	// A7: cap + delimit free-form user context. Unbounded Context becomes
	// LLM prompt tokens under flat 1-credit pricing, and raw interpolation
	// mixes untrusted content into the instruction stream.
	input.Context = truncateRunes(strings.TrimSpace(input.Context), maxAnalyzeContextRunes)

	summary, err := s.buildDataSummary(ctx, userID, input.Days)
	if err != nil {
		return nil, err
	}

	userPrompt := fmt.Sprintf("Datos del usuario (últimos %d días):\n%s", input.Days, summaryToPromptContext(summary))
	if input.Context != "" {
		userPrompt += fmt.Sprintf("\n\n<user_context>\n%s\n</user_context>", input.Context)
	}
	userPrompt += "\n\nRealiza el análisis."

	content, err := s.generateWithRefund(ctx, userID, systemAnalyze, userPrompt)
	if err != nil {
		content = fmt.Sprintf("En los últimos %d días: %d pomodoros, %d min de enfoque, %d tareas completadas de %d. Promedio: %.1f pomodoros/día activo.",
			input.Days, summary.TotalPomodoros, summary.TotalFocusMin, summary.CompletedTasks, summary.TotalTasks, summary.AvgPomPerDay)
	}

	source := "gemini"
	if err != nil {
		source = "fallback"
	}
	dataMap := map[string]any{"source": source, "days": input.Days, "context": input.Context, "summary": summary}
	jsonData, _ := json.Marshal(dataMap)
	now := time.Now().UTC()

	insight := &domain.AIInsight{
		UserID:      userID,
		Type:        "analysis",
		Title:       "Análisis personalizado",
		Content:     content,
		DataJSON:    string(jsonData),
		GeneratedAt: now,
		ExpiresAt:   ptrTime(now.Add(48 * time.Hour)),
	}
	if err := s.insightRepo.Create(ctx, insight); err != nil {
		return nil, err
	}
	return insight, nil
}

// A7 cost/injection caps for AI prompt construction.
const (
	// maxAnalyzeContextRunes bounds free-form user context (~0.5k tokens).
	maxAnalyzeContextRunes = 2000
	// maxReportPayloadRunes bounds the client-built report JSON (~3k tokens).
	maxReportPayloadRunes = 12000
)

// truncateRunes cuts s to at most max runes (rune-aware: never splits UTF-8).
func truncateRunes(s string, max int) string {
	if max <= 0 {
		return ""
	}
	runes := []rune(s)
	if len(runes) <= max {
		return s
	}
	return string(runes[:max]) + "\n[truncated]"
}

// Report generates a structured AIReportResponse for the POST /ai/report route.
// It reuses the same credit gating (ensureAiAccess) and LLM provider as the
// other AI endpoints, but operates on the client-supplied ReportPayload rather
// than server-side repository data. Falls back to a deterministic template when
// the LLM is unavailable so the Android client always gets a valid response.
func (s *AIService) Report(ctx context.Context, userID string, payload ReportPayload) (*AIReportResponse, error) {
	if err := s.ensureAiAccess(ctx, userID); err != nil {
		return nil, err
	}

	payloadJSON, _ := json.MarshalIndent(payload, "", "  ")
	// A7: the client builds this payload on-device (arrays unbounded). Cap
	// what enters the prompt — and the flat 1-credit price — with truncation.
	payloadText := truncateRunes(string(payloadJSON), maxReportPayloadRunes)
	userPrompt := fmt.Sprintf("Datos del reporte (periodo: %s, %s a %s):\n<report_data>\n%s\n</report_data>\n\nGenera el reporte estructurado.",
		payload.Period, payload.PeriodStart, payload.PeriodEnd, payloadText)

	content, err := s.generateWithRefund(ctx, userID, systemReport, userPrompt)
	if err != nil {
		return s.fallbackReport(payload), nil
	}

	var result AIReportResponse
	if err := json.Unmarshal([]byte(extractJSON(content)), &result); err != nil {
		// Malformed model output delivers no AI value: refund like a failure.
		_ = s.users.RefundAiCredit(ctx, userID)
		return s.fallbackReport(payload), nil
	}
	if result.Title == "" {
		result.Title = fmt.Sprintf("Reporte %s", payload.Period)
	}
	if result.Highlights == nil {
		result.Highlights = []string{}
	}
	if result.Insights == nil {
		result.Insights = []ReportInsight{}
	}
	if result.Recommendations == nil {
		result.Recommendations = []string{}
	}
	return &result, nil
}

// fallbackReport produces a deterministic AIReportResponse when the LLM cannot
// be reached, so the Android client always receives a well-formed payload.
func (s *AIService) fallbackReport(payload ReportPayload) *AIReportResponse {
	periodLabel := payload.Period
	if periodLabel == "" {
		periodLabel = "periodo"
	}
	hours := payload.Summary.TotalMinutes / 60
	mins := payload.Summary.TotalMinutes % 60

	highlights := []string{
		fmt.Sprintf("%d sesión(es) completada(s) de %d", payload.Summary.CompletedSessions, payload.Summary.TotalSessions),
		fmt.Sprintf("%d h %d min de enfoque total", hours, mins),
	}
	if payload.Trends.MinutesChange != 0 {
		sign := "+"
		if payload.Trends.MinutesChange < 0 {
			sign = ""
		}
		highlights = append(highlights, fmt.Sprintf("Cambio vs. periodo anterior: %s%d min", sign, payload.Trends.MinutesChange))
	}

	insights := []ReportInsight{
		{
			Category: "constancia",
			Text:     fmt.Sprintf("Completaste %d de %d sesiones iniciadas este %s.", payload.Summary.CompletedSessions, payload.Summary.TotalSessions, periodLabel),
		},
	}
	if payload.Patterns.BestDayOfWeek != "" {
		insights = append(insights, ReportInsight{
			Category: "patrones",
			Text:     fmt.Sprintf("Tu día más productivo fue %s.", payload.Patterns.BestDayOfWeek),
		})
	}

	recommendations := []string{
		"Mantén bloques de enfoque consistentes en tus horas pico.",
		"Revisa las tareas con menos avance y priorízalas en el próximo periodo.",
	}

	return &AIReportResponse{
		Title:           fmt.Sprintf("Reporte %s", periodLabel),
		Highlights:      highlights,
		Insights:        insights,
		Recommendations: recommendations,
	}
}

func (s *AIService) ProductivityPrediction(ctx context.Context, userID string) (map[string]any, error) {
	if err := s.ensureAiAccess(ctx, userID); err != nil {
		return nil, err
	}

	summary, err := s.buildDataSummary(ctx, userID, 14)
	if err != nil {
		return s.fallbackPrediction(), nil
	}

	userPrompt := fmt.Sprintf("Datos recientes (14 días):\n%s\n\nHoy es %s. Predice la productividad.",
		summaryToPromptContext(summary), time.Now().Format("Monday"))

	content, err := s.generateWithRefund(ctx, userID, systemPrediction, userPrompt)
	if err != nil {
		return s.fallbackPrediction(), nil
	}

	var result map[string]any
	if err := json.Unmarshal([]byte(extractJSON(content)), &result); err != nil {
		_ = s.users.RefundAiCredit(ctx, userID)
		return s.fallbackPrediction(), nil
	}
	result["source"] = "gemini"
	return result, nil
}

func (s *AIService) ProductivityPredictionFromML(ctx context.Context, weekday int, recentFocusMinutes float64, streakDays int) map[string]any {
	body := map[string]any{
		"weekday":              weekday,
		"recent_focus_minutes": recentFocusMinutes,
		"streak_days":          streakDays,
	}
	jsonBody, err := json.Marshal(body)
	if err != nil {
		return s.fallbackPrediction()
	}
	endpoint := s.mlServiceURL + "/predict/productivity"
	req, err := http.NewRequestWithContext(ctx, http.MethodPost, endpoint, bytes.NewReader(jsonBody))
	if err != nil {
		return s.fallbackPrediction()
	}
	req.Header.Set("Content-Type", "application/json")
	resp, err := s.httpClient.Do(req)
	if err != nil {
		return s.fallbackPrediction()
	}
	defer resp.Body.Close()
	if resp.StatusCode < 200 || resp.StatusCode >= 300 {
		return s.fallbackPrediction()
	}
	var payload map[string]any
	if err := json.NewDecoder(resp.Body).Decode(&payload); err != nil {
		return s.fallbackPrediction()
	}
	payload["source"] = "ml-service"
	return payload
}

func (s *AIService) BurnoutRisk(ctx context.Context, userID string) (map[string]any, error) {
	if err := s.ensureAiAccess(ctx, userID); err != nil {
		return nil, err
	}

	summary, err := s.buildDataSummary(ctx, userID, 30)
	if err != nil {
		return s.fallbackBurnout(), nil
	}

	userPrompt := fmt.Sprintf("Datos del último mes:\n%s\n\nEvalúa el riesgo de burnout.", summaryToPromptContext(summary))

	content, err := s.generateWithRefund(ctx, userID, systemBurnout, userPrompt)
	if err != nil {
		return s.fallbackBurnout(), nil
	}

	var result map[string]any
	if err := json.Unmarshal([]byte(extractJSON(content)), &result); err != nil {
		_ = s.users.RefundAiCredit(ctx, userID)
		return s.fallbackBurnout(), nil
	}
	result["source"] = "gemini"
	return result, nil
}

func (s *AIService) OptimalHours(ctx context.Context, userID string) (map[string]any, error) {
	if err := s.ensureAiAccess(ctx, userID); err != nil {
		return nil, err
	}

	summary, err := s.buildDataSummary(ctx, userID, 30)
	if err != nil {
		return s.fallbackOptimalHours(), nil
	}

	userPrompt := fmt.Sprintf("Datos del último mes (distribución de sesiones por hora):\n%s\n\nIdentifica las horas más productivas.",
		summaryToPromptContext(summary))

	content, err := s.generateWithRefund(ctx, userID, systemOptimalHours, userPrompt)
	if err != nil {
		return s.fallbackOptimalHours(), nil
	}

	var result map[string]any
	if err := json.Unmarshal([]byte(extractJSON(content)), &result); err != nil {
		_ = s.users.RefundAiCredit(ctx, userID)
		return s.fallbackOptimalHours(), nil
	}
	result["source"] = "gemini"
	return result, nil
}

// ---------- fallbacks ----------

func (s *AIService) fallbackPrediction() map[string]any {
	return map[string]any{
		"level":        "medium",
		"focusMinutes": 110,
		"confidence":   0.4,
		"source":       "fallback",
		"reasoning":    "Sin datos suficientes de Gemini. Estimación por defecto.",
	}
}

func (s *AIService) fallbackBurnout() map[string]any {
	return map[string]any{
		"risk":           "unknown",
		"score":          0.0,
		"factors":        []string{"insufficient_data"},
		"source":         "fallback",
		"recommendation": "No hay datos suficientes para evaluar. Sigue usando la app para obtener un análisis real.",
	}
}

func (s *AIService) fallbackOptimalHours() map[string]any {
	return map[string]any{
		"hours":      []string{"09:00", "10:00", "11:00"},
		"confidence": 0.3,
		"source":     "fallback",
		"reasoning":  "Estimación genérica. Usa la app más días para obtener horas reales.",
	}
}

// ---------- utilities ----------

// extractJSON tries to find a JSON object in a string (Gemini sometimes wraps in markdown).
func extractJSON(s string) string {
	start := strings.Index(s, "{")
	end := strings.LastIndex(s, "}")
	if start >= 0 && end > start {
		return s[start : end+1]
	}
	return s
}

func ptrTime(v time.Time) *time.Time {
	return &v
}
