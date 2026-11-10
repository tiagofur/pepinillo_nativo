# Sprint 5 iOS — Resume session after kill

When the app relaunches with a killed session that still has usable time
left, offer to resume it where it died instead of only recording an
abandonment (T5 Sprint-1 behavior stays as the Discard path).
Authorized scope: "Sprint 5 (reanudar sesión)". Product decisions
assumed after cancelled questionnaire (override any with one line):
offer-sheet (not silent), frozen absence (pause, never over-claim),
same-day + >60s-remaining eligibility.

## Specs

- S1: On launch with an eligible ghost, surface an offer (Resume with
  remaining time / Discard). Resume restarts the engine from the ghost
  anchors; Discard keeps today's abandon-record path.
- S2: Absence is frozen: resume continues with the kill-time remaining
  (anchors shifted to now). Elapsed wall-clock while dead never counts
  as focus.
- S3: Eligible = remaining > 60s AND kill happened same calendar day.
  Anything else follows the old abandon-and-clear path silently.
- S4: Test-first per rule: one RED test per rule through the public
  interface. iOS runner unavailable here (CLI tools only, no Xcode) —
  tests run in Xcode/CI before merge.

## Tasks

- T1 (S1-S2): Engine resume-from-ghost-anchors with wall-clock math. Route:
  inline parent (FocusEngine state). Commit: 4aaca2fe feat(ios): adopt
  killed sessions back to live with wall-clock math.
- T2 (S3): Eligibility + offer surfacing on launch. Route: inline parent.
  Commit: e9e17cb9 feat(ios): offer resume for eligible killed sessions
  on launch.
- T3 (S1): Resume/discard UI + wiring. Route: inline parent. Commit:
  52c7d722 feat(ios): offer resume for killed sessions with wall-clock
  adopt.

## Log

- L0 (go-ahead sprint 5, verbatim): "Sprint 5"
- L1 (scope choice, verbatim): "Reanudar sesión"
- L2 (questionnaire cancelled by user; parent-assumed defaults, verbatim):
  "se pregunta (sheet Resume/Discard), congelado (el hueco cuenta como
  pausa) y mismo día + >1 min"
- L3 (T1 done + S2 REVISED openly): frozen is unimplementable without a
  kill timestamp (no reliable kill hook; heartbeat rejected as infra).
  Wall-clock instead: resume iff timerEnd is future with remaining =
  end-now; long absences self-expire to abandon. Flow restarts at 0
  (stale anchor is a lower bound, never over-claims); prior multi-phase
  totals unrecoverable. Phase derived (mode+duration+config, eps 120s),
  no new anchor writes. Commit 4aaca2fe (4 tests test-first). Mismo
  caveat de runner.
- L4 (T2 done): GhostResumeSpec + resolveGhostResume puros (8 casos) +
  stash pre-clear en initialState + abandon diferido a Discard. Commit
  e9e17cb9. Mismo caveat de runner.
- L5 (T3 done): sheet Resume/Discard (X = Discard, offer never lingers)
  + ghostResumeTapped/ghostDiscardTapped + adoptGhostSession handler
  (observation/LiveActivity/soundscape/widget-anchor rebuild; no calendar
  event, no notification ask) + GhostResumeSpec.remaining (sheet text +
  anchor rebuild) + 2 repaired T2 literals + 1 reducer adopt test + 2
  AppFeature ghost tests (all RED pre-fix as compile errors). Anchor
  incident: an edit consumed the next test's @Test func line, orphaning
  its body — caught by verification read pre-commit, repaired (restored
  declaration, removed stray brace). Commit 52c7d722 (8 files, FULL diff
  reviewed). Mismo caveat de runner.
- L6 (Xcode verification saga): user has Xcode 27.0 (xcode-select pointed
  to CLT; DEVELOPER_DIR per invocation). First real build ever: macro
  trust gate (-skipMacroValidation), RevenueCat 5.72->5.95 + TCA 1.25.5->
  1.26.2 (Xcode 27 fixes), handmade Package.resolved (gitignored) after
  diagnosing SwiftPM minimal-change + stale tag cache + duplicate
  IssueReporting targets (xctest-dynamic-overlay vs swift-issue-reporting).
  Build fixes 31d0774d (snapshot typealias, wasCompleted reorder, widget
  explicit init, watchOS gate/closures, backfill call, PendingGhostOffer
  struct). Test repairs 9c834490 (stubs, @MainActor, labels, order,
  tolerances, race-free group harness). Suite 828/43 after 6e5a0dd0
  (sync wall-clock re-anchor, midpoint lock pattern, more stubs and
  tolerances). Remaining are blind-test debt (stubs, wall-clock-exact
  asserts, engine-harness races) + TCA-1.26 behavior deltas
  (Watch/Settings/Siri/Auth). Scope decision pending: full
  stabilization epic vs commit-and-track.
- L7 (suite GREEN 870/0 + 1 quarantined): rounds 67459cff. Resolved:
  engine-harness races (skip-nils, lock-count listeners), TCA-1.26
  (@MainActor suites, stub-everything: @DependencyClient testValue
  ignores defaults), AppGroup cross-test theft (existing
  AppGroupDefaultsSerialTrait applied to all engine/watch/settings/auth/
  email/revenue/router suites + per-test pinning), wall-clock-exact
  asserts (tolerances), Swift 6.4 memberwise rules, package upgrades
  (RevenueCat 5.95, TCA 1.26.2, full latest-in-range resolved set).
  Production fixes kept: sync wall-clock re-anchor, no other behavior
  changes. One quarantine: spotlightTaskDeepLinkOpensTaskDetail
  (taskTapped never arrives despite observer firing + lookup hitting;
  needs Xcode breakpoint debugging). Test command Vista: xcodebuild
  test -skipMacroValidation, DEVELOPER_DIR per invocation (xcode-select
  points at CLT).
