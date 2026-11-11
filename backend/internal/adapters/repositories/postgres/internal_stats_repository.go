package postgres

import (
	"context"
	"time"

	"gorm.io/gorm"

	"pepinillo/backend/internal/domain"
)

// InternalStatsRepository runs read-only aggregate queries restricted to users
// with metrics_opt_in = TRUE. Nothing here selects identifying columns.
type InternalStatsRepository struct {
	db *gorm.DB
}

func NewInternalStatsRepository(db *gorm.DB) *InternalStatsRepository {
	return &InternalStatsRepository{db: db}
}

var statsModes = []string{"pomodoro", "flowtime", "timeblock", "stopwatch"}

const breakPhases = "('short_break','long_break','break')"

func (r *InternalStatsRepository) Compute(ctx context.Context, now time.Time) (*domain.InternalStats, error) {
	d7 := now.AddDate(0, 0, -7)
	d30 := now.AddDate(0, 0, -30)
	db := r.db.WithContext(ctx)
	out := &domain.InternalStats{
		Sessions:     domain.InternalStatsByMode{ByMode30d: zeroModes()},
		FocusMinutes: domain.InternalStatsByMode{ByMode30d: zeroModes()},
	}

	// Active = opted-in user who started a focus session or touched a task in the window.
	var u struct{ Total, New30d, Active7d, Active30d int64 }
	if err := db.Raw(`
SELECT COUNT(*) AS total,
  COUNT(*) FILTER (WHERE u.created_at >= ?) AS new30d,
  COUNT(*) FILTER (WHERE EXISTS (SELECT 1 FROM focus_sessions f WHERE f.user_id = u.id AND f.started_at >= ?)
                      OR EXISTS (SELECT 1 FROM tasks t WHERE t.user_id = u.id AND t.updated_at >= ?)) AS active7d,
  COUNT(*) FILTER (WHERE EXISTS (SELECT 1 FROM focus_sessions f WHERE f.user_id = u.id AND f.started_at >= ?)
                      OR EXISTS (SELECT 1 FROM tasks t WHERE t.user_id = u.id AND t.updated_at >= ?)) AS active30d
FROM users u WHERE u.metrics_opt_in`, d30, d7, d7, d30, d30).Scan(&u).Error; err != nil {
		return nil, err
	}
	out.Users = domain.InternalStatsUsers{Total: u.Total, New30d: u.New30d, Active7d: u.Active7d, Active30d: u.Active30d}

	var rows []struct {
		Mode    string
		IsBreak bool
		Count   int64
		Seconds int64
	}
	if err := db.Raw(`
SELECT f.mode AS mode, (f.phase IN `+breakPhases+`) AS is_break,
  COUNT(*) AS count, COALESCE(SUM(f.elapsed_seconds), 0) AS seconds
FROM focus_sessions f JOIN users u ON u.id = f.user_id
WHERE u.metrics_opt_in AND f.started_at >= ?
GROUP BY 1, 2`, d30).Scan(&rows).Error; err != nil {
		return nil, err
	}
	var breakSeconds int64
	for _, row := range rows {
		if row.IsBreak {
			breakSeconds += row.Seconds
			continue
		}
		if _, ok := out.Sessions.ByMode30d[row.Mode]; !ok {
			continue
		}
		out.Sessions.ByMode30d[row.Mode] += row.Count
		out.Sessions.Total30d += row.Count
		out.FocusMinutes.ByMode30d[row.Mode] += row.Seconds / 60
		out.FocusMinutes.Total30d += row.Seconds / 60
	}
	out.BreakMinutes.Total30d = breakSeconds / 60

	var t struct{ Created30d, Completed30d int64 }
	if err := db.Raw(`
SELECT COUNT(*) FILTER (WHERE t.created_date >= ?) AS created30d,
  COUNT(*) FILTER (WHERE t.is_finished AND NOT t.is_deleted AND t.finish_date >= ?) AS completed30d
FROM tasks t JOIN users u ON u.id = t.user_id WHERE u.metrics_opt_in`, d30, d30).Scan(&t).Error; err != nil {
		return nil, err
	}
	out.Tasks = domain.InternalStatsTasks{Created30d: t.Created30d, Completed30d: t.Completed30d}
	return out, nil
}

func zeroModes() map[string]int64 {
	m := make(map[string]int64, len(statsModes))
	for _, k := range statsModes {
		m[k] = 0
	}
	return m
}
