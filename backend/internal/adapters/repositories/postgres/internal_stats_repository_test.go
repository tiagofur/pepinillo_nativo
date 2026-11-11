package postgres

import (
	"context"
	"os"
	"testing"
	"time"

	"gorm.io/driver/postgres"
	"gorm.io/gorm"
)

// Runs only when STATS_TEST_DATABASE_URL points at a DB with all migrations
// applied (use a scratch database; the test inserts and removes its own rows).
func TestInternalStatsRepository_ConsentAndAggregates(t *testing.T) {
	dsn := os.Getenv("STATS_TEST_DATABASE_URL")
	if dsn == "" {
		t.Skip("STATS_TEST_DATABASE_URL not set")
	}
	db, err := gorm.Open(postgres.Open(dsn), &gorm.Config{})
	if err != nil {
		t.Fatal(err)
	}
	now := time.Now().UTC()
	ids := []string{"00000000-0000-0000-0000-0000000000a1", "00000000-0000-0000-0000-0000000000a2", "00000000-0000-0000-0000-0000000000a3"}
	t.Cleanup(func() { db.Exec("DELETE FROM users WHERE id IN ?", ids) })
	db.Exec("DELETE FROM users WHERE id IN ?", ids)

	repo := NewInternalStatsRepository(db)
	before, err := repo.Compute(context.Background(), now)
	if err != nil {
		t.Fatal(err)
	}

	ago := func(days int) time.Time { return now.AddDate(0, 0, -days) }
	mustExec := func(sql string, args ...any) {
		t.Helper()
		if err := db.Exec(sql, args...).Error; err != nil {
			t.Fatal(err)
		}
	}
	// a1: opted in, new, active today. a2: opted in, old, active 20d ago. a3: NOT opted in, very active.
	mustExec(`INSERT INTO users (id,email,name,metrics_opt_in,created_at) VALUES (?,?,?,true,?),(?,?,?,true,?),(?,?,?,false,?)`,
		ids[0], "a1@x.test", "A1", ago(2), ids[1], "a2@x.test", "A2", ago(90), ids[2], "a3@x.test", "A3", ago(1))
	sess := func(id, user, mode, phase string, secs int, started time.Time) {
		mustExec(`INSERT INTO focus_sessions (id,user_id,started_at,mode,phase,duration_seconds,elapsed_seconds,created_at,updated_at) VALUES (?,?,?,?,?,?,?,now(),now())`,
			id, user, started, mode, phase, secs, secs)
	}
	sess("st-1", ids[0], "pomodoro", "work", 1500, ago(0))
	sess("st-2", ids[0], "pomodoro", "short_break", 300, ago(0))
	sess("st-3", ids[1], "flowtime", "flow", 3600, ago(20))
	sess("st-4", ids[1], "stopwatch", "freeform", 600, ago(45)) // outside 30d
	sess("st-5", ids[2], "pomodoro", "work", 9999, ago(0))      // no consent
	mustExec(`INSERT INTO tasks (sync_id,user_id,created_date,finish_date,is_finished,updated_at) VALUES
	 ('st-t1',?,?,?,true,?),('st-t2',?,?,NULL,false,?),('st-t3',?,?,?,true,?)`,
		ids[0], ago(3), ago(1), ago(1), ids[0], ago(60), ago(60), ids[2], ago(1), ago(1), ago(1))
	t.Cleanup(func() { db.Exec("DELETE FROM tasks WHERE sync_id LIKE 'st-t%'") })

	after, err := repo.Compute(context.Background(), now)
	if err != nil {
		t.Fatal(err)
	}

	// Exact deltas vs. the pre-insert snapshot (robust on a populated DB).
	// Non-consenting user a3 (9999s of work, a task, a new account) must add nothing.
	check := func(name string, got, want int64) {
		t.Helper()
		if got != want {
			t.Errorf("%s delta = %d, want %d", name, got, want)
		}
	}
	check("users.total", after.Users.Total-before.Users.Total, 2)
	check("users.new30d", after.Users.New30d-before.Users.New30d, 1)
	check("users.active7d", after.Users.Active7d-before.Users.Active7d, 1)
	check("users.active30d", after.Users.Active30d-before.Users.Active30d, 2)
	check("sessions.total30d", after.Sessions.Total30d-before.Sessions.Total30d, 2)
	check("sessions.pomodoro", after.Sessions.ByMode30d["pomodoro"]-before.Sessions.ByMode30d["pomodoro"], 1)
	check("sessions.flowtime", after.Sessions.ByMode30d["flowtime"]-before.Sessions.ByMode30d["flowtime"], 1)
	check("sessions.stopwatch", after.Sessions.ByMode30d["stopwatch"]-before.Sessions.ByMode30d["stopwatch"], 0)
	check("focusMinutes.total30d", after.FocusMinutes.Total30d-before.FocusMinutes.Total30d, 85)
	check("focusMinutes.pomodoro", after.FocusMinutes.ByMode30d["pomodoro"]-before.FocusMinutes.ByMode30d["pomodoro"], 25)
	check("focusMinutes.flowtime", after.FocusMinutes.ByMode30d["flowtime"]-before.FocusMinutes.ByMode30d["flowtime"], 60)
	check("breakMinutes.total30d", after.BreakMinutes.Total30d-before.BreakMinutes.Total30d, 5)
	check("tasks.created30d", after.Tasks.Created30d-before.Tasks.Created30d, 1)
	check("tasks.completed30d", after.Tasks.Completed30d-before.Tasks.Completed30d, 1)
}
