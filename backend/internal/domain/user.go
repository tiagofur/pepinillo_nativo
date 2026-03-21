package domain

import "time"

type User struct {
	ID                    string     `json:"id" gorm:"type:uuid;primaryKey"`
	Email                 string     `json:"email" gorm:"uniqueIndex;not null"`
	Name                  string     `json:"name" gorm:"not null"`
	PasswordHash          *string    `json:"-"`
	ImageURL              *string    `json:"imageUrl"`
	BirthDate             *time.Time `json:"birthDate"`
	SubscriptionTier      string     `json:"subscriptionTier" gorm:"default:free;not null"`
	SubscriptionExpiresAt *time.Time `json:"subscriptionExpiresAt"`
	EmailVerified         bool       `json:"emailVerified" gorm:"default:false;not null"`
	EmailVerifiedAt       *time.Time `json:"emailVerifiedAt"`
	PendingEmail          *string    `json:"pendingEmail,omitempty" gorm:"index"`
	EmailChangedAt        *time.Time `json:"emailChangedAt,omitempty"`

	// Google OAuth
	GoogleID      *string `json:"googleId,omitempty" gorm:"uniqueIndex"`
	GoogleEmail   *string `json:"googleEmail,omitempty"`
	GoogleName    *string `json:"googleName,omitempty"`
	GooglePicture *string `json:"googlePicture,omitempty"`

	// Apple OAuth
	AppleID    *string `json:"appleId,omitempty" gorm:"uniqueIndex"`
	AppleEmail *string `json:"appleEmail,omitempty"`
	AppleName  *string `json:"appleName,omitempty"`

	CreatedAt time.Time `json:"createdAt"`
	UpdatedAt time.Time `json:"updatedAt"`
}
