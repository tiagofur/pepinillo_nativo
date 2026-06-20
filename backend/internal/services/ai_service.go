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

// ---------- helpers to gather user data ----------

func (s *AIService) gatherRecentStats(ctx context.Context, userID string, days int) ([]domain.PomodoroStats, error) {
	to := time.Now().UTC()
	from := to.AddDate(0, 0, -days)
	return s.pomodoroRepo.ListStatsByRange(ctx, userID, from, to)
}

func (s *AIService) gatherRecentSessions(ctx context.Context, userID string, days int) ([]domain.PomodoroSession, error) {
	to := time.Now().UTC()
	from := to.AddDate(0, 0, -days)
	return s.pomodoroRepo.ListSessionsByRange(ctx, userID, from, to)
}

func (s *AIService) gatherTasks(ctx context.Context, userID string) ([]domain.Task, error) {
	return s.taskRepo.ListByUser(ctx, userID)
}

type userDataSummary struct {
	TotalTasks       int            `json:"totalTasks"`
	CompletedTasks   int            `json:"completedTasks"`
	PendingTasks     int            `json:"pendingTasks"`
	OverdueTasks     int            `json:"overdueTasks"`
	Categories       map[string]int `json:"categories"`
	StatsWindow      int            `json:"statsWindowDays"`
	TotalPomodoros   int            `json:"totalPomodoros"`
	TotalFocusMin    int            `json:"totalFocusMinutes"`
	TotalBreaks      int            `json:"totalBreaks"`
	DaysWithActivity int            `json:"daysWithActivity"`
	AvgPomPerDay     float64        `json:"avgPomodorosPerDay"`
	SessionCount     int            `json:"sessionCount"`
	CompletedSess    int            `json:"completedSessions"`
	SessionHours     map[int]int    `json:"sessionsByHour"` // hour -> count
}

func (s *AIService) buildDataSummary(ctx context.Context, userID string, days int) (*userDataSummary, error) {
	tasks, err := s.gatherTasks(ctx, userID)
	if err != nil {
		return nil, err
	}
	stats, err := s.gatherRecentStats(ctx, userID, days)
	if err != nil {
		return nil, err
	}
	sessions, err := s.gatherRecentSessions(ctx, userID, days)
	if err != nil {
		return nil, err
	}

	now := time.Now().UTC()
	summary := &userDataSummary{
		Categories:   make(map[string]int),
		SessionHours: make(map[int]int),
		StatsWindow:  days,
	}

	for _, t := range tasks {
		if t.IsDeleted {
			continue
		}
		summary.TotalTasks++
		if t.IsFinished {
			summary.CompletedTasks++
		} else {
			summary.PendingTasks++
			if t.FinishDate != nil && t.FinishDate.Before(now) {
				summary.OverdueTasks++
			}
		}
		cat := "sin categoría"
		if t.Category != nil && *t.Category != "" {
			cat = *t.Category
		}
		summary.Categories[cat]++
	}

	for _, st := range stats {
		summary.TotalPomodoros += st.Pomodoros
		summary.TotalFocusMin += st.PomodoroDuration / 60
		summary.TotalBreaks += st.Breaks
		if st.Pomodoros > 0 {
			summary.DaysWithActivity++
		}
	}
	if summary.DaysWithActivity > 0 {
		summary.AvgPomPerDay = float64(summary.TotalPomodoros) / float64(summary.DaysWithActivity)
	}

	for _, sess := range sessions {
		summary.SessionCount++
		if sess.WasCompleted {
			summary.CompletedSess++
		}
		summary.SessionHours[sess.StartedAt.Hour()]++
	}

	return summary, nil
}

func summaryToPromptContext(s *userDataSummary) string {
	b, _ := json.MarshalIndent(s, "", "  ")
	return string(b)
}

// ---------- system prompts ----------

const systemPromptBase = `Eres un coach de productividad experto integrado en la app Pepinillo (timer Pomodoro + gestión de tareas).
Responde SIEMPRE en español. Sé conciso, accionable y empático.
Basa tus recomendaciones en los datos reales del usuario que se te proporcionan.
Si los datos son insuficientes para una conclusión, dilo honestamente.
Formato: texto plano, usa viñetas para listas. No uses markdown headers.`

const systemDailyTip = systemPromptBase + `
Tu tarea: genera UN tip de productividad personalizado para hoy basado en los datos recientes del usuario.
El tip debe ser específico y accionable (no genérico). Máximo 3 oraciones.`

const systemWeeklyReport = systemPromptBase + `
Tu tarea: genera un resumen semanal de productividad. Incluye:
- Resumen de actividad (pomodoros, tiempo de enfoque, tareas completadas)
- Lo que salió bien
- Área de oportunidad
- Un consejo concreto para la próxima semana
Máximo 200 palabras.`

const systemAnalyze = systemPromptBase + `
Tu tarea: realiza un análisis profundo de productividad basado en los datos proporcionados. Incluye:
- Patrones identificados (horas productivas, días fuertes, ritmo de trabajo)
- Análisis de completación de tareas y uso del método Pomodoro
- Riesgos (sobrecarga, inconsistencia, tareas atrasadas)
- 3 recomendaciones priorizadas
Máximo 400 palabras.`

const systemBurnout = systemPromptBase + `
Tu tarea: evalúa el riesgo de burnout del usuario basado en sus patrones de trabajo.
Devuelve un JSON con esta estructura exacta (sin texto adicional):
{"risk": "low|medium|high", "score": 0.0-1.0, "factors": ["factor1", "factor2"], "recommendation": "texto breve"}`

const systemOptimalHours = systemPromptBase + `
Tu tarea: identifica las horas más productivas del usuario basado en sus sesiones.
Devuelve un JSON con esta estructura exacta (sin texto adicional):
{"hours": ["HH:MM", "HH:MM", "HH:MM"], "confidence": 0.0-1.0, "reasoning": "explicación breve"}`

const systemPrediction = systemPromptBase + `
Tu tarea: predice la productividad del usuario para hoy basado en su historial.
Devuelve un JSON con esta estructura exacta (sin texto adicional):
{"level": "low|medium|high", "focusMinutes": N, "confidence": 0.0-1.0, "reasoning": "explicación breve"}`

const systemReport = systemPromptBase + `
Tu tarea: genera un reporte de productividad estructurado basado en los datos del periodo que te proporciona el usuario (resumen, tendencias, patrones, desglose por tarea y distribución diaria).
Devuelve un JSON con esta estructura exacta (sin texto adicional):
{"title": "string", "highlights": ["string"], "insights": [{"category": "string", "text": "string"}], "recommendations": ["string"]}`

// ---------- public methods ----------

func (s *AIService) GenerateDailyTip(ctx context.Context, userID string) (*domain.AIInsight, error) {
	if err := s.ensureAiAccess(ctx, userID); err != nil {
		return nil, err
	}

	summary, err := s.buildDataSummary(ctx, userID, 7)
	if err != nil {
		return nil, err
	}

	userPrompt := fmt.Sprintf("Datos del usuario (últimos %d días):\n%s\n\nGenera el tip de hoy.", summary.StatsWindow, summaryToPromptContext(summary))

	content, err := s.llm.Generate(ctx, systemDailyTip, userPrompt)
	if err != nil || content == "" {
		// Fallback to contextual stub
		content = s.buildFallbackTip(summary)
	}

	dataMap := map[string]any{"source": "gemini", "window": "7d", "summary": summary}
	if strings.Contains(content, "datos insuficientes") || content == s.buildFallbackTip(summary) {
		dataMap["source"] = "fallback"
	}
	jsonData, _ := json.Marshal(dataMap)
	now := time.Now().UTC()

	insight := &domain.AIInsight{
		UserID:      userID,
		Type:        "tip",
		Title:       "Tip del día",
		Content:     content,
		DataJSON:    string(jsonData),
		GeneratedAt: now,
		ExpiresAt:   ptrTime(now.Add(24 * time.Hour)),
	}
	if err := s.insightRepo.Create(ctx, insight); err != nil {
		return nil, err
	}
	return insight, nil
}

func (s *AIService) ensureAiAccess(ctx context.Context, userID string) error {
	user, err := s.users.GetByID(ctx, userID)
	if err != nil {
		return err
	}
	if user == nil {
		return ErrUserNotFound
	}

	tier := EffectiveTier(user)
	isEverywhere := tier == "everywhere_monthly" || tier == "everywhere_annual"

	if !isEverywhere {
		return ErrTierInsufficientForCloudAI
	}

	// Monthly credit refresh (100 credits)
	now := time.Now().UTC()
	shouldRefresh := user.AiCreditsLastRefreshedAt == nil || now.After(user.AiCreditsLastRefreshedAt.AddDate(0, 1, 0))

	if shouldRefresh {
		if err := s.users.RefreshAiCredits(ctx, userID, 100); err != nil {
			return err
		}
	}

	// Consume 1 credit
	ok, err := s.users.ConsumeAiCredit(ctx, userID)
	if err != nil {
		return err
	}
	if !ok {
		return ErrInsufficientAICredits
	}

	return nil
}

func (s *AIService) buildFallbackTip(summary *userDataSummary) string {
	if summary.OverdueTasks > 0 {
		return fmt.Sprintf("Tienes %d tarea(s) atrasada(s). Prioriza las más importantes y dedica el primer pomodoro del día a avanzar en ellas.", summary.OverdueTasks)
	}
	if summary.AvgPomPerDay < 2 {
		return "Tu promedio de pomodoros diarios es bajo. Intenta completar al menos 4 pomodoros hoy enfocándote en una sola tarea a la vez."
	}
	return "Planifica primero tus 3 tareas más importantes y bloquéalas en tus horas de mayor energía."
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

	content, err := s.llm.Generate(ctx, systemWeeklyReport, userPrompt)
	if err != nil || content == "" {
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

	summary, err := s.buildDataSummary(ctx, userID, input.Days)
	if err != nil {
		return nil, err
	}

	userPrompt := fmt.Sprintf("Datos del usuario (últimos %d días):\n%s", input.Days, summaryToPromptContext(summary))
	if input.Context != "" {
		userPrompt += fmt.Sprintf("\n\nContexto adicional del usuario: %s", input.Context)
	}
	userPrompt += "\n\nRealiza el análisis."

	content, err := s.llm.Generate(ctx, systemAnalyze, userPrompt)
	if err != nil || content == "" {
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
	userPrompt := fmt.Sprintf("Datos del reporte (periodo: %s, %s a %s):\n%s\n\nGenera el reporte estructurado.",
		payload.Period, payload.PeriodStart, payload.PeriodEnd, string(payloadJSON))

	content, err := s.llm.Generate(ctx, systemReport, userPrompt)
	if err != nil || content == "" {
		return s.fallbackReport(payload), nil
	}

	var result AIReportResponse
	if err := json.Unmarshal([]byte(extractJSON(content)), &result); err != nil {
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

	content, err := s.llm.Generate(ctx, systemPrediction, userPrompt)
	if err != nil || content == "" {
		return s.fallbackPrediction(), nil
	}

	var result map[string]any
	if err := json.Unmarshal([]byte(extractJSON(content)), &result); err != nil {
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

	content, err := s.llm.Generate(ctx, systemBurnout, userPrompt)
	if err != nil || content == "" {
		return s.fallbackBurnout(), nil
	}

	var result map[string]any
	if err := json.Unmarshal([]byte(extractJSON(content)), &result); err != nil {
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

	content, err := s.llm.Generate(ctx, systemOptimalHours, userPrompt)
	if err != nil || content == "" {
		return s.fallbackOptimalHours(), nil
	}

	var result map[string]any
	if err := json.Unmarshal([]byte(extractJSON(content)), &result); err != nil {
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
