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

func NewAIService(
	insightRepo ports.AIInsightRepository,
	taskRepo ports.TaskRepository,
	pomodoroRepo ports.PomodoroRepository,
	llm ports.LLMProvider,
	mlServiceURL string,
) *AIService {
	return &AIService{
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
		Categories:  make(map[string]int),
		SessionHours: make(map[int]int),
		StatsWindow: days,
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

// ---------- public methods ----------

func (s *AIService) GenerateDailyTip(ctx context.Context, userID string) (*domain.AIInsight, error) {
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

func (s *AIService) ProductivityPrediction(ctx context.Context, userID string) map[string]any {
	summary, err := s.buildDataSummary(ctx, userID, 14)
	if err != nil {
		return s.fallbackPrediction()
	}

	userPrompt := fmt.Sprintf("Datos recientes (14 días):\n%s\n\nHoy es %s. Predice la productividad.",
		summaryToPromptContext(summary), time.Now().Format("Monday"))

	content, err := s.llm.Generate(ctx, systemPrediction, userPrompt)
	if err != nil || content == "" {
		return s.fallbackPrediction()
	}

	var result map[string]any
	if err := json.Unmarshal([]byte(extractJSON(content)), &result); err != nil {
		return s.fallbackPrediction()
	}
	result["source"] = "gemini"
	return result
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

func (s *AIService) BurnoutRisk(ctx context.Context, userID string) map[string]any {
	summary, err := s.buildDataSummary(ctx, userID, 30)
	if err != nil {
		return s.fallbackBurnout()
	}

	userPrompt := fmt.Sprintf("Datos del último mes:\n%s\n\nEvalúa el riesgo de burnout.", summaryToPromptContext(summary))

	content, err := s.llm.Generate(ctx, systemBurnout, userPrompt)
	if err != nil || content == "" {
		return s.fallbackBurnout()
	}

	var result map[string]any
	if err := json.Unmarshal([]byte(extractJSON(content)), &result); err != nil {
		return s.fallbackBurnout()
	}
	result["source"] = "gemini"
	return result
}

func (s *AIService) OptimalHours(ctx context.Context, userID string) map[string]any {
	summary, err := s.buildDataSummary(ctx, userID, 30)
	if err != nil {
		return s.fallbackOptimalHours()
	}

	userPrompt := fmt.Sprintf("Datos del último mes (distribución de sesiones por hora):\n%s\n\nIdentifica las horas más productivas.",
		summaryToPromptContext(summary))

	content, err := s.llm.Generate(ctx, systemOptimalHours, userPrompt)
	if err != nil || content == "" {
		return s.fallbackOptimalHours()
	}

	var result map[string]any
	if err := json.Unmarshal([]byte(extractJSON(content)), &result); err != nil {
		return s.fallbackOptimalHours()
	}
	result["source"] = "gemini"
	return result
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
