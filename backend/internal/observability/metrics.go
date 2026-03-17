package observability

import (
	"fmt"
	"strings"
	"sync"
	"sync/atomic"
	"time"
)

const (
	sloWindow5m = 5 * time.Minute
	sloWindow1h = time.Hour
)

type Alert struct {
	Code      string `json:"code"`
	Severity  string `json:"severity"`
	Message   string `json:"message"`
	Value     int64  `json:"value,omitempty"`
	Threshold int64  `json:"threshold,omitempty"`
}

type SuppressedAlert struct {
	Alert  Alert  `json:"alert"`
	Reason string `json:"reason"`
	Until  string `json:"until,omitempty"`
}

type AlertEvaluation struct {
	Alerts      []Alert           `json:"alerts"`
	Suppressed  []SuppressedAlert `json:"suppressed"`
	MuteActive  bool              `json:"muteActive"`
	CooldownSec int64             `json:"cooldownSec"`
	EvaluatedAt string            `json:"evaluatedAt"`
}

type AlertRules struct {
	BillingMinSamples                 int64 `json:"billingMinSamples"`
	BillingFailureRatioWarnPct        int64 `json:"billingFailureRatioWarnPct"`
	BillingFailureRatioCriticalPct    int64 `json:"billingFailureRatioCriticalPct"`
	PushFailureRatioWarnPct           int64 `json:"pushFailureRatioWarnPct"`
	PushFailureRatioCriticalPct       int64 `json:"pushFailureRatioCriticalPct"`
	RecurrenceFailureRatioWarnPct     int64 `json:"recurrenceFailureRatioWarnPct"`
	RecurrenceFailureRatioCriticalPct int64 `json:"recurrenceFailureRatioCriticalPct"`
	AlertCooldownSeconds              int64 `json:"alertCooldownSeconds"`
	AlertMuteWindowEnabled            bool  `json:"alertMuteWindowEnabled"`
	AlertMuteStartHourUTC             int64 `json:"alertMuteStartHourUtc"`
	AlertMuteEndHourUTC               int64 `json:"alertMuteEndHourUtc"`
}

type SLOState struct {
	Metric               string `json:"metric"`
	Window               string `json:"window"`
	TotalSamples         int64  `json:"totalSamples"`
	FailureSamples       int64  `json:"failureSamples"`
	FailureRatioPct      int64  `json:"failureRatioPct"`
	WarnThresholdPct     int64  `json:"warnThresholdPct"`
	CriticalThresholdPct int64  `json:"criticalThresholdPct"`
	Status               string `json:"status"`
	Severity             string `json:"severity"`
}

type metricEvent struct {
	at      time.Time
	success bool
}

type metricThreshold struct {
	warnPct     int64
	criticalPct int64
}

var (
	billingSuccessCount int64
	billingFailureCount int64
	billingLatencyMsSum int64

	pushSentCount   int64
	pushFailedCount int64
	pushDeviceSends int64

	recurrenceRunsCount     int64
	recurrenceUsersSum      int64
	recurrenceCreatedSum    int64
	recurrenceFailuresCount int64

	alertRulesMu sync.RWMutex
	alertRules   = DefaultAlertRules()

	eventsMu         sync.Mutex
	billingEvents    []metricEvent
	pushEvents       []metricEvent
	recurrenceEvents []metricEvent

	alertStateMu         sync.Mutex
	lastAlertEmittedAt   = make(map[string]time.Time)
	lastAlertFingerprint = make(map[string]string)

	nowFunc = time.Now
)

func DefaultAlertRules() AlertRules {
	return AlertRules{
		BillingMinSamples:                 5,
		BillingFailureRatioWarnPct:        20,
		BillingFailureRatioCriticalPct:    40,
		PushFailureRatioWarnPct:           20,
		PushFailureRatioCriticalPct:       40,
		RecurrenceFailureRatioWarnPct:     20,
		RecurrenceFailureRatioCriticalPct: 40,
		AlertCooldownSeconds:              300,
		AlertMuteWindowEnabled:            false,
		AlertMuteStartHourUTC:             0,
		AlertMuteEndHourUTC:               0,
	}
}

func ConfigureAlertRules(rules AlertRules) {
	defaults := DefaultAlertRules()
	if rules.BillingMinSamples <= 0 {
		rules.BillingMinSamples = defaults.BillingMinSamples
	}
	if rules.BillingFailureRatioWarnPct <= 0 {
		rules.BillingFailureRatioWarnPct = defaults.BillingFailureRatioWarnPct
	}
	if rules.BillingFailureRatioCriticalPct <= 0 {
		rules.BillingFailureRatioCriticalPct = defaults.BillingFailureRatioCriticalPct
	}
	if rules.PushFailureRatioWarnPct <= 0 {
		rules.PushFailureRatioWarnPct = defaults.PushFailureRatioWarnPct
	}
	if rules.PushFailureRatioCriticalPct <= 0 {
		rules.PushFailureRatioCriticalPct = defaults.PushFailureRatioCriticalPct
	}
	if rules.RecurrenceFailureRatioWarnPct <= 0 {
		rules.RecurrenceFailureRatioWarnPct = defaults.RecurrenceFailureRatioWarnPct
	}
	if rules.RecurrenceFailureRatioCriticalPct <= 0 {
		rules.RecurrenceFailureRatioCriticalPct = defaults.RecurrenceFailureRatioCriticalPct
	}
	if rules.AlertCooldownSeconds < 0 {
		rules.AlertCooldownSeconds = defaults.AlertCooldownSeconds
	}
	if rules.AlertMuteStartHourUTC < 0 || rules.AlertMuteStartHourUTC > 23 {
		rules.AlertMuteStartHourUTC = defaults.AlertMuteStartHourUTC
	}
	if rules.AlertMuteEndHourUTC < 0 || rules.AlertMuteEndHourUTC > 23 {
		rules.AlertMuteEndHourUTC = defaults.AlertMuteEndHourUTC
	}

	if rules.BillingFailureRatioCriticalPct < rules.BillingFailureRatioWarnPct {
		rules.BillingFailureRatioCriticalPct = rules.BillingFailureRatioWarnPct
	}
	if rules.PushFailureRatioCriticalPct < rules.PushFailureRatioWarnPct {
		rules.PushFailureRatioCriticalPct = rules.PushFailureRatioWarnPct
	}
	if rules.RecurrenceFailureRatioCriticalPct < rules.RecurrenceFailureRatioWarnPct {
		rules.RecurrenceFailureRatioCriticalPct = rules.RecurrenceFailureRatioWarnPct
	}

	alertRulesMu.Lock()
	alertRules = rules
	alertRulesMu.Unlock()
}

func CurrentAlertRules() AlertRules {
	alertRulesMu.RLock()
	defer alertRulesMu.RUnlock()
	return alertRules
}

func RecordBilling(success bool, duration time.Duration) {
	if success {
		atomic.AddInt64(&billingSuccessCount, 1)
	} else {
		atomic.AddInt64(&billingFailureCount, 1)
	}
	atomic.AddInt64(&billingLatencyMsSum, duration.Milliseconds())
	appendMetricEvent(&billingEvents, success)
}

func RecordPush(success bool, devices int) {
	if success {
		atomic.AddInt64(&pushSentCount, 1)
		atomic.AddInt64(&pushDeviceSends, int64(devices))
	} else {
		atomic.AddInt64(&pushFailedCount, 1)
	}
	appendMetricEvent(&pushEvents, success)
}

func RecordRecurrenceRun(users, created int, success bool) {
	atomic.AddInt64(&recurrenceRunsCount, 1)
	atomic.AddInt64(&recurrenceUsersSum, int64(users))
	atomic.AddInt64(&recurrenceCreatedSum, int64(created))
	if !success {
		atomic.AddInt64(&recurrenceFailuresCount, 1)
	}
	appendMetricEvent(&recurrenceEvents, success)
}

func Snapshot() map[string]any {
	success := atomic.LoadInt64(&billingSuccessCount)
	failure := atomic.LoadInt64(&billingFailureCount)
	total := success + failure
	avgBillingLatencyMs := int64(0)
	if total > 0 {
		avgBillingLatencyMs = atomic.LoadInt64(&billingLatencyMsSum) / total
	}

	return map[string]any{
		"billing": map[string]any{
			"successCount":      success,
			"failureCount":      failure,
			"avgLatencyMs":      avgBillingLatencyMs,
			"latencyMsTotalSum": atomic.LoadInt64(&billingLatencyMsSum),
		},
		"push": map[string]any{
			"sentCount":   atomic.LoadInt64(&pushSentCount),
			"failedCount": atomic.LoadInt64(&pushFailedCount),
			"deviceSends": atomic.LoadInt64(&pushDeviceSends),
		},
		"recurrence": map[string]any{
			"runsCount":     atomic.LoadInt64(&recurrenceRunsCount),
			"failuresCount": atomic.LoadInt64(&recurrenceFailuresCount),
			"usersTotal":    atomic.LoadInt64(&recurrenceUsersSum),
			"createdTotal":  atomic.LoadInt64(&recurrenceCreatedSum),
		},
	}
}

func PrometheusText() string {
	success := atomic.LoadInt64(&billingSuccessCount)
	failure := atomic.LoadInt64(&billingFailureCount)
	total := success + failure
	avgBillingLatencyMs := int64(0)
	if total > 0 {
		avgBillingLatencyMs = atomic.LoadInt64(&billingLatencyMsSum) / total
	}

	sloStates := EvaluateSLO()

	var b strings.Builder
	b.WriteString("# HELP pepinillo_billing_success_total Total successful billing verifications\n")
	b.WriteString("# TYPE pepinillo_billing_success_total counter\n")
	b.WriteString(fmt.Sprintf("pepinillo_billing_success_total %d\n", success))
	b.WriteString("# HELP pepinillo_billing_failure_total Total failed billing verifications\n")
	b.WriteString("# TYPE pepinillo_billing_failure_total counter\n")
	b.WriteString(fmt.Sprintf("pepinillo_billing_failure_total %d\n", failure))
	b.WriteString("# HELP pepinillo_billing_latency_avg_ms Average billing verification latency in ms\n")
	b.WriteString("# TYPE pepinillo_billing_latency_avg_ms gauge\n")
	b.WriteString(fmt.Sprintf("pepinillo_billing_latency_avg_ms %d\n", avgBillingLatencyMs))

	pushSent := atomic.LoadInt64(&pushSentCount)
	pushFailed := atomic.LoadInt64(&pushFailedCount)
	pushDevices := atomic.LoadInt64(&pushDeviceSends)
	b.WriteString("# HELP pepinillo_push_sent_total Total push send batches\n")
	b.WriteString("# TYPE pepinillo_push_sent_total counter\n")
	b.WriteString(fmt.Sprintf("pepinillo_push_sent_total %d\n", pushSent))
	b.WriteString("# HELP pepinillo_push_failed_total Total failed push send batches\n")
	b.WriteString("# TYPE pepinillo_push_failed_total counter\n")
	b.WriteString(fmt.Sprintf("pepinillo_push_failed_total %d\n", pushFailed))
	b.WriteString("# HELP pepinillo_push_device_sends_total Total device-level push sends\n")
	b.WriteString("# TYPE pepinillo_push_device_sends_total counter\n")
	b.WriteString(fmt.Sprintf("pepinillo_push_device_sends_total %d\n", pushDevices))

	recRuns := atomic.LoadInt64(&recurrenceRunsCount)
	recFailures := atomic.LoadInt64(&recurrenceFailuresCount)
	recUsers := atomic.LoadInt64(&recurrenceUsersSum)
	recCreated := atomic.LoadInt64(&recurrenceCreatedSum)
	b.WriteString("# HELP pepinillo_recurrence_runs_total Total recurrence generator runs\n")
	b.WriteString("# TYPE pepinillo_recurrence_runs_total counter\n")
	b.WriteString(fmt.Sprintf("pepinillo_recurrence_runs_total %d\n", recRuns))
	b.WriteString("# HELP pepinillo_recurrence_failures_total Total failed recurrence generator runs\n")
	b.WriteString("# TYPE pepinillo_recurrence_failures_total counter\n")
	b.WriteString(fmt.Sprintf("pepinillo_recurrence_failures_total %d\n", recFailures))
	b.WriteString("# HELP pepinillo_recurrence_users_total Total users scanned in recurrence runs\n")
	b.WriteString("# TYPE pepinillo_recurrence_users_total counter\n")
	b.WriteString(fmt.Sprintf("pepinillo_recurrence_users_total %d\n", recUsers))
	b.WriteString("# HELP pepinillo_recurrence_created_total Total generated recurrence tasks\n")
	b.WriteString("# TYPE pepinillo_recurrence_created_total counter\n")
	b.WriteString(fmt.Sprintf("pepinillo_recurrence_created_total %d\n", recCreated))

	for _, s := range sloStates {
		metricName := strings.ReplaceAll(s.Metric, "-", "_")
		windowLabel := strings.ReplaceAll(s.Window, " ", "")
		b.WriteString("# HELP pepinillo_slo_failure_ratio_pct SLO failure ratio percentage by metric/window\n")
		b.WriteString("# TYPE pepinillo_slo_failure_ratio_pct gauge\n")
		b.WriteString(fmt.Sprintf("pepinillo_slo_failure_ratio_pct{metric=\"%s\",window=\"%s\"} %d\n", metricName, windowLabel, s.FailureRatioPct))
	}

	return b.String()
}

func EvaluateSLO() []SLOState {
	rules := CurrentAlertRules()
	now := nowFunc().UTC()
	minSamples := rules.BillingMinSamples
	thresholds := map[string]metricThreshold{
		"billing": {
			warnPct:     rules.BillingFailureRatioWarnPct,
			criticalPct: rules.BillingFailureRatioCriticalPct,
		},
		"push": {
			warnPct:     rules.PushFailureRatioWarnPct,
			criticalPct: rules.PushFailureRatioCriticalPct,
		},
		"recurrence": {
			warnPct:     rules.RecurrenceFailureRatioWarnPct,
			criticalPct: rules.RecurrenceFailureRatioCriticalPct,
		},
	}

	eventsMu.Lock()
	pruneBefore := now.Add(-sloWindow1h)
	billingEvents = pruneEvents(billingEvents, pruneBefore)
	pushEvents = pruneEvents(pushEvents, pruneBefore)
	recurrenceEvents = pruneEvents(recurrenceEvents, pruneBefore)
	billingCopy := append([]metricEvent(nil), billingEvents...)
	pushCopy := append([]metricEvent(nil), pushEvents...)
	recurrenceCopy := append([]metricEvent(nil), recurrenceEvents...)
	eventsMu.Unlock()

	states := make([]SLOState, 0, 6)
	states = append(states, buildWindowStates("billing", billingCopy, thresholds["billing"], minSamples, now)...)
	states = append(states, buildWindowStates("push", pushCopy, thresholds["push"], minSamples, now)...)
	states = append(states, buildWindowStates("recurrence", recurrenceCopy, thresholds["recurrence"], minSamples, now)...)
	return states
}

func EvaluateAlerts() []Alert {
	return EvaluateManagedAlerts().Alerts
}

func EvaluateManagedAlerts() AlertEvaluation {
	now := nowFunc().UTC()
	rules := CurrentAlertRules()
	candidates := buildAlertCandidates()

	result := AlertEvaluation{
		Alerts:      make([]Alert, 0, len(candidates)),
		Suppressed:  make([]SuppressedAlert, 0),
		MuteActive:  isMuteWindowActive(now, rules),
		CooldownSec: rules.AlertCooldownSeconds,
		EvaluatedAt: now.Format(time.RFC3339),
	}

	if len(candidates) == 0 {
		return result
	}

	alertStateMu.Lock()
	defer alertStateMu.Unlock()

	for _, candidate := range candidates {
		if result.MuteActive {
			result.Suppressed = append(result.Suppressed, SuppressedAlert{
				Alert:  candidate,
				Reason: "mute_window",
			})
			continue
		}

		key := candidate.Code
		fingerprint := alertFingerprint(candidate)
		lastEmitAt, hasEmit := lastAlertEmittedAt[key]
		lastFingerprint, hasFingerprint := lastAlertFingerprint[key]
		cooldownEnd := lastEmitAt.Add(time.Duration(rules.AlertCooldownSeconds) * time.Second)

		unchanged := hasFingerprint && lastFingerprint == fingerprint
		inCooldown := hasEmit && rules.AlertCooldownSeconds > 0 && now.Before(cooldownEnd)

		if unchanged && inCooldown {
			result.Suppressed = append(result.Suppressed, SuppressedAlert{
				Alert:  candidate,
				Reason: "cooldown_dedup",
				Until:  cooldownEnd.Format(time.RFC3339),
			})
			continue
		}

		result.Alerts = append(result.Alerts, candidate)
		lastAlertEmittedAt[key] = now
		lastAlertFingerprint[key] = fingerprint
	}

	return result
}

func buildAlertCandidates() []Alert {
	states := EvaluateSLO()
	alerts := make([]Alert, 0, len(states))
	for _, s := range states {
		if s.Status != "degraded" {
			continue
		}
		threshold := s.WarnThresholdPct
		if s.Severity == "critical" {
			threshold = s.CriticalThresholdPct
		}
		alerts = append(alerts, Alert{
			Code:      fmt.Sprintf("%s_slo_degraded_%s", s.Metric, s.Window),
			Severity:  s.Severity,
			Message:   fmt.Sprintf("%s SLO degraded on %s window", s.Metric, s.Window),
			Value:     s.FailureRatioPct,
			Threshold: threshold,
		})
	}
	return alerts
}

func appendMetricEvent(dst *[]metricEvent, success bool) {
	now := nowFunc().UTC()
	eventsMu.Lock()
	*dst = append(*dst, metricEvent{at: now, success: success})
	pruneBefore := now.Add(-sloWindow1h)
	*dst = pruneEvents(*dst, pruneBefore)
	eventsMu.Unlock()
}

func pruneEvents(events []metricEvent, minTime time.Time) []metricEvent {
	if len(events) == 0 {
		return events
	}
	firstIdx := 0
	for firstIdx < len(events) && events[firstIdx].at.Before(minTime) {
		firstIdx++
	}
	if firstIdx == 0 {
		return events
	}
	out := make([]metricEvent, len(events)-firstIdx)
	copy(out, events[firstIdx:])
	return out
}

func buildWindowStates(metric string, events []metricEvent, t metricThreshold, minSamples int64, now time.Time) []SLOState {
	return []SLOState{
		buildState(metric, "5m", events, now.Add(-sloWindow5m), t, minSamples),
		buildState(metric, "1h", events, now.Add(-sloWindow1h), t, minSamples),
	}
}

func buildState(metric, window string, events []metricEvent, minTime time.Time, t metricThreshold, minSamples int64) SLOState {
	var total int64
	var failures int64
	for _, ev := range events {
		if ev.at.Before(minTime) {
			continue
		}
		total++
		if !ev.success {
			failures++
		}
	}

	failureRatioPct := int64(0)
	if total > 0 {
		failureRatioPct = (failures * 100) / total
	}

	status := "ok"
	severity := "none"
	if total < minSamples {
		status = "insufficient_data"
		severity = "info"
	} else if failureRatioPct >= t.criticalPct {
		status = "degraded"
		severity = "critical"
	} else if failureRatioPct >= t.warnPct {
		status = "degraded"
		severity = "warning"
	}

	return SLOState{
		Metric:               metric,
		Window:               window,
		TotalSamples:         total,
		FailureSamples:       failures,
		FailureRatioPct:      failureRatioPct,
		WarnThresholdPct:     t.warnPct,
		CriticalThresholdPct: t.criticalPct,
		Status:               status,
		Severity:             severity,
	}
}

func alertFingerprint(alert Alert) string {
	return fmt.Sprintf("%s|%s|%s|%d|%d", alert.Code, alert.Severity, alert.Message, alert.Value, alert.Threshold)
}

func isMuteWindowActive(now time.Time, rules AlertRules) bool {
	if !rules.AlertMuteWindowEnabled {
		return false
	}

	start := int(rules.AlertMuteStartHourUTC)
	end := int(rules.AlertMuteEndHourUTC)
	if start == end {
		return false
	}

	hour := now.UTC().Hour()
	if start < end {
		return hour >= start && hour < end
	}
	return hour >= start || hour < end
}
