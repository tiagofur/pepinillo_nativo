package services

import (
	"context"
	"time"

	"pepinillo/backend/internal/domain"
	"pepinillo/backend/internal/ports"
)

type AnalyticsService struct {
	repo ports.AnalyticsRepository
}

func NewAnalyticsService(repo ports.AnalyticsRepository) *AnalyticsService {
	return &AnalyticsService{repo: repo}
}

func (s *AnalyticsService) GenerateWeeklyReport(ctx context.Context, userID string, weekStart, weekEnd time.Time) (*domain.WeeklyReport, error) {
	return s.repo.GenerateWeeklyReport(ctx, userID, weekStart, weekEnd)
}

func (s *AnalyticsService) GenerateMonthlyReport(ctx context.Context, userID string, monthStart, monthEnd time.Time) (*domain.MonthlyReport, error) {
	return s.repo.GenerateMonthlyReport(ctx, userID, monthStart, monthEnd)
}

func (s *AnalyticsService) GetCompletionRate(ctx context.Context, userID string, periodStart, periodEnd time.Time) (*domain.CompletionRateStats, error) {
	return s.repo.GetCompletionRate(ctx, userID, periodStart, periodEnd)
}

func (s *AnalyticsService) GetStreakStats(ctx context.Context, userID string) (*domain.StreakStats, error) {
	return s.repo.GetStreakStats(ctx, userID)
}
