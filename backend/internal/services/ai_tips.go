package services

// Issue #995: mechanical split of ai_service.go (verbatim moves, no
// behavior change). The daily-tip pipeline with its access gate, the
// credit-refund LLM runner and the contextual fallback tip.

import (
	"context"
	"encoding/json"
	"fmt"
	"strings"
	"time"

	"pepinillo/backend/internal/domain"
)

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

	content, err := s.generateWithRefund(ctx, userID, systemDailyTip, userPrompt)
	if err != nil {
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

// generateWithRefund runs the LLM and refunds the credit spent by
// ensureAiAccess when generation itself produced nothing (A5). Callers then
// build their (free) fallbacks as before. A successful generation — even a
// thin one — keeps the charge.
func (s *AIService) generateWithRefund(ctx context.Context, userID, system, user string) (string, error) {
	content, err := s.llm.Generate(ctx, system, user)
	if err != nil || strings.TrimSpace(content) == "" {
		_ = s.users.RefundAiCredit(ctx, userID)
		if err == nil {
			err = ErrAIGenerationFailed
		}
		return "", err
	}
	return content, nil
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
