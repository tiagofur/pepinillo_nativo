package services

import (
	"context"
	"encoding/json"
	"errors"
	"fmt"
	"strconv"
	"strings"
	"sync"
	"time"

	"github.com/google/uuid"

	"pepinillo/backend/internal/domain"
	"pepinillo/backend/internal/ports"
)

type TaskService struct {
	repo           ports.TaskRepository
	behaviorLogger ports.BehaviorLogger
	wsManager      ports.WebSocketManager
	generationMu   sync.Mutex
	activeWindows  map[string]struct{}
}

var ErrRecurrenceWindowInProgress = errors.New("recurrence_window_in_progress")

const recurrenceWindowLockTTL = 10 * time.Minute

type UserRecurrenceGeneration struct {
	UserID  string
	Created int
}

func NewTaskService(repo ports.TaskRepository, behaviorLogger ports.BehaviorLogger, wsManager ports.WebSocketManager) *TaskService {
	return &TaskService{
		repo:           repo,
		behaviorLogger: behaviorLogger,
		wsManager:      wsManager,
		activeWindows:  map[string]struct{}{},
	}
}

func (s *TaskService) ListByUser(ctx context.Context, userID string) ([]domain.Task, error) {
	return s.repo.ListByUser(ctx, userID)
}

func (s *TaskService) ListByFinishDate(ctx context.Context, userID string, date time.Time) ([]domain.Task, error) {
	return s.repo.ListByFinishDate(ctx, userID, date)
}

func (s *TaskService) ListRecurrences(ctx context.Context, userID string, from, to *time.Time) ([]domain.Task, error) {
	items, err := s.repo.ListByUser(ctx, userID)
	if err != nil {
		return nil, err
	}

	filtered := make([]domain.Task, 0)
	for _, item := range items {
		if item.IsDeleted || item.RecurrenceRule == nil || strings.TrimSpace(*item.RecurrenceRule) == "" {
			continue
		}

		if from != nil && item.FinishDate != nil && item.FinishDate.Before(from.UTC()) {
			continue
		}
		if to != nil && item.CreatedDate != nil && item.CreatedDate.After(to.UTC()) {
			continue
		}

		filtered = append(filtered, item)
	}
	return filtered, nil
}

func (s *TaskService) GenerateRecurrences(ctx context.Context, userID string, from, to time.Time) ([]domain.Task, error) {
	rangeStart := dayStartUTC(from)
	rangeEnd := dayStartUTC(to)
	if rangeEnd.Before(rangeStart) {
		return nil, fmt.Errorf("invalid_date_range")
	}
	if rangeEnd.Sub(rangeStart) > 370*24*time.Hour {
		return nil, fmt.Errorf("date_range_too_large")
	}

	windowKey := recurrenceDedupKey(userID, rangeStart) + "->" + rangeEnd.Format("2006-01-02")
	lockOwnerID, lockErr := s.tryBeginWindow(ctx, windowKey)
	if lockErr != nil {
		return nil, lockErr
	}
	if lockOwnerID == "" {
		return nil, ErrRecurrenceWindowInProgress
	}
	defer s.endWindow(ctx, windowKey, lockOwnerID)

	items, err := s.repo.ListByUser(ctx, userID)
	if err != nil {
		return nil, err
	}

	existingByTemplateDay := make(map[string]struct{})
	templates := make([]domain.Task, 0)
	for _, item := range items {
		if item.SyncID == "" {
			continue
		}
		if item.RecurringTemplateID != nil && strings.TrimSpace(*item.RecurringTemplateID) != "" {
			occurrenceDay := pickTaskDay(item)
			if !occurrenceDay.IsZero() {
				existingByTemplateDay[recurrenceDedupKey(*item.RecurringTemplateID, occurrenceDay)] = struct{}{}
			}
			continue
		}
		if item.IsDeleted || item.RecurrenceRule == nil || strings.TrimSpace(*item.RecurrenceRule) == "" {
			continue
		}
		templates = append(templates, item)
	}

	created := make([]domain.Task, 0)
	now := time.Now().UTC()
	for _, template := range templates {
		anchor := pickTaskDay(template)
		if anchor.IsZero() {
			anchor = now
		}
		rule, ok := parseRecurrenceRule(*template.RecurrenceRule, anchor)
		if !ok {
			continue
		}

		for day := rangeStart; !day.After(rangeEnd); day = day.AddDate(0, 0, 1) {
			if !rule.matches(day) {
				continue
			}
			if day.Equal(dayStartUTC(anchor)) {
				continue
			}

			key := recurrenceDedupKey(template.SyncID, day)
			if _, exists := existingByTemplateDay[key]; exists {
				continue
			}

			instance := buildRecurringInstance(template, day, now)
			if err := s.repo.Upsert(ctx, &instance); err != nil {
				return nil, err
			}
			existingByTemplateDay[key] = struct{}{}
			created = append(created, instance)
		}
	}

	if s.behaviorLogger != nil {
		_ = s.behaviorLogger.LogEvent(ctx, userID, "recurrences_generated", map[string]any{
			"from":    rangeStart.Format(time.RFC3339),
			"to":      rangeEnd.Format(time.RFC3339),
			"created": len(created),
		})
	}

	return created, nil
}

func (s *TaskService) GenerateRecurrencesForAllUsers(ctx context.Context, from, to time.Time) (int, int, error) {
	users, created, _, err := s.GenerateRecurrencesForAllUsersWithSummary(ctx, from, to)
	return users, created, err
}

func (s *TaskService) GenerateRecurrencesForAllUsersWithSummary(ctx context.Context, from, to time.Time) (int, int, []UserRecurrenceGeneration, error) {
	userIDs, err := s.repo.ListUsersWithRecurrenceTemplates(ctx)
	if err != nil {
		return 0, 0, nil, err
	}

	totalCreated := 0
	byUser := make([]UserRecurrenceGeneration, 0)
	for _, userID := range userIDs {
		created, genErr := s.GenerateRecurrences(ctx, userID, from, to)
		if genErr != nil {
			if errors.Is(genErr, ErrRecurrenceWindowInProgress) {
				continue
			}
			return len(userIDs), totalCreated, byUser, genErr
		}
		totalCreated += len(created)
		if len(created) > 0 {
			byUser = append(byUser, UserRecurrenceGeneration{
				UserID:  userID,
				Created: len(created),
			})
		}
	}

	return len(userIDs), totalCreated, byUser, nil
}

func (s *TaskService) Upsert(ctx context.Context, task *domain.Task) error {
	if task.UpdatedAt.IsZero() {
		task.UpdatedAt = time.Now().UTC()
	}
	if err := s.repo.Upsert(ctx, task); err != nil {
		return err
	}
	_ = s.behaviorLogger.LogEvent(ctx, task.UserID, "task_upserted", map[string]any{"taskId": task.ID, "syncId": task.SyncID})

	s.sendTaskUpdateNotification(task.UserID, task, "task_updated")

	return nil
}

func (s *TaskService) Delete(ctx context.Context, userID string, taskID int) error {
	if err := s.repo.Delete(ctx, userID, taskID); err != nil {
		return err
	}
	_ = s.behaviorLogger.LogEvent(ctx, userID, "task_deleted", map[string]any{"taskId": taskID})

	s.sendTaskDeleteNotification(userID, taskID)

	return nil
}

func (s *TaskService) Sync(ctx context.Context, userID string, tasks []domain.Task, deletedSyncIDs []string, since *time.Time) (*ports.TaskSyncResult, error) {
	result, err := s.repo.Sync(ctx, userID, tasks, deletedSyncIDs, since)
	if err != nil {
		return nil, err
	}
	_ = s.behaviorLogger.LogEvent(ctx, userID, "tasks_synced", map[string]any{"uploaded": len(tasks), "deleted": len(deletedSyncIDs), "downloaded": len(result.ServerTasks), "rejected": len(result.RejectedSyncIDs)})
	return result, nil
}

func (s *TaskService) sendTaskUpdateNotification(userID string, task *domain.Task, messageType string) {
	if s.wsManager == nil {
		return
	}

	message := map[string]any{
		"type": messageType,
		"data": task,
	}

	msgBytes, err := json.Marshal(message)
	if err != nil {
		fmt.Printf("failed to marshal websocket message: %v", err)
		return
	}

	_ = s.wsManager.SendToUser(userID, msgBytes)
}

func (s *TaskService) sendTaskDeleteNotification(userID string, taskID int) {
	if s.wsManager == nil {
		return
	}

	message := map[string]any{
		"type": "task_deleted",
		"data": map[string]any{
			"id": taskID,
		},
	}

	msgBytes, err := json.Marshal(message)
	if err != nil {
		fmt.Printf("failed to marshal websocket message: %v", err)
		return
	}

	_ = s.wsManager.SendToUser(userID, msgBytes)
}

type parsedRecurrenceRule struct {
	freq      string
	interval  int
	byDays    map[time.Weekday]bool
	anchorDay time.Time
}

func parseRecurrenceRule(raw string, anchorDay time.Time) (*parsedRecurrenceRule, bool) {
	parts := strings.Split(strings.ToUpper(strings.TrimSpace(raw)), ";")
	data := map[string]string{}
	for _, part := range parts {
		chunk := strings.SplitN(strings.TrimSpace(part), "=", 2)
		if len(chunk) != 2 {
			continue
		}
		data[chunk[0]] = chunk[1]
	}

	freq := data["FREQ"]
	if freq != "DAILY" && freq != "WEEKLY" && freq != "MONTHLY" {
		return nil, false
	}

	interval := 1
	if value, ok := data["INTERVAL"]; ok {
		if parsed, err := strconv.Atoi(value); err == nil && parsed > 0 {
			interval = parsed
		}
	}

	byDays := map[time.Weekday]bool{}
	if freq == "WEEKLY" {
		source := data["BYDAY"]
		if source == "" {
			byDays[anchorDay.Weekday()] = true
		} else {
			for _, token := range strings.Split(source, ",") {
				if weekday, ok := weekdayFromRRuleToken(strings.TrimSpace(token)); ok {
					byDays[weekday] = true
				}
			}
			if len(byDays) == 0 {
				byDays[anchorDay.Weekday()] = true
			}
		}
	}

	return &parsedRecurrenceRule{
		freq:      freq,
		interval:  interval,
		byDays:    byDays,
		anchorDay: dayStartUTC(anchorDay),
	}, true
}

func (r *parsedRecurrenceRule) matches(day time.Time) bool {
	d := dayStartUTC(day)
	if d.Before(r.anchorDay) {
		return false
	}

	switch r.freq {
	case "DAILY":
		diff := int(d.Sub(r.anchorDay).Hours() / 24)
		return diff%r.interval == 0
	case "WEEKLY":
		if !r.byDays[d.Weekday()] {
			return false
		}
		weeks := int(d.Sub(weekStart(r.anchorDay)).Hours() / (24 * 7))
		return weeks%r.interval == 0
	case "MONTHLY":
		if d.Day() != r.anchorDay.Day() {
			return false
		}
		months := (d.Year()-r.anchorDay.Year())*12 + int(d.Month()-r.anchorDay.Month())
		return months%r.interval == 0
	default:
		return false
	}
}

func weekdayFromRRuleToken(token string) (time.Weekday, bool) {
	switch token {
	case "MO":
		return time.Monday, true
	case "TU":
		return time.Tuesday, true
	case "WE":
		return time.Wednesday, true
	case "TH":
		return time.Thursday, true
	case "FR":
		return time.Friday, true
	case "SA":
		return time.Saturday, true
	case "SU":
		return time.Sunday, true
	default:
		return time.Sunday, false
	}
}

func weekStart(day time.Time) time.Time {
	d := dayStartUTC(day)
	offset := int(d.Weekday()+6) % 7 // monday based
	return d.AddDate(0, 0, -offset)
}

func dayStartUTC(t time.Time) time.Time {
	u := t.UTC()
	return time.Date(u.Year(), u.Month(), u.Day(), 0, 0, 0, 0, time.UTC)
}

func pickTaskDay(task domain.Task) time.Time {
	if task.CreatedDate != nil {
		return dayStartUTC(*task.CreatedDate)
	}
	if task.FinishDate != nil {
		return dayStartUTC(*task.FinishDate)
	}
	if !task.UpdatedAt.IsZero() {
		return dayStartUTC(task.UpdatedAt)
	}
	return time.Time{}
}

func recurrenceDedupKey(templateSyncID string, day time.Time) string {
	return templateSyncID + "|" + dayStartUTC(day).Format("2006-01-02")
}

func (s *TaskService) tryBeginWindow(ctx context.Context, key string) (string, error) {
	s.generationMu.Lock()
	if _, exists := s.activeWindows[key]; exists {
		s.generationMu.Unlock()
		return "", nil
	}
	s.activeWindows[key] = struct{}{}
	s.generationMu.Unlock()

	ownerID := uuid.NewString()
	acquired, err := s.repo.TryAcquireRecurrenceLock(ctx, key, ownerID, time.Now().UTC().Add(recurrenceWindowLockTTL))
	if err != nil {
		s.generationMu.Lock()
		delete(s.activeWindows, key)
		s.generationMu.Unlock()
		return "", err
	}
	if !acquired {
		s.generationMu.Lock()
		delete(s.activeWindows, key)
		s.generationMu.Unlock()
		return "", nil
	}
	return ownerID, nil
}

func (s *TaskService) endWindow(ctx context.Context, key, ownerID string) {
	_ = s.repo.ReleaseRecurrenceLock(ctx, key, ownerID)

	s.generationMu.Lock()
	defer s.generationMu.Unlock()
	delete(s.activeWindows, key)
}

func buildRecurringInstance(template domain.Task, day time.Time, now time.Time) domain.Task {
	var (
		title       = template.Title
		description = template.Description
		category    = template.Category
		energy      = template.EnergyLevel
	)

	instance := domain.Task{
		SyncID:              uuid.NewString(),
		UserID:              template.UserID,
		Title:               title,
		Description:         description,
		EnergyLevel:         energy,
		RecurrenceRule:      nil,
		RecurringTemplateID: &template.SyncID,
		CreatedDate:         ptrTimeTask(day),
		FinishDate:          nil,
		IsFinished:          false,
		Priority:            template.Priority,
		Category:            category,
		EstimatedPomodoros:  template.EstimatedPomodoros,
		CompletedPomodoros:  0,
		FocusedSeconds:      0,
		ActiveSessionID:     nil,
		IsDeleted:           false,
		UpdatedAt:           now,
	}

	if template.CreatedDate != nil && template.FinishDate != nil {
		offset := template.FinishDate.Sub(*template.CreatedDate)
		finish := day.Add(offset)
		instance.FinishDate = &finish
	}

	return instance
}

func ptrTimeTask(v time.Time) *time.Time {
	return &v
}

// Mode-specific tracking methods
func (s *TaskService) UpdateTaskTrackingMode(ctx context.Context, userID string, taskID int, mode string) error {
	if err := s.repo.UpdateTrackingMode(ctx, userID, taskID, mode); err != nil {
		return err
	}
	_ = s.behaviorLogger.LogEvent(ctx, userID, "task_tracking_mode_updated", map[string]any{"taskId": taskID, "mode": mode})
	return nil
}

func (s *TaskService) IncrementTaskCompletion(ctx context.Context, userID string, taskID int, mode string) error {
	if err := s.repo.IncrementCompletionCount(ctx, userID, taskID, mode); err != nil {
		return err
	}
	_ = s.behaviorLogger.LogEvent(ctx, userID, "task_completion_incremented", map[string]any{"taskId": taskID, "mode": mode})
	return nil
}

func (s *TaskService) IncrementTaskFocusTime(ctx context.Context, userID string, taskID int, mode string, seconds int) error {
	if err := s.repo.IncrementFocusTime(ctx, userID, taskID, mode, seconds); err != nil {
		return err
	}
	_ = s.behaviorLogger.LogEvent(ctx, userID, "task_focus_time_incremented", map[string]any{"taskId": taskID, "mode": mode, "seconds": seconds})
	return nil
}

func (s *TaskService) SetTaskActiveSession(ctx context.Context, userID string, taskID int, sessionID *string) error {
	if err := s.repo.SetActiveSession(ctx, userID, taskID, sessionID); err != nil {
		return err
	}
	_ = s.behaviorLogger.LogEvent(ctx, userID, "task_active_session_set", map[string]any{"taskId": taskID, "sessionId": sessionID})
	return nil
}
