package postgres

import (
	"context"

	"gorm.io/gorm"

	"pepinillo/backend/internal/domain"
)

type AIInsightRepository struct {
	db *gorm.DB
}

func NewAIInsightRepository(db *gorm.DB) *AIInsightRepository {
	return &AIInsightRepository{db: db}
}

func (r *AIInsightRepository) Create(ctx context.Context, insight *domain.AIInsight) error {
	return r.db.WithContext(ctx).Create(insight).Error
}

func (r *AIInsightRepository) ListByUser(ctx context.Context, userID string, limit, offset int) ([]domain.AIInsight, error) {
	var insights []domain.AIInsight
	err := r.db.WithContext(ctx).
		Where("user_id = ?", userID).
		Order("generated_at DESC").
		Limit(limit).
		Offset(offset).
		Find(&insights).Error
	if err != nil {
		return nil, err
	}
	return insights, nil
}
