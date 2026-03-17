package observability

import (
	"strings"
	"sync/atomic"
	"testing"
	"time"
)

func resetMetrics() {
	atomic.StoreInt64(&billingSuccessCount, 0)
	atomic.StoreInt64(&billingFailureCount, 0)
	atomic.StoreInt64(&billingLatencyMsSum, 0)
	atomic.StoreInt64(&pushSentCount, 0)
	atomic.StoreInt64(&pushFailedCount, 0)
	atomic.StoreInt64(&pushDeviceSends, 0)
	atomic.StoreInt64(&recurrenceRunsCount, 0)
	atomic.StoreInt64(&recurrenceUsersSum, 0)
	atomic.StoreInt64(&recurrenceCreatedSum, 0)
	atomic.StoreInt64(&recurrenceFailuresCount, 0)

	eventsMu.Lock()
	billingEvents = nil
	pushEvents = nil
	recurrenceEvents = nil
	eventsMu.Unlock()

	alertStateMu.Lock()
	lastAlertEmittedAt = make(map[string]time.Time)
	lastAlertFingerprint = make(map[string]string)
	alertStateMu.Unlock()

	nowFunc = time.Now
	ConfigureAlertRules(DefaultAlertRules())
}

func TestSnapshotAggregatesCounters(t *testing.T) {
	resetMetrics()

	RecordBilling(true, 120*time.Millisecond)
	RecordBilling(false, 80*time.Millisecond)
	RecordPush(true, 3)
	RecordPush(false, 0)
	RecordRecurrenceRun(2, 5, true)
	RecordRecurrenceRun(1, 0, false)

	snapshot := Snapshot()
	billing := snapshot["billing"].(map[string]any)
	push := snapshot["push"].(map[string]any)
	recurrence := snapshot["recurrence"].(map[string]any)

	if billing["successCount"].(int64) != 1 || billing["failureCount"].(int64) != 1 {
		t.Fatalf("unexpected billing counters: %+v", billing)
	}
	if push["sentCount"].(int64) != 1 || push["failedCount"].(int64) != 1 || push["deviceSends"].(int64) != 3 {
		t.Fatalf("unexpected push counters: %+v", push)
	}
	if recurrence["runsCount"].(int64) != 2 || recurrence["failuresCount"].(int64) != 1 {
		t.Fatalf("unexpected recurrence counters: %+v", recurrence)
	}
}

func TestPrometheusTextContainsCoreMetrics(t *testing.T) {
	resetMetrics()
	RecordBilling(true, 100*time.Millisecond)
	RecordPush(true, 2)
	RecordRecurrenceRun(1, 3, true)

	text := PrometheusText()
	required := []string{
		"pepinillo_billing_success_total",
		"pepinillo_push_sent_total",
		"pepinillo_recurrence_runs_total",
		"pepinillo_slo_failure_ratio_pct",
	}
	for _, token := range required {
		if !strings.Contains(text, token) {
			t.Fatalf("expected prometheus output to contain %s", token)
		}
	}
}

func TestEvaluateManagedAlertsCooldownAndDedup(t *testing.T) {
	resetMetrics()
	base := time.Date(2026, 1, 1, 12, 0, 0, 0, time.UTC)
	now := base
	nowFunc = func() time.Time { return now }
	ConfigureAlertRules(AlertRules{
		BillingMinSamples:                 5,
		BillingFailureRatioWarnPct:        20,
		BillingFailureRatioCriticalPct:    50,
		PushFailureRatioWarnPct:           20,
		PushFailureRatioCriticalPct:       50,
		RecurrenceFailureRatioWarnPct:     20,
		RecurrenceFailureRatioCriticalPct: 50,
		AlertCooldownSeconds:              300,
	})

	for i := 0; i < 5; i++ {
		RecordBilling(false, 100*time.Millisecond)
	}
	for i := 0; i < 5; i++ {
		RecordBilling(true, 100*time.Millisecond)
	}

	first := EvaluateManagedAlerts()
	if len(first.Alerts) == 0 {
		t.Fatal("expected emitted alerts on first evaluation")
	}

	second := EvaluateManagedAlerts()
	if len(second.Alerts) != 0 {
		t.Fatalf("expected no emitted alerts in cooldown, got %d", len(second.Alerts))
	}
	if len(second.Suppressed) == 0 || second.Suppressed[0].Reason != "cooldown_dedup" {
		t.Fatalf("expected cooldown_dedup suppression, got %+v", second.Suppressed)
	}

	for i := 0; i < 5; i++ {
		RecordBilling(true, 100*time.Millisecond)
	}
	changed := EvaluateManagedAlerts()
	if len(changed.Alerts) == 0 {
		t.Fatal("expected changed alert to be emitted even during cooldown")
	}

	now = now.Add(301 * time.Second)
	afterCooldown := EvaluateManagedAlerts()
	if len(afterCooldown.Alerts) == 0 {
		t.Fatal("expected emitted alerts after cooldown window")
	}
}

func TestEvaluateManagedAlertsMuteWindow(t *testing.T) {
	resetMetrics()
	base := time.Date(2026, 1, 1, 2, 0, 0, 0, time.UTC)
	nowFunc = func() time.Time { return base }
	ConfigureAlertRules(AlertRules{
		BillingMinSamples:                 5,
		BillingFailureRatioWarnPct:        20,
		BillingFailureRatioCriticalPct:    50,
		PushFailureRatioWarnPct:           20,
		PushFailureRatioCriticalPct:       50,
		RecurrenceFailureRatioWarnPct:     20,
		RecurrenceFailureRatioCriticalPct: 50,
		AlertCooldownSeconds:              300,
		AlertMuteWindowEnabled:            true,
		AlertMuteStartHourUTC:             1,
		AlertMuteEndHourUTC:               6,
	})

	for i := 0; i < 5; i++ {
		RecordBilling(false, 100*time.Millisecond)
	}

	eval := EvaluateManagedAlerts()
	if !eval.MuteActive {
		t.Fatal("expected mute window to be active")
	}
	if len(eval.Alerts) != 0 {
		t.Fatalf("expected no emitted alerts while muted, got %d", len(eval.Alerts))
	}
	if len(eval.Suppressed) == 0 || eval.Suppressed[0].Reason != "mute_window" {
		t.Fatalf("expected mute_window suppression, got %+v", eval.Suppressed)
	}
}

func TestEvaluateSLOUsesWindows(t *testing.T) {
	resetMetrics()
	base := time.Date(2026, 1, 1, 12, 0, 0, 0, time.UTC)
	now := base
	nowFunc = func() time.Time { return now }

	for i := 0; i < 5; i++ {
		RecordBilling(false, 50*time.Millisecond)
	}
	for i := 0; i < 5; i++ {
		RecordBilling(true, 50*time.Millisecond)
	}

	now = now.Add(10 * time.Minute)
	for i := 0; i < 5; i++ {
		RecordBilling(true, 50*time.Millisecond)
	}

	states := EvaluateSLO()
	var fiveMin SLOState
	var oneHour SLOState
	for _, s := range states {
		if s.Metric != "billing" {
			continue
		}
		if s.Window == "5m" {
			fiveMin = s
		}
		if s.Window == "1h" {
			oneHour = s
		}
	}

	if fiveMin.FailureRatioPct != 0 {
		t.Fatalf("expected billing 5m ratio 0, got %d", fiveMin.FailureRatioPct)
	}
	if oneHour.FailureRatioPct <= 0 {
		t.Fatalf("expected billing 1h ratio > 0, got %d", oneHour.FailureRatioPct)
	}
}
