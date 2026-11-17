import type { LocaleCode } from '$lib/domain/entities/types';

export type MessageKey =
	| 'app.name'
	| 'app.tagline'
	| 'nav.focus'
	| 'nav.plan'
	| 'nav.dashboard'
	| 'nav.account'
	| 'footer.companion'
	| 'onboarding.title'
	| 'onboarding.body'
	| 'onboarding.limits'
	| 'onboarding.browserOnly'
	| 'onboarding.timerHonesty'
	| 'onboarding.continue'
	| 'onboarding.skip'
	| 'focus.title'
	| 'focus.honesty'
	| 'focus.start'
	| 'focus.pause'
	| 'focus.resume'
	| 'focus.skip'
	| 'focus.complete'
	| 'focus.reset'
	| 'focus.journal'
	| 'focus.linkTask'
	| 'focus.noTask'
	| 'focus.mode.pomodoro'
	| 'focus.mode.stopwatch'
	| 'focus.mode.flowtime'
	| 'focus.mode.timeblock'
	| 'focus.mode.locked'
	| 'focus.upgradeTeaser'
	| 'focus.autoStart'
	| 'focus.suggest.title'
	| 'focus.suggest.apply'
	| 'focus.suggest.locked'
	| 'focus.suggest.morning'
	| 'focus.suggest.deep'
	| 'focus.suggest.afternoon'
	| 'focus.suggest.evening'
	| 'focus.suggest.flexible'
	| 'focus.phase.idle'
	| 'focus.phase.running'
	| 'focus.phase.paused'
	| 'focus.phase.completed'
	| 'plan.title'
	| 'plan.add'
	| 'plan.search'
	| 'plan.newTask'
	| 'plan.search.empty'
	| 'plan.empty.all'
	| 'dashboard.refresh'
	| 'plan.empty'
	| 'plan.capBlocked'
	| 'plan.upgradeTeaser'
	| 'plan.priority'
	| 'plan.energy'
	| 'plan.estPomos'
	| 'plan.complete'
	| 'plan.delete'
	| 'plan.filter.all'
	| 'plan.filter.today'
	| 'plan.filter.upcoming'
	| 'plan.filter.inbox'
	| 'plan.quickPlaceholder'
	| 'plan.activeCap'
	| 'plan.priority.low'
	| 'plan.priority.medium'
	| 'plan.priority.high'
	| 'plan.energy.low'
	| 'plan.energy.medium'
	| 'plan.energy.high'
	| 'plan.listLabel'
	| 'plan.showOptions'
	| 'plan.hideOptions'
	| 'plan.focusTask'
	| 'plan.reorder'
	| 'dashboard.title'
	| 'dashboard.subtitle'
	| 'dashboard.today'
	| 'dashboard.last7'
	| 'dashboard.sessions'
	| 'dashboard.minutes'
	| 'dashboard.extendedGated'
	| 'dashboard.empty'
	| 'dashboard.heroCta'
	| 'dashboard.recent'
	| 'dashboard.avgSession'
	| 'account.title'
	| 'account.subtitle'
	| 'account.premiumThemes'
	| 'account.settings'
	| 'account.storage'
	| 'account.upgradeTitle'
	| 'account.pomodoro'
	| 'account.workMinutes'
	| 'account.breakMinutes'
	| 'account.export'
	| 'account.exportHint'
	| 'toast.sessionComplete'
	| 'toast.sessionSkipped'
	| 'toast.exportDone'
	| 'toast.signedIn'
	| 'toast.registered'
	| 'toast.signedOut'
	| 'toast.syncOk'
	| 'toast.syncMerged'
	| 'toast.syncPullDone'
	| 'account.signIn'
	| 'account.signUp'
	| 'account.signOut'
	| 'account.email'
	| 'account.password'
	| 'account.name'
	| 'account.syncNow'
	| 'account.syncing'
	| 'account.apiMissing'
	| 'account.everywhereActive'
	| 'account.everywhereInactive'
	| 'account.signedInAs'
	| 'account.refreshEntitlement'
	| 'sync.everywhereRequired'
	| 'sync.mergeExisting'
	| 'sync.ok'
	| 'sync.pullError'
	| 'sync.lastSync'
	| 'sync.autoSyncOn'
	| 'auth.required'
	| 'account.tier'
	| 'account.tierFree'
	| 'account.locale'
	| 'account.theme'
	| 'account.theme.system'
	| 'account.theme.light'
	| 'account.theme.dark'
	| 'account.storageWarning'
	| 'account.everywhereTeaser'
	| 'account.about'
	| 'account.nonGoals'
	| 'account.deviceId'
	| 'account.appearance'
	| 'account.theme.classic'
	| 'account.theme.forest'
	| 'account.theme.ocean'
	| 'account.theme.sunset'
	| 'landing.openApp'
	| 'landing.wipNote'
	| 'common.wip.title'
	| 'common.wip.body'
	| 'common.proLocked'
	| 'focus.phase.work'
	| 'focus.phase.shortBreak'
	| 'focus.phase.longBreak'
	| 'focus.waitingBreak'
	| 'focus.waitingWork'
	| 'focus.startBreak'
	| 'focus.startWork'
	| 'focus.takeBreak'
	| 'focus.ghost.title'
	| 'focus.ghost.body'
	| 'focus.ghost.resume'
	| 'focus.ghost.discard'
	| 'celebration.firstSession.title'
	| 'celebration.firstSession.body'
	| 'celebration.streak.title'
	| 'celebration.streak.body'
	| 'celebration.sessionCount.title'
	| 'celebration.sessionCount.body'
	| 'celebration.personalBest.title'
	| 'celebration.personalBest.body'
	| 'celebration.keepGoing'
	| 'celebration.record.title'
	| 'celebration.record.dismiss'
	| 'journal.title'
	| 'journal.subtitle'
	| 'journal.rating.1'
	| 'journal.rating.2'
	| 'journal.rating.3'
	| 'journal.rating.4'
	| 'journal.rating.5'
	| 'journal.placeholder'
	| 'journal.save'
	| 'journal.skip'
	| 'taskPicker.title'
	| 'taskPicker.empty'
	| 'taskPicker.unlink'
	| 'soundscape.title'
	| 'soundscape.none'
	| 'soundscape.rain'
	| 'soundscape.forest'
	| 'soundscape.cafe'
	| 'soundscape.whiteNoise'
	| 'soundscape.ocean'
	| 'soundscape.fireplace'
	| 'soundscape.binaural'
	| 'soundscape.lofi'
	| 'soundscape.volume'
	| 'soundscape.hint'
	| 'companion.focusToday'
	| 'companion.sessionsToday'
	| 'companion.streak'
	| 'companion.pomodoroNumber'
	| 'companion.activeTask'
	| 'companion.streakEmpty'
	| 'companion.suggest.title'
	| 'companion.suggest.apply'
	| 'adhd.breathe'
	| 'adhd.stretch'
	| 'adhd.hydrate'
	| 'adhd.move'
	| 'adhd.subtitle'
	| 'settings.focus.title'
	| 'settings.pomodoro.work'
	| 'settings.pomodoro.break'
	| 'settings.pomodoro.longBreak'
	| 'settings.pomodoro.sessions'
	| 'settings.autoStartBreaks'
	| 'settings.autoStartWork'
	| 'settings.flowtime.min'
	| 'settings.timeblock.minutes'
	| 'settings.timeblock.midpoint'
	| 'settings.sound.title'
	| 'settings.sound.enabled'
	| 'settings.behavior.title'
	| 'sound.classic'
	| 'sound.chime'
	| 'sound.bell'
	| 'sound.digital'
	| 'sound.woodblock'
	| 'settings.haptics'
	| 'settings.keepScreenOn'
	| 'settings.journal'
	| 'settings.adhd'
	| 'settings.notifications'
	| 'settings.notifications.hint'
	| 'plan.filter.completed'
	| 'plan.priority.none'
	| 'plan.energy.deep'
	| 'plan.energy.shallow'
	| 'plan.energy.admin'
	| 'plan.energySuggest'
	| 'plan.energyHint'
	| 'plan.due.today'
	| 'plan.due.overdue'
	| 'plan.dueDate'
	| 'plan.focusToday'
	| 'plan.recurrence'
	| 'plan.recurrence.daily'
	| 'plan.recurrence.weekdays'
	| 'plan.recurrence.weekly'
	| 'plan.recurrence.biweekly'
	| 'plan.recurrence.monthly'
	| 'plan.notes'
	| 'plan.notesPlaceholder'
	| 'plan.subtasks'
	| 'plan.subtaskAdd'
	| 'plan.subtaskDelete'
	| 'plan.subtasksGate'
	| 'plan.analytics'
	| 'plan.analytics.sessions'
	| 'plan.analytics.focus'
	| 'plan.deleteConfirm'
	| 'plan.inspector'
	| 'plan.empty.today'
	| 'plan.empty.inbox'
	| 'plan.empty.upcoming'
	| 'plan.empty.completed'
	| 'plan.empty.body'
	| 'quickCapture.title'
	| 'quickCapture.placeholder'
	| 'quickCapture.hint'
	| 'quickCapture.captured'
	| 'palette.placeholder'
	| 'palette.addTask'
	| 'palette.empty'
	| 'palette.focus'
	| 'palette.plan'
	| 'palette.dashboard'
	| 'palette.startFocus'
	| 'palette.toggleTheme'
	| 'toast.undo'
	| 'period.7'
	| 'period.30'
	| 'period.365'
	| 'chart.week'
	| 'chart.window'
	| 'chart.modes'
	| 'chart.day.sun'
	| 'chart.day.mon'
	| 'chart.day.tue'
	| 'chart.day.wed'
	| 'chart.day.thu'
	| 'chart.day.fri'
	| 'chart.day.sat'
	| 'dash.best'
	| 'dash.focusScore'
	| 'dash.peakHour'
	| 'dash.completion'
	| 'dash.longest'
	| 'dash.periodFocus'
	| 'score.exceptional'
	| 'score.strong'
	| 'score.steady'
	| 'score.warming'
	| 'score.rest'
	| 'achievements.title'
	| 'achievements.firstFocus.title'
	| 'achievements.weekWarrior.title'
	| 'achievements.pomodoroMaster.title'
	| 'achievements.deepDiver.title'
	| 'achievements.centuryClub.title'
	| 'achievements.earlyBird.title'
	| 'sessions.recent'
	| 'sessions.empty'
	| 'review.weekly'
	| 'review.monthly'
	| 'review.dataTab'
	| 'review.aiTab'
	| 'review.aiSoon'
	| 'review.focus'
	| 'review.sessions'
	| 'review.trendUp'
	| 'review.trendDown'
	| 'review.trendFlat'
	| 'review.topTasks'
	| 'review.modes'
	| 'review.bestDay'
	| 'auth.title'
	| 'auth.subtitle'
	| 'auth.signIn'
	| 'auth.signUp'
	| 'auth.nameField'
	| 'auth.emailField'
	| 'auth.passwordField'
	| 'auth.working'
	| 'auth.needAccount'
	| 'auth.haveAccount'
	| 'auth.forgot.link'
	| 'auth.forgot.submit'
	| 'auth.forgot.sent'
	| 'auth.error.generic'
	| 'auth.error.invalidCredentials'
	| 'auth.error.invalidEmail'
	| 'auth.error.emailTaken'
	| 'auth.error.weakPassword'
	| 'auth.error.apiMissing'
	| 'auth.syncHint'
	| 'auth.verifyPending'
	| 'auth.apiMissing'
	| 'auth.dangerTitle'
	| 'auth.deleteConfirm'
	| 'auth.deleteAccount'
	| 'sync.title'
	| 'sync.hint'
	| 'sync.last'
	| 'sync.live'
	| 'sync.offline'
	| 'sync.mergeTitle'
	| 'sync.mergeBody'
	| 'sync.mergePull'
	| 'sync.mergeUpload'
	| 'upgrade.title'
	| 'upgrade.meta'
	| 'upgrade.headline'
	| 'upgrade.sub'
	| 'upgrade.signedIn'
	| 'upgrade.signInFirst'
	| 'upgrade.plan.free'
	| 'upgrade.plan.plus'
	| 'upgrade.plan.everywhere'
	| 'upgrade.price.free'
	| 'upgrade.price.plus'
	| 'upgrade.price.everywhere'
	| 'upgrade.note.free'
	| 'upgrade.note.plus'
	| 'upgrade.note.everywhere'
	| 'upgrade.flag.best'
	| 'upgrade.free.pomodoro'
	| 'upgrade.free.stopwatch'
	| 'upgrade.free.tasks'
	| 'upgrade.free.analytics'
	| 'upgrade.plus.modes'
	| 'upgrade.plus.tasks'
	| 'upgrade.plus.subtasks'
	| 'upgrade.plus.themes'
	| 'upgrade.plus.analytics'
	| 'upgrade.plus.soundscapes'
	| 'upgrade.everywhere.plusIncluded'
	| 'upgrade.everywhere.sync'
	| 'upgrade.everywhere.ai'
	| 'upgrade.everywhere.recovery'
	| 'upgrade.everywhere.web'
	| 'upgrade.cta.free'
	| 'upgrade.cta.plus'
	| 'upgrade.cta.everywhere'
	| 'upgrade.working'
	| 'upgrade.checkoutError'
	| 'upgrade.portalError'
	| 'upgrade.storesTitle'
	| 'upgrade.storesBody'
	| 'upgrade.storeApp'
	| 'upgrade.storePlay'
	| 'upgrade.manageTitle'
	| 'upgrade.manageBody'
	| 'upgrade.manageCta'
	| 'legal.privacy'
	| 'legal.terms'
	| 'auth.deleteFailed'
	| 'ai.cardTitle'
	| 'ai.gated'
	| 'ai.upgradeCta'
	| 'ai.loading'
	| 'ai.error'
	| 'ai.empty'
	| 'ai.highlights'
	| 'ai.insights'
	| 'ai.optimalHours'
	| 'ai.burnout'
	| 'settings.dailyReminder'
	| 'settings.reminderHour'
	| 'settings.reminderMinute'
	| 'settings.reminderNext'
	| 'settings.weeklyRecap'
	| 'settings.streak.title'
	| 'settings.celebrateRecords'
	| 'settings.privacy.title'
	| 'settings.analytics'
	| 'settings.analytics.hint'
	| 'settings.startup.title'
	| 'settings.startup.hint'
	| 'landing.nav.guides'
	| 'landing.nav.macmanual'
	| 'landing.nav.pricing'
	| 'landing.guides.title'
	| 'landing.guides.sub'
	| 'landing.guides.cta'
	| 'landing.nav.open'
	| 'landing.nav.home'
	| 'landing.meta'
	| 'landing.kicker'
	| 'landing.hero.title'
	| 'landing.hero.sub'
	| 'landing.hero.hint'
	| 'landing.cta.web'
	| 'landing.cta.stores'
	| 'landing.flow.label'
	| 'landing.flow.plan'
	| 'landing.flow.focus'
	| 'landing.flow.complete'
	| 'landing.flow.reflect'
	| 'landing.feat.modes.title'
	| 'landing.feat.modes.body'
	| 'landing.feat.tasks.title'
	| 'landing.feat.tasks.body'
	| 'landing.feat.stats.title'
	| 'landing.feat.stats.body'
	| 'landing.feat.sync.title'
	| 'landing.feat.sync.body'
	| 'landing.download.title'
	| 'landing.download.body'
	| 'landing.download.ios'
	| 'landing.download.android'
	| 'landing.download.web'
	| 'landing.pricing.title'
	| 'landing.pricing.cta'
	| 'landing.faq.title'
	| 'landing.faq.offline.q'
	| 'landing.faq.offline.a'
	| 'landing.faq.devices.q'
	| 'landing.faq.devices.a'
	| 'landing.faq.price.q'
	| 'landing.faq.price.a'
	| 'landing.faq.account.q'
	| 'landing.faq.account.a'
	| 'guides.title'
	| 'guides.meta'
	| 'guides.intro'
	| 'guides.soon'
	| 'guides.list.macos'
	| 'guides.list.macos.body'
	| 'guides.list.iphone'
	| 'guides.list.watchos'
	| 'guides.list.android'
	| 'guides.list.wearos'
	| 'guides.list.web'
	| 'guides.list.generic.body';

type Dict = Record<MessageKey, string>;

const en: Dict = {
	'app.name': 'Pepinillo',
	'app.tagline': 'Plan, focus, and celebrate your deep work — natively, on every screen you own.',
	'nav.focus': 'Focus',
	'nav.plan': 'Plan',
	'nav.dashboard': 'Dashboard',
	'nav.account': 'Account',
	'footer.companion':
		'Companion extra — not a full OS replacement. Best with the tab open during sessions.',
	'onboarding.title': 'Welcome to the Pepinillo web companion',
	'onboarding.body':
		'Use Focus, Plan, and Dashboard on a large screen without installing another app. This is a companion surface — widgets, tray, watch, and Live Activity stay on native apps.',
	'onboarding.limits':
		'Free includes Pomodoro + Stopwatch, up to 3 active tasks, and analytics for today + the last 7 days.',
	'onboarding.browserOnly':
		'Free data lives in this browser only. Clearing site data, using another browser, or resetting the profile will lose it.',
	'onboarding.timerHonesty':
		'Best experience: keep this tab open during a session. Browsers may throttle background timers — we do not claim OS-level timer survival.',
	'onboarding.continue': 'Start focusing',
	'onboarding.skip': 'Skip',
	'focus.title': 'Focus',
	'focus.honesty': 'Keep this tab open for reliable timing. Background tabs may throttle.',
	'focus.start': 'Start',
	'focus.pause': 'Pause',
	'focus.resume': 'Resume',
	'focus.skip': 'Skip',
	'focus.complete': 'Complete',
	'focus.reset': 'New session',
	'focus.journal': 'Session journal',
	'focus.linkTask': 'Link task',
	'focus.noTask': 'No task',
	'focus.mode.pomodoro': 'Pomodoro',
	'focus.mode.stopwatch': 'Stopwatch',
	'focus.mode.flowtime': 'Flowtime',
	'focus.mode.timeblock': 'Time Block',
	'focus.mode.locked': 'Everywhere',
	'focus.upgradeTeaser':
		'Flowtime and Time Block unlock with Everywhere (subscribe or restore on iOS, Android, or Windows). No purchase on web yet.',
	'focus.autoStart': 'Auto-start next segment',
	'focus.suggest.title': 'Suggested for now',
	'focus.suggest.apply': 'Apply',
	'focus.suggest.locked': 'Unlock with Everywhere',
	'focus.suggest.morning': 'Morning energy — short focused sprints work well.',
	'focus.suggest.deep': 'Deep work window — Flowtime helps you stay in flow.',
	'focus.suggest.afternoon': 'Afternoon structure — Time Block protects the calendar.',
	'focus.suggest.evening': 'Evening wind-down — one more Pomodoro, then rest.',
	'focus.suggest.flexible': 'Flexible hours — Stopwatch without pressure.',
	'focus.phase.idle': 'Ready',
	'focus.phase.running': 'In session',
	'focus.phase.paused': 'Paused',
	'focus.phase.completed': 'Done',
	'plan.title': 'Plan',
	'plan.add': 'Add task',
	'plan.search': 'Search tasks',
	'plan.newTask': 'New task',
	'plan.search.empty': 'No tasks match your search',
	'dashboard.refresh': 'Refresh',
	'plan.empty': 'No tasks yet. Add up to 3 active tasks on Free.',
	'plan.capBlocked': 'Free allows up to 3 active tasks.',
	'plan.upgradeTeaser':
		'Need more than 3 active tasks, subtasks, or recurrence? Everywhere unlocks them after you restore on a store app.',
	'plan.priority': 'Priority',
	'plan.energy': 'Energy',
	'plan.estPomos': 'Est. pomodoros',
	'plan.complete': 'Complete',
	'plan.delete': 'Delete',
	'plan.filter.all': 'All',
	'plan.filter.today': 'Today',
	'plan.filter.upcoming': 'Upcoming',
	'plan.filter.inbox': 'Inbox',
	'plan.quickPlaceholder': 'What needs focus?',
	'plan.activeCap': 'active',
	'plan.priority.low': 'Low',
	'plan.priority.medium': 'Med',
	'plan.priority.high': 'High',
	'plan.energy.low': 'Shallow',
	'plan.energy.medium': 'Balanced',
	'plan.energy.high': 'Deep',
	'plan.listLabel': 'List',
	'plan.showOptions': 'More',
	'plan.hideOptions': 'Less',
	'plan.focusTask': 'Focus',
	'plan.reorder': 'Reorder',
	'dashboard.title': 'Dashboard',
	'dashboard.subtitle': 'Reflect on what worked',
	'dashboard.today': 'Today',
	'dashboard.last7': 'Last 7 days',
	'dashboard.sessions': 'Sessions',
	'dashboard.minutes': 'Focus minutes',
	'dashboard.extendedGated':
		'30-day and 1-year views unlock with Everywhere. Free shows today + last 7 days.',
	'dashboard.empty': 'Complete a session to see your summary here.',
	'dashboard.heroCta': 'Start focusing',
	'dashboard.recent': 'Recent sessions',
	'dashboard.avgSession': 'Avg min / session',
	'account.title': 'Account',
	'account.subtitle': 'Identity, preferences, companion limits',
	'account.premiumThemes': 'Forest / Ocean / Sunset unlock with Everywhere.',
	'account.settings': 'Preferences',
	'account.storage': 'Local storage',
	'account.upgradeTitle': 'Everywhere',
	'account.pomodoro': 'Pomodoro lengths',
	'account.workMinutes': 'Work (minutes)',
	'account.breakMinutes': 'Break (minutes)',
	'account.export': 'Export local data',
	'account.exportHint': 'Download tasks, sessions, and preferences as JSON from this browser.',
	'toast.sessionComplete': 'Session saved. Nice work.',
	'toast.sessionSkipped': 'Session skipped and saved.',
	'toast.exportDone': 'Export downloaded.',
	'toast.signedIn': 'Signed in.',
	'toast.registered': 'Account created.',
	'toast.signedOut': 'Signed out.',
	'toast.syncOk': 'Local data uploaded.',
	'toast.syncMerged': 'Data combined from your devices.',
	'toast.syncPullDone': 'Updated from the cloud.',
	'account.signIn': 'Sign in',
	'account.signUp': 'Create account',
	'account.signOut': 'Sign out',
	'account.email': 'Email',
	'account.password': 'Password',
	'account.name': 'Name',
	'account.syncNow': 'Upload local data (Everywhere)',
	'account.syncing': 'Syncing…',
	'account.apiMissing':
		'API URL not configured. Set PUBLIC_API_BASE_URL in web/.env to enable account + sync.',
	'account.everywhereActive': 'Everywhere active — cloud sync available.',
	'account.everywhereInactive':
		'Signed in on Free. Subscribe or restore Everywhere on iOS, Android, or Windows, then refresh.',
	'account.signedInAs': 'Signed in as',
	'account.refreshEntitlement': 'Refresh subscription',
	'sync.everywhereRequired': 'Everywhere subscription required for cloud sync.',
	'sync.mergeExisting':
		'Server already had data for this account. Local data was merged (LWW). Review tasks on other devices.',
	'sync.ok': 'Upload complete.',
	'sync.pullError': 'Could not refresh from the cloud. Try again.',
	'sync.lastSync': 'Last sync',
	'sync.autoSyncOn': 'Auto-sync on — changes sync across devices.',
	'auth.required': 'Sign in first.',
	'account.appearance': 'Appearance',
	'account.theme.classic': 'Classic',
	'account.theme.forest': 'Forest',
	'account.theme.ocean': 'Ocean',
	'account.theme.sunset': 'Sunset',
	'landing.openApp': 'Open the app',
	'landing.wipNote': 'The new web app is being built with everything from the native apps.',
	'common.wip.title': 'It arrives in the next batch',
	'common.wip.body': 'This surface is being rebuilt with everything from the native apps.',
	'common.proLocked': 'Pepinillo+ feature',
	'focus.phase.work': 'Focus',
	'focus.phase.shortBreak': 'Short break',
	'focus.phase.longBreak': 'Long break',
	'focus.waitingBreak': 'Break ready when you are.',
	'focus.waitingWork': 'Next focus phase is ready when you are.',
	'focus.startBreak': 'Start break',
	'focus.startWork': 'Start focus',
	'focus.takeBreak': 'Take a break',
	'focus.ghost.title': 'Unfinished session',
	'focus.ghost.body': 'You left a {mode} session running ({time} recorded). Resume it or discard it.',
	'focus.ghost.resume': 'Resume',
	'focus.ghost.discard': 'Discard',
	'celebration.firstSession.title': 'First session!',
	'celebration.firstSession.body': 'The hardest part is starting. You did it.',
	'celebration.streak.title': '{days}-day streak!',
	'celebration.streak.body': 'Showing up day after day is how gardens grow.',
	'celebration.sessionCount.title': '{count} sessions!',
	'celebration.sessionCount.body': 'Momentum is real. Keep harvesting.',
	'celebration.personalBest.title': 'Personal best: {minutes}m',
	'celebration.personalBest.body': 'Your longest focus stretch yet. Deep work suits you.',
	'celebration.keepGoing': 'Keep going',
	'celebration.record.title': 'New streak record: {days} days',
	'celebration.record.dismiss': 'Dismiss record banner',
	'journal.title': 'How did it go?',
	'journal.subtitle': 'A quick note helps your weekly review.',
	'journal.rating.1': 'Rough',
	'journal.rating.2': 'Meh',
	'journal.rating.3': 'Okay',
	'journal.rating.4': 'Good',
	'journal.rating.5': 'Great',
	'journal.placeholder': 'What did you focus on? Anything to remember?',
	'journal.save': 'Save',
	'journal.skip': 'Skip',
	'taskPicker.title': 'Focus on a task',
	'taskPicker.empty': 'No active tasks yet — create some in Plan.',
	'taskPicker.unlink': 'No linked task',
	'soundscape.title': 'Soundscapes',
	'soundscape.none': 'None',
	'soundscape.rain': 'Rain',
	'soundscape.forest': 'Forest',
	'soundscape.cafe': 'Café',
	'soundscape.whiteNoise': 'White noise',
	'soundscape.ocean': 'Ocean',
	'soundscape.fireplace': 'Fireplace',
	'soundscape.binaural': 'Binaural',
	'soundscape.lofi': 'Lo-fi',
	'soundscape.volume': 'Volume',
	'soundscape.hint': 'Procedurally generated audio — synthesized live in your browser.',
	'companion.focusToday': 'Focus today',
	'companion.sessionsToday': 'Sessions today',
	'companion.streak': 'Streak',
	'companion.streakEmpty': 'Start your streak',
	'companion.pomodoroNumber': 'Pomodoro #',
	'companion.activeTask': 'Active task',
	'companion.suggest.title': 'Suggested for now',
	'companion.suggest.apply': 'Tap to apply',
	'adhd.breathe': 'Breathe slowly',
	'adhd.stretch': 'Stretch a little',
	'adhd.hydrate': 'Drink some water',
	'adhd.move': 'Move around',
	'adhd.subtitle': 'Guided break',
	'settings.focus.title': 'Focus',
	'settings.pomodoro.work': 'Work (min)',
	'settings.pomodoro.break': 'Short break (min)',
	'settings.pomodoro.longBreak': 'Long break (min)',
	'settings.pomodoro.sessions': 'Sessions before long break',
	'settings.autoStartBreaks': 'Auto-start breaks',
	'settings.autoStartWork': 'Auto-start next focus',
	'settings.flowtime.min': 'Flowtime: suggest break after (min)',
	'settings.timeblock.minutes': 'Time block (min)',
	'settings.timeblock.midpoint': 'Midpoint check-in',
	'settings.sound.title': 'Sound',
	'settings.sound.enabled': 'Completion sound',
	'settings.behavior.title': 'Behavior',
	'sound.classic': 'Classic',
	'sound.chime': 'Chime',
	'sound.bell': 'Bell',
	'sound.digital': 'Digital',
	'sound.woodblock': 'Woodblock',
	'settings.haptics': 'Vibration (if supported)',
	'settings.keepScreenOn': 'Keep screen on while focusing',
	'settings.journal': 'Journal after each session',
	'settings.adhd': 'Guided breaks (ADHD-friendly)',
	'settings.notifications': 'Phase notifications',
	'settings.notifications.hint': 'Browser notifications between phases. You will be asked for permission.',
	'plan.filter.completed': 'Completed',
	'plan.priority.none': 'None',
	'plan.energy.deep': 'Deep',
	'plan.energy.shallow': 'Shallow',
	'plan.energy.admin': 'Admin',
	'plan.energySuggest': 'Suggest for now',
	'plan.energyHint': 'Suggested energy right now: {energy}',
	'plan.due.today': 'Today',
	'plan.due.overdue': 'Overdue',
	'plan.dueDate': 'Due date',
	'plan.focusToday': 'Focus today',
	'plan.recurrence': 'Repeat',
	'plan.recurrence.daily': 'Daily',
	'plan.recurrence.weekdays': 'Weekdays',
	'plan.recurrence.weekly': 'Weekly',
	'plan.recurrence.biweekly': 'Every 2 weeks',
	'plan.recurrence.monthly': 'Monthly',
	'plan.notes': 'Notes',
	'plan.notesPlaceholder': 'Notes, links, context…',
	'plan.subtasks': 'Subtasks',
	'plan.subtaskAdd': 'Add a subtask and press Enter',
	'plan.subtaskDelete': 'Delete subtask',
	'plan.subtasksGate': 'Subtasks are a Pepinillo+ feature.',
	'plan.analytics': 'Focus history',
	'plan.analytics.sessions': '{count} sessions',
	'plan.analytics.focus': '{time} of focus',
	'plan.deleteConfirm': 'Tap again to delete',
	'plan.inspector': 'Task details',
	'plan.empty.today': 'Nothing for today',
	'plan.empty.inbox': 'Inbox zero',
	'plan.empty.all': 'Nothing here yet',
	'plan.empty.upcoming': 'Nothing scheduled ahead',
	'plan.empty.completed': 'No harvest yet',
	'plan.empty.body': 'Add your first task above — your garden starts here.',
	'quickCapture.title': 'Quick Capture',
	'quickCapture.placeholder': 'Capture a task…',
	'quickCapture.hint': '⌘K / Ctrl+K from anywhere',
	'quickCapture.captured': '{title} captured to Inbox',
	'palette.placeholder': 'Search commands or capture a task…',
	'palette.addTask': 'Add task',
	'palette.empty': 'No matching commands',
	'palette.focus': 'Focus',
	'palette.plan': 'Plan',
	'palette.dashboard': 'Dashboard',
	'palette.startFocus': 'Start focus session',
	'palette.toggleTheme': 'Toggle light / dark',
	'toast.undo': 'Undo',
	'period.7': '7D',
	'period.30': '30D',
	'period.365': '1Y',
	'chart.week': 'This week',
	'chart.window': 'Last {days} days',
	'chart.modes': 'Modes',
	'chart.day.sun': 'Sun',
	'chart.day.mon': 'Mon',
	'chart.day.tue': 'Tue',
	'chart.day.wed': 'Wed',
	'chart.day.thu': 'Thu',
	'chart.day.fri': 'Fri',
	'chart.day.sat': 'Sat',
	'dash.best': 'Best: {days}',
	'dash.focusScore': 'Focus score',
	'dash.peakHour': 'Peak hour',
	'dash.completion': 'Completion',
	'dash.longest': 'Longest session',
	'dash.periodFocus': 'Period focus',
	'score.exceptional': 'Exceptional week',
	'score.strong': 'Strong rhythm',
	'score.steady': 'Steady',
	'score.warming': 'Warming up',
	'score.rest': 'Rest week',
	'achievements.title': 'Achievements',
	'achievements.firstFocus.title': 'First Focus',
	'achievements.weekWarrior.title': 'Week Warrior',
	'achievements.pomodoroMaster.title': 'Pomodoro Master',
	'achievements.deepDiver.title': 'Deep Diver',
	'achievements.centuryClub.title': 'Century Club',
	'achievements.earlyBird.title': 'Early Bird',
	'sessions.recent': 'Recent sessions',
	'sessions.empty': 'Complete your first session to see it here.',
	'review.weekly': 'Weekly review',
	'review.monthly': 'Monthly review',
	'review.dataTab': 'Data',
	'review.aiTab': 'AI Insights',
	'review.aiSoon': 'AI insights arrive with Everywhere+ (coming to web).',
	'review.focus': 'Focus',
	'review.sessions': 'Sessions',
	'review.trendUp': 'Up {pct}% vs previous period',
	'review.trendDown': 'Down {pct}% vs previous period',
	'review.trendFlat': 'Same as previous period',
	'review.topTasks': 'Top tasks',
	'review.modes': 'Modes',
	'review.bestDay': 'Best day:',
	'auth.title': 'Account',
	'auth.subtitle': 'Sign in to sync your garden across devices.',
	'auth.signIn': 'Sign in',
	'auth.signUp': 'Create account',
	'auth.nameField': 'Name',
	'auth.emailField': 'Email',
	'auth.passwordField': 'Password (8+ characters)',
	'auth.working': 'Working…',
	'auth.needAccount': 'Need an account?',
	'auth.haveAccount': 'I have an account',
	'auth.forgot.link': 'Forgot password?',
	'auth.forgot.submit': 'Send reset link',
	'auth.forgot.sent': 'If the email exists, a reset link is on its way.',
	'auth.error.generic': 'Something went wrong. Try again.',
	'auth.error.invalidCredentials': 'Wrong email or password.',
	'auth.error.invalidEmail': 'That email does not look valid.',
	'auth.error.emailTaken': 'That email already has an account.',
	'auth.error.weakPassword': 'Use at least 8 characters.',
	'auth.error.apiMissing': 'The sync API is not configured for this build.',
	'auth.syncHint': 'Sync requires Everywhere/AI+. Your data always stays on this device first.',
	'auth.verifyPending': 'Check your inbox to verify your email — sync activates after that.',
	'auth.apiMissing': 'Cloud sync is not configured in this build (PUBLIC_API_BASE_URL empty). Everything works offline.',
	'auth.dangerTitle': 'Session',
	'auth.deleteConfirm': 'This removes your cloud account. Your email, to confirm:',
	'auth.deleteAccount': 'Delete account',
	'upgrade.title': 'Pricing',
	'upgrade.meta': 'Pepinillo pricing: free forever, Pepinillo+ one-time purchase, Everywhere/AI+ subscription with cloud sync and AI.',
	'upgrade.headline': 'Grow your focus, your way',
	'upgrade.sub': 'Start free forever. Pepinillo+ is one purchase, yours forever — no subscription. Everywhere/AI+ adds cloud sync and AI across every screen you own.',
	'upgrade.signedIn': 'Signed in as {email}',
	'upgrade.signInFirst': 'Sign in first to purchase on the web',
	'upgrade.plan.free': 'Free',
	'upgrade.plan.plus': 'Pepinillo+',
	'upgrade.plan.everywhere': 'Everywhere/AI+',
	'upgrade.price.free': '$0',
	'upgrade.price.plus': '$19.99 once',
	'upgrade.price.everywhere': '$4.99/mo · $34.99/yr',
	'upgrade.note.free': 'Everything to start a habit',
	'upgrade.note.plus': 'One purchase. Yours forever. Not a subscription.',
	'upgrade.note.everywhere': 'Everything in Pepinillo+, across every screen you own.',
	'upgrade.flag.best': 'Most complete',
	'upgrade.free.pomodoro': 'Pomodoro + Stopwatch',
	'upgrade.free.stopwatch': '3 active tasks',
	'upgrade.free.tasks': 'Analytics: today + 7 days',
	'upgrade.free.analytics': 'Complete offline, no account needed',
	'upgrade.plus.modes': 'Flowtime + Time Block',
	'upgrade.plus.tasks': 'Unlimited tasks',
	'upgrade.plus.subtasks': 'Subtasks + recurrence',
	'upgrade.plus.themes': 'Forest, Ocean and Sunset themes',
	'upgrade.plus.analytics': 'Full analytics (30 days + 1 year)',
	'upgrade.plus.soundscapes': 'All soundscapes',
	'upgrade.everywhere.plusIncluded': 'Everything in Pepinillo+',
	'upgrade.everywhere.sync': 'Cloud sync between devices (LWW, like the native apps)',
	'upgrade.everywhere.ai': 'AI insights: reviews, tips and predictions',
	'upgrade.everywhere.recovery': 'Account recovery — your data is safe even if you lose a device',
	'upgrade.everywhere.web': 'Full access to this web app',
	'upgrade.cta.free': 'Open the app',
	'upgrade.cta.plus': 'Buy once',
	'upgrade.cta.everywhere': 'Subscribe',
	'upgrade.working': 'Opening…',
	'upgrade.checkoutError': 'Could not open checkout. Try again in a moment.',
	'upgrade.portalError': 'Could not open the billing portal. Do you have a web subscription?',
	'upgrade.storesTitle': 'Prefer the native apps?',
	'upgrade.storesBody': 'Pepinillo lives natively on iPhone, iPad, Mac, Android and Wear OS — with widgets, watch complications and Live Activities.',
	'upgrade.storeApp': 'App Store',
	'upgrade.storePlay': 'Google Play',
	'upgrade.manageTitle': 'Manage your web subscription',
	'upgrade.manageBody': 'Change plan, update payment method or cancel — straight in the Stripe portal.',
	'upgrade.manageCta': 'Open billing portal',
	'legal.privacy': 'Privacy',
	'legal.terms': 'Terms',
	'auth.deleteFailed': 'Could not delete the account right now. Try again or contact support.',
	'ai.cardTitle': 'AI insights',
	'ai.gated': 'AI insights are an Everywhere/AI+ feature.',
	'ai.upgradeCta': 'Upgrade',
	'ai.loading': 'Thinking…',
	'ai.error': 'AI is unavailable right now. Try again later.',
	'ai.empty': 'No AI insights for this period yet — complete a few sessions first.',
	'ai.highlights': 'Highlights',
	'ai.insights': 'Insights',
	'ai.optimalHours': 'Optimal hours',
	'ai.burnout': 'Burnout risk',
	'settings.dailyReminder': 'Daily reminder',
	'settings.reminderHour': 'Hour',
	'settings.reminderMinute': 'Minute',
	'settings.reminderNext': 'next in {time}',
	'settings.weeklyRecap': 'Weekly recap notification',
	'settings.streak.title': 'Streak',
	'settings.celebrateRecords': 'Celebrate new records',
	'settings.privacy.title': 'Privacy',
	'settings.analytics': 'Share anonymous usage metrics',
	'settings.analytics.hint': 'PII-free aggregated stats. Off by default; nothing is sent unless you opt in.',
	'settings.startup.title': 'Startup',
	'settings.startup.hint': 'The section the app opens on (Mac parity).',
	'landing.nav.guides': 'Guides',
	'landing.nav.macmanual': 'macOS manual',
	'landing.nav.pricing': 'Pricing',
	'landing.guides.title': 'Learn to use every corner',
	'landing.guides.sub': 'The complete macOS user manual, with real screenshots of the app: from your first session to every keyboard shortcut.',
	'landing.guides.cta': 'Read the macOS manual',
	'landing.nav.open': 'Open app',
	'landing.nav.home': 'Home',
	'landing.meta': 'Pepinillo is a native companion for deep work: plan with intention, focus without noise, and celebrate your progress. iPhone, iPad, Mac, Android, Wear OS and web.',
	'landing.kicker': 'Deep work, native',
	'landing.hero.title': 'Plan with intention. Focus without noise. Celebrate what you grow.',
	'landing.hero.sub': 'Pepinillo is a native companion for deep work on every screen you own — a pomodoro timer that respects your brain, tasks organized by energy, and stats that help you understand your patterns.',
	'landing.hero.hint': 'The web app works offline and installs like a native app.',
	'landing.cta.web': 'Open the web app',
	'landing.cta.stores': 'Get the native apps',
	'landing.flow.label': 'The Pepinillo flow',
	'landing.flow.plan': 'Plan',
	'landing.flow.focus': 'Focus',
	'landing.flow.complete': 'Complete',
	'landing.flow.reflect': 'Reflect',
	'landing.feat.modes.title': 'Four ways to focus',
	'landing.feat.modes.body': 'Pomodoro for rhythm, Flowtime for deep immersion, Time Blocks for planned sessions, Stopwatch for open work. Your engine keeps running honestly on every device.',
	'landing.feat.tasks.title': 'Tasks that respect your energy',
	'landing.feat.tasks.body': 'Organize by priority and mental energy — deep, shallow, admin — with subtasks, recurrence and a daily suggestion based on your chronobiology.',
	'landing.feat.stats.title': 'Streaks worth celebrating',
	'landing.feat.stats.body': 'Weekly and monthly reviews, focus score, personal records and milestones that fire exactly when you earn them. Your garden grows with every session.',
	'landing.feat.sync.title': 'Everywhere you work',
	'landing.feat.sync.body': 'Everywhere/AI+ syncs your data between devices the same way the native apps do, and adds AI insights: reviews, tips and predictions.',
	'landing.download.title': 'Native on every screen',
	'landing.download.body': 'Widgets, watch complications, Live Activities, menu bar — Pepinillo feels at home on each platform. This web app is the newest member of the family.',
	'landing.download.ios': 'iPhone & iPad',
	'landing.download.android': 'Android',
	'landing.download.web': 'Use the web app',
	'landing.pricing.title': 'Simple, honest pricing',
	'landing.pricing.cta': 'See full pricing',
	'landing.faq.title': 'Frequently asked',
	'landing.faq.offline.q': 'Does it work offline?',
	'landing.faq.offline.a': 'Yes — everything runs on your device first. The web app stores your data locally and works without connection; cloud sync is an Everywhere/AI+ extra.',
	'landing.faq.devices.q': 'Which devices are supported?',
	'landing.faq.devices.a': 'iPhone, iPad, Mac, Android, Wear OS and this web app. Your engine, tasks and stats behave the same everywhere.',
	'landing.faq.price.q': 'Is the web version free?',
	'landing.faq.price.a': 'Yes. The web app is free with the same limits as mobile free: Pomodoro + Stopwatch, 3 active tasks and 7 days of analytics. Pepinillo+ and Everywhere/AI+ unlock the rest.',
	'landing.faq.account.q': 'Do I need an account?',
	'landing.faq.account.a': 'No. You can use everything offline without signing up. An account is only needed for cloud sync and AI (Everywhere/AI+).',
	'guides.title': 'User guides',
	'guides.meta': 'Step-by-step user guides for Pepinillo on Mac, iPhone, iPad, watchOS, Android, Wear OS and web.',
	'guides.intro': 'Learn every corner of Pepinillo, platform by platform.',
	'guides.soon': 'Coming soon',
	'guides.list.macos': 'Mac — manual & touch guide',
	'guides.list.macos.body': 'Menu bar, Notch panel, Quick Capture, keyboard shortcuts and the new touch gestures.',
	'guides.list.iphone': 'iPhone & iPad',
	'guides.list.watchos': 'watchOS',
	'guides.list.android': 'Android',
	'guides.list.wearos': 'Wear OS',
	'guides.list.web': 'Web app',
	'guides.list.generic.body': 'The full guide for this platform is on its way.',
	'sync.title': 'Cloud sync',
	'sync.hint': 'Last-Write-Wins with the server clock, like the native apps.',
	'sync.last': 'Last sync',
	'sync.live': 'Live updates connected',
	'sync.offline': 'Live updates off',
	'sync.mergeTitle': 'We found cloud data',
	'sync.mergeBody': 'This account already has data in the cloud. Keep the cloud version, or overwrite the cloud with what is on this device?',
	'sync.mergePull': 'Use the cloud data',
	'sync.mergeUpload': 'Upload this device',
	'account.tier': 'Plan',
	'account.tierFree': 'Free · local browser only',
	'account.locale': 'Language',
	'account.theme': 'Theme',
	'account.theme.system': 'System',
	'account.theme.light': 'Light',
	'account.theme.dark': 'Dark',
	'account.storageWarning':
		'Your Free data is stored only in this browser profile. Clearing storage or switching browsers loses it. Multi-device sync is not available on Free.',
	'account.everywhereTeaser':
		'Pepinillo Everywhere (sync + premium web features) is restored via your store purchase and account — not sold as Pepinillo+ on web. Sign-in arrives in a later slice.',
	'account.about':
		'Web is a companion extra for large-screen focus. It does not replace native OS features.',
	'account.nonGoals':
		'Not on web: tray, global hotkeys, home/lock widgets, Live Activity, watch companions, Health, CloudKit, team collab, notes editor.',
	'account.deviceId': 'Device id (local)'
};

const es: Dict = {
	...en,
	'app.tagline': 'Planifica, enfócate y celebra tu deep work — nativo, en todas tus pantallas.',
	'nav.focus': 'Foco',
	'nav.plan': 'Plan',
	'nav.dashboard': 'Panel',
	'nav.account': 'Cuenta',
	'footer.companion':
		'Extra compañero — no reemplaza el SO. Mejor con la pestaña abierta durante las sesiones.',
	'onboarding.title': 'Bienvenido al compañero web de Pepinillo',
	'onboarding.body':
		'Usá Focus, Plan y Dashboard en pantalla grande sin instalar otra app. Es una superficie compañera: widgets, bandeja, reloj y Live Activity siguen en las apps nativas.',
	'onboarding.limits':
		'Free incluye Pomodoro + Cronómetro, hasta 3 tareas activas y analíticas de hoy + últimos 7 días.',
	'onboarding.browserOnly':
		'Los datos Free viven solo en este navegador. Borrar datos del sitio, usar otro navegador o resetear el perfil los pierde.',
	'onboarding.timerHonesty':
		'Mejor experiencia: mantené esta pestaña abierta. Los navegadores pueden limitar temporizadores en segundo plano — no prometemos supervivencia a nivel SO.',
	'onboarding.continue': 'Empezar a enfocarme',
	'onboarding.skip': 'Omitir',
	'focus.title': 'Foco',
	'focus.honesty':
		'Mantené esta pestaña abierta para un tiempo confiable. Las pestañas en segundo plano pueden limitarse.',
	'focus.start': 'Iniciar',
	'focus.pause': 'Pausar',
	'focus.resume': 'Reanudar',
	'focus.skip': 'Saltar',
	'focus.complete': 'Completar',
	'focus.reset': 'Nueva sesión',
	'focus.journal': 'Diario de sesión',
	'focus.linkTask': 'Vincular tarea',
	'focus.noTask': 'Sin tarea',
	'focus.mode.pomodoro': 'Pomodoro',
	'focus.mode.stopwatch': 'Cronómetro',
	'focus.mode.flowtime': 'Flowtime',
	'focus.mode.timeblock': 'Time Block',
	'focus.mode.locked': 'Everywhere',
	'focus.upgradeTeaser':
		'Flowtime y Time Block se desbloquean con Everywhere (suscribite o restaurá en iOS, Android o Windows). Aún no hay compra en web.',
	'focus.autoStart': 'Auto-iniciar siguiente segmento',
	'focus.suggest.title': 'Sugerido ahora',
	'focus.suggest.apply': 'Aplicar',
	'focus.suggest.locked': 'Desbloqueá con Everywhere',
	'focus.suggest.morning': 'Energía de mañana — sprints cortos rinden bien.',
	'focus.suggest.deep': 'Ventana de deep work — Flowtime te ayuda a flotar.',
	'focus.suggest.afternoon': 'Estructura de tarde — Time Block protege el calendario.',
	'focus.suggest.evening': 'Cierre del día — un Pomodoro más y a descansar.',
	'focus.suggest.flexible': 'Horario flexible — Cronómetro sin presión.',
	'focus.phase.idle': 'Listo',
	'focus.phase.running': 'En sesión',
	'focus.phase.paused': 'Pausado',
	'focus.phase.completed': 'Listo',
	'plan.title': 'Plan',
	'plan.add': 'Agregar tarea',
	'plan.search': 'Buscar tareas',
	'plan.newTask': 'Nueva tarea',
	'plan.search.empty': 'Ninguna tarea coincide con tu búsqueda',
	'dashboard.refresh': 'Actualizar',
	'plan.empty': 'Sin tareas aún. En Free podés tener hasta 3 activas.',
	'plan.capBlocked': 'Free permite hasta 3 tareas activas.',
	'plan.upgradeTeaser':
		'¿Más de 3 tareas activas, subtareas o recurrencia? Everywhere las desbloquea al restaurar en una app de tienda.',
	'plan.priority': 'Prioridad',
	'plan.energy': 'Energía',
	'plan.estPomos': 'Pomodoros est.',
	'plan.complete': 'Completar',
	'plan.delete': 'Eliminar',
	'plan.filter.all': 'Todas',
	'plan.filter.today': 'Hoy',
	'plan.filter.upcoming': 'Próximas',
	'plan.filter.inbox': 'Bandeja',
	'plan.quickPlaceholder': '¿En qué te enfocás?',
	'plan.activeCap': 'activas',
	'plan.priority.low': 'Baja',
	'plan.priority.medium': 'Media',
	'plan.priority.high': 'Alta',
	'plan.energy.low': 'Ligera',
	'plan.energy.medium': 'Media',
	'plan.energy.high': 'Profunda',
	'plan.listLabel': 'Lista',
	'plan.showOptions': 'Más',
	'plan.hideOptions': 'Menos',
	'plan.focusTask': 'Foco',
	'plan.reorder': 'Orden',
	'dashboard.title': 'Panel',
	'dashboard.today': 'Hoy',
	'dashboard.last7': 'Últimos 7 días',
	'dashboard.sessions': 'Sesiones',
	'dashboard.minutes': 'Minutos de foco',
	'dashboard.extendedGated':
		'Las vistas de 30 días y 1 año se desbloquean con Everywhere. Free muestra hoy + últimos 7 días.',
	'dashboard.empty': 'Completá una sesión para ver el resumen aquí.',
	'dashboard.subtitle': 'Reflexioná sobre lo que funcionó',
	'dashboard.heroCta': 'Empezar a enfocarme',
	'dashboard.recent': 'Sesiones recientes',
	'dashboard.avgSession': 'Min prom. / sesión',
	'account.title': 'Cuenta',
	'account.tier': 'Plan',
	'account.tierFree': 'Free · solo navegador local',
	'account.locale': 'Idioma',
	'account.theme': 'Tema',
	'account.theme.system': 'Sistema',
	'account.theme.light': 'Claro',
	'account.theme.dark': 'Oscuro',
	'account.storageWarning':
		'Tus datos Free se guardan solo en este perfil del navegador. Borrar almacenamiento o cambiar de navegador los pierde. La sync multi-dispositivo no está en Free.',
	'account.everywhereTeaser':
		'Pepinillo Everywhere (sync + premium web) se restaura con la compra de tienda y la cuenta — no se vende Pepinillo+ en web. El inicio de sesión llega en una etapa posterior.',
	'account.about':
		'La web es un extra compañero para foco en pantalla grande. No reemplaza funciones nativas del SO.',
	'account.nonGoals':
		'No en web: bandeja, atajos globales, widgets, Live Activity, reloj, Health, CloudKit, colaboración en equipo, editor de notas.',
	'account.deviceId': 'Id de dispositivo (local)',
	'account.subtitle': 'Identidad, preferencias y límites del compañero',
	'account.premiumThemes': 'Forest / Ocean / Sunset se desbloquean con Everywhere.',
	'account.settings': 'Preferencias',
	'account.storage': 'Almacenamiento local',
	'account.upgradeTitle': 'Everywhere',
	'account.pomodoro': 'Duraciones Pomodoro',
	'account.workMinutes': 'Trabajo (minutos)',
	'account.breakMinutes': 'Descanso (minutos)',
	'account.export': 'Exportar datos locales',
	'account.exportHint': 'Descargá tareas, sesiones y preferencias como JSON de este navegador.',
	'toast.sessionComplete': 'Sesión guardada. Buen trabajo.',
	'toast.sessionSkipped': 'Sesión saltada y guardada.',
	'toast.exportDone': 'Exportación descargada.',
	'toast.signedIn': 'Sesión iniciada.',
	'toast.registered': 'Cuenta creada.',
	'toast.signedOut': 'Sesión cerrada.',
	'toast.syncOk': 'Datos locales subidos.',
	'toast.syncMerged': 'Datos combinados de tus dispositivos.',
	'toast.syncPullDone': 'Actualizado desde la nube.',
	'account.signIn': 'Iniciar sesión',
	'account.signUp': 'Crear cuenta',
	'account.signOut': 'Cerrar sesión',
	'account.email': 'Email',
	'account.password': 'Contraseña',
	'account.name': 'Nombre',
	'account.syncNow': 'Subir datos locales (Everywhere)',
	'account.syncing': 'Sincronizando…',
	'account.apiMissing':
		'API no configurada. Definí PUBLIC_API_BASE_URL en web/.env para cuenta + sync.',
	'account.everywhereActive': 'Everywhere activo — sync en la nube disponible.',
	'account.everywhereInactive':
		'Sesión Free. Suscribite o restaurá Everywhere en iOS, Android o Windows y refrescá.',
	'account.signedInAs': 'Sesión como',
	'account.refreshEntitlement': 'Actualizar suscripción',
	'sync.everywhereRequired': 'Se requiere Everywhere para sync en la nube.',
	'sync.mergeExisting':
		'El servidor ya tenía datos. Se fusionó lo local (LWW). Revisá en otros dispositivos.',
	'sync.ok': 'Subida completa.',
	'sync.pullError': 'No se pudo actualizar desde la nube. Intentá de nuevo.',
	'sync.lastSync': 'Última sync',
	'sync.autoSyncOn': 'Auto-sync activo — los cambios se sincronizan entre dispositivos.',
	'auth.required': 'Iniciá sesión primero.',
	'account.appearance': 'Apariencia',
	'account.theme.classic': 'Clásico',
	'account.theme.forest': 'Bosque',
	'account.theme.ocean': 'Océano',
	'account.theme.sunset': 'Atardecer',
	'landing.openApp': 'Abrir la app',
	'landing.wipNote': 'La nueva web se está construyendo con todo de las apps nativas.',
	'common.wip.title': 'Llega en el próximo lote',
	'common.wip.body': 'Esta superficie se está reconstruyendo con todo de las apps nativas.',
	'common.proLocked': 'Función de Pepinillo+',
	'focus.phase.work': 'Enfoque',
	'focus.phase.shortBreak': 'Descanso corto',
	'focus.phase.longBreak': 'Descanso largo',
	'focus.waitingBreak': 'El descanso está listo cuando vos lo estés.',
	'focus.waitingWork': 'El próximo enfoque está listo cuando vos lo estés.',
	'focus.startBreak': 'Comenzar descanso',
	'focus.startWork': 'Comenzar enfoque',
	'focus.takeBreak': 'Tomar un descanso',
	'focus.ghost.title': 'Sesión inconclusa',
	'focus.ghost.body': 'Dejaste una sesión de {mode} corriendo ({time} registrados). Retomalá o descartala.',
	'focus.ghost.resume': 'Retomar',
	'focus.ghost.discard': 'Descartar',
	'celebration.firstSession.title': '¡Primera sesión!',
	'celebration.firstSession.body': 'Lo más difícil es empezar. ¡Lo lograste!',
	'celebration.streak.title': '¡Racha de {days} días!',
	'celebration.streak.body': 'Presentarse día tras día es como crece el huerto.',
	'celebration.sessionCount.title': '¡{count} sesiones!',
	'celebration.sessionCount.body': 'El impulso es real. Seguí cosechando.',
	'celebration.personalBest.title': 'Récord personal: {minutes}m',
	'celebration.personalBest.body': 'Tu tramo de enfoque más largo hasta ahora. El deep work te queda.',
	'celebration.keepGoing': '¡Seguí así!',
	'celebration.record.title': 'Nuevo récord de racha: {days} días',
	'celebration.record.dismiss': 'Cerrar aviso de récord',
	'journal.title': '¿Cómo te fue?',
	'journal.subtitle': 'Una nota rápida ayuda a tu repaso semanal.',
	'journal.rating.1': 'Duro',
	'journal.rating.2': 'Meh',
	'journal.rating.3': 'Okay',
	'journal.rating.4': 'Bien',
	'journal.rating.5': '¡Genial!',
	'journal.placeholder': '¿En qué te enfocaste? ¿Algo para recordar?',
	'journal.save': 'Guardar',
	'journal.skip': 'Omitir',
	'taskPicker.title': 'Enfocate en una tarea',
	'taskPicker.empty': 'Todavía no hay tareas activas — crealas en Plan.',
	'taskPicker.unlink': 'Sin tarea vinculada',
	'soundscape.title': 'Paisajes sonoros',
	'soundscape.none': 'Ninguno',
	'soundscape.rain': 'Lluvia',
	'soundscape.forest': 'Bosque',
	'soundscape.cafe': 'Café',
	'soundscape.whiteNoise': 'Ruido blanco',
	'soundscape.ocean': 'Océano',
	'soundscape.fireplace': 'Fogata',
	'soundscape.binaural': 'Binaural',
	'soundscape.lofi': 'Lo-fi',
	'soundscape.volume': 'Volumen',
	'soundscape.hint': 'Audio generado por síntesis en tu navegador, sin descargas.',
	'companion.focusToday': 'Enfoque hoy',
	'companion.sessionsToday': 'Sesiones hoy',
	'companion.streak': 'Racha',
	'companion.streakEmpty': 'Empezá tu racha',
	'companion.pomodoroNumber': 'Pomodoro n.º',
	'companion.activeTask': 'Tarea activa',
	'companion.suggest.title': 'Sugerido para ahora',
	'companion.suggest.apply': 'Tocá para aplicarlo',
	'adhd.breathe': 'Respirá lento',
	'adhd.stretch': 'Estiráte un poco',
	'adhd.hydrate': 'Tomá agua',
	'adhd.move': 'Movete un poco',
	'adhd.subtitle': 'Descanso guiado',
	'settings.focus.title': 'Enfoque',
	'settings.pomodoro.work': 'Trabajo (min)',
	'settings.pomodoro.break': 'Descanso corto (min)',
	'settings.pomodoro.longBreak': 'Descanso largo (min)',
	'settings.pomodoro.sessions': 'Sesiones antes del descanso largo',
	'settings.autoStartBreaks': 'Auto-iniciar descansos',
	'settings.autoStartWork': 'Auto-iniciar el próximo enfoque',
	'settings.flowtime.min': 'Flowtime: sugerir descanso tras (min)',
	'settings.timeblock.minutes': 'Bloque de tiempo (min)',
	'settings.timeblock.midpoint': 'Check-in a mitad',
	'settings.sound.title': 'Sonido',
	'settings.sound.enabled': 'Sonido de finalización',
	'settings.behavior.title': 'Comportamiento',
	'sound.classic': 'Clásico',
	'sound.chime': 'Campanillas',
	'sound.bell': 'Campana',
	'sound.digital': 'Digital',
	'sound.woodblock': 'Madera',
	'settings.haptics': 'Vibración (si está soportada)',
	'settings.keepScreenOn': 'Mantener pantalla encendida al enfocar',
	'settings.journal': 'Journal tras cada sesión',
	'settings.adhd': 'Descansos guiados (modo TDAH)',
	'settings.notifications': 'Notificaciones de fase',
	'settings.notifications.hint': 'Notificaciones del navegador entre fases. Se pedirá permiso.',
	'plan.filter.completed': 'Completadas',
	'plan.priority.none': 'Sin prioridad',
	'plan.energy.deep': 'Profunda',
	'plan.energy.shallow': 'Superficial',
	'plan.energy.admin': 'Admin',
	'plan.energySuggest': 'Sugerir para ahora',
	'plan.energyHint': 'Energía sugerida ahora: {energy}',
	'plan.due.today': 'Hoy',
	'plan.due.overdue': 'Atrasada',
	'plan.dueDate': 'Fecha límite',
	'plan.focusToday': 'Enfoque hoy',
	'plan.recurrence': 'Repetir',
	'plan.recurrence.daily': 'Diaria',
	'plan.recurrence.weekdays': 'Días de semana',
	'plan.recurrence.weekly': 'Semanal',
	'plan.recurrence.biweekly': 'Cada 2 semanas',
	'plan.recurrence.monthly': 'Mensual',
	'plan.notes': 'Notas',
	'plan.notesPlaceholder': 'Notas, links, contexto…',
	'plan.subtasks': 'Subtareas',
	'plan.subtaskAdd': 'Agregá una subtarea y apretá Enter',
	'plan.subtaskDelete': 'Eliminar subtarea',
	'plan.subtasksGate': 'Las subtareas son de Pepinillo+.',
	'plan.analytics': 'Historial de foco',
	'plan.analytics.sessions': '{count} sesiones',
	'plan.analytics.focus': '{time} de foco',
	'plan.deleteConfirm': 'Tocá de nuevo para eliminar',
	'plan.inspector': 'Detalle de tarea',
	'plan.empty.today': 'Nada para hoy',
	'plan.empty.inbox': 'Bandeja en cero',
	'plan.empty.all': 'Nada por aquí todavía',
	'plan.empty.upcoming': 'Nada agendado',
	'plan.empty.completed': 'Aún sin cosecha',
	'plan.empty.body': 'Agregá tu primera tarea arriba — tu huerto empieza acá.',
	'quickCapture.title': 'Captura rápida',
	'quickCapture.placeholder': 'Capturar una tarea…',
	'quickCapture.hint': '⌘K / Ctrl+K desde cualquier lugar',
	'quickCapture.captured': '{title} capturada en Inbox',
	'palette.placeholder': 'Buscá comandos o capturá una tarea…',
	'palette.addTask': 'Agregar tarea',
	'palette.empty': 'Sin comandos que coincidan',
	'palette.focus': 'Focus',
	'palette.plan': 'Plan',
	'palette.dashboard': 'Dashboard',
	'palette.startFocus': 'Iniciar sesión de foco',
	'palette.toggleTheme': 'Cambiar claro / oscuro',
	'toast.undo': 'Deshacer',
	'period.7': '7D',
	'period.30': '30D',
	'period.365': '1A',
	'chart.week': 'Esta semana',
	'chart.window': 'Últimos {days} días',
	'chart.modes': 'Modos',
	'chart.day.sun': 'Dom',
	'chart.day.mon': 'Lun',
	'chart.day.tue': 'Mar',
	'chart.day.wed': 'Mié',
	'chart.day.thu': 'Jue',
	'chart.day.fri': 'Vie',
	'chart.day.sat': 'Sáb',
	'dash.best': 'Récord: {days}',
	'dash.focusScore': 'Puntaje de foco',
	'dash.peakHour': 'Hora pico',
	'dash.completion': 'Finalización',
	'dash.longest': 'Sesión más larga',
	'dash.periodFocus': 'Foco del período',
	'score.exceptional': 'Semana excepcional',
	'score.strong': 'Ritmo sólido',
	'score.steady': 'Constante',
	'score.warming': 'Calentando',
	'score.rest': 'Semana de descanso',
	'achievements.title': 'Logros',
	'achievements.firstFocus.title': 'Primer Foco',
	'achievements.weekWarrior.title': 'Guerrero Semanal',
	'achievements.pomodoroMaster.title': 'Maestro Pomodoro',
	'achievements.deepDiver.title': 'Buzo Profundo',
	'achievements.centuryClub.title': 'Club de los Cien',
	'achievements.earlyBird.title': 'Madrugador',
	'sessions.recent': 'Sesiones recientes',
	'sessions.empty': 'Completá tu primera sesión para verla acá.',
	'review.weekly': 'Repaso semanal',
	'review.monthly': 'Repaso mensual',
	'review.dataTab': 'Datos',
	'review.aiTab': 'Insights IA',
	'review.aiSoon': 'Los insights de IA llegan con Everywhere+ (pronto en web).',
	'review.focus': 'Foco',
	'review.sessions': 'Sesiones',
	'review.trendUp': 'Subiste {pct}% vs el período anterior',
	'review.trendDown': 'Bajaste {pct}% vs el período anterior',
	'review.trendFlat': 'Igual que el período anterior',
	'review.topTasks': 'Tareas top',
	'review.modes': 'Modos',
	'review.bestDay': 'Mejor día:',
	'auth.title': 'Cuenta',
	'auth.subtitle': 'Iniciá sesión para sincronizar tu huerto entre dispositivos.',
	'auth.signIn': 'Iniciar sesión',
	'auth.signUp': 'Crear cuenta',
	'auth.nameField': 'Nombre',
	'auth.emailField': 'Email',
	'auth.passwordField': 'Contraseña (8+ caracteres)',
	'auth.working': 'Un momento…',
	'auth.needAccount': '¿No tenés cuenta?',
	'auth.haveAccount': 'Ya tengo cuenta',
	'auth.forgot.link': '¿Olvidaste la contraseña?',
	'auth.forgot.submit': 'Enviar link de recuperación',
	'auth.forgot.sent': 'Si el email existe, el link va en camino.',
	'auth.error.generic': 'Algo salió mal. Probá de nuevo.',
	'auth.error.invalidCredentials': 'Email o contraseña incorrectos.',
	'auth.error.invalidEmail': 'Ese email no parece válido.',
	'auth.error.emailTaken': 'Ese email ya tiene una cuenta.',
	'auth.error.weakPassword': 'Usá al menos 8 caracteres.',
	'auth.error.apiMissing': 'El API de sync no está configurado en este build.',
	'auth.syncHint': 'La sync requiere Everywhere/AI+. Tus datos siempre viven primero en este dispositivo.',
	'auth.verifyPending': 'Revisá tu inbox para verificar el email — la sync se activa después.',
	'auth.apiMissing': 'La sync cloud no está configurada en este build (PUBLIC_API_BASE_URL vacío). Todo funciona offline.',
	'auth.dangerTitle': 'Sesión',
	'auth.deleteConfirm': 'Esto elimina tu cuenta en la nube. Tu email, para confirmar:',
	'auth.deleteAccount': 'Eliminar cuenta',
	'upgrade.title': 'Precios',
	'upgrade.meta': 'Precios de Pepinillo: free para siempre, Pepinillo+ compra única, Everywhere/AI+ suscripción con sync cloud e IA.',
	'upgrade.headline': 'Cultivá tu foco, a tu manera',
	'upgrade.sub': 'Empezá gratis para siempre. Pepinillo+ es una compra, tuya para siempre — no es una suscripción. Everywhere/AI+ suma sync cloud e IA en todas tus pantallas.',
	'upgrade.signedIn': 'Sesión iniciada como {email}',
	'upgrade.signInFirst': 'Iniciá sesión primero para comprar en la web',
	'upgrade.plan.free': 'Free',
	'upgrade.plan.plus': 'Pepinillo+',
	'upgrade.plan.everywhere': 'Everywhere/AI+',
	'upgrade.price.free': '$0',
	'upgrade.price.plus': '$19.99 una vez',
	'upgrade.price.everywhere': '$4.99/mes · $34.99/año',
	'upgrade.note.free': 'Todo para empezar el hábito',
	'upgrade.note.plus': 'Una compra. Tuya para siempre. No es una suscripción.',
	'upgrade.note.everywhere': 'Todo lo de Pepinillo+, en todas tus pantallas.',
	'upgrade.flag.best': 'El más completo',
	'upgrade.free.pomodoro': 'Pomodoro + Cronómetro',
	'upgrade.free.stopwatch': '3 tareas activas',
	'upgrade.free.tasks': 'Analítica: hoy + 7 días',
	'upgrade.free.analytics': 'Offline completo, sin cuenta',
	'upgrade.plus.modes': 'Flowtime + Bloques de tiempo',
	'upgrade.plus.tasks': 'Tareas ilimitadas',
	'upgrade.plus.subtasks': 'Subtareas + recurrencia',
	'upgrade.plus.themes': 'Temas Bosque, Océano y Atardecer',
	'upgrade.plus.analytics': 'Analítica completa (30 días + 1 año)',
	'upgrade.plus.soundscapes': 'Todos los paisajes sonoros',
	'upgrade.everywhere.plusIncluded': 'Todo lo de Pepinillo+',
	'upgrade.everywhere.sync': 'Sync cloud entre dispositivos (LWW, como en las apps nativas)',
	'upgrade.everywhere.ai': 'Insights de IA: repasos, tips y predicciones',
	'upgrade.everywhere.recovery': 'Recuperación de cuenta — tus datos a salvo aunque pierdas un dispositivo',
	'upgrade.everywhere.web': 'Acceso completo a esta app web',
	'upgrade.cta.free': 'Abrir la app',
	'upgrade.cta.plus': 'Comprar una vez',
	'upgrade.cta.everywhere': 'Suscribirme',
	'upgrade.working': 'Abriendo…',
	'upgrade.checkoutError': 'No pudimos abrir el checkout. Probá en un momento.',
	'upgrade.portalError': 'No pudimos abrir el portal de pagos. ¿Tenés una suscripción web?',
	'upgrade.storesTitle': '¿Preferís las apps nativas?',
	'upgrade.storesBody': 'Pepinillo vive nativo en iPhone, iPad, Mac, Android y Wear OS — con widgets, complicaciones de reloj y Live Activities.',
	'upgrade.storeApp': 'App Store',
	'upgrade.storePlay': 'Google Play',
	'upgrade.manageTitle': 'Gestioná tu suscripción web',
	'upgrade.manageBody': 'Cambiá de plan, actualizá el medio de pago o cancelá — directo en el portal de Stripe.',
	'upgrade.manageCta': 'Abrir portal de pagos',
	'legal.privacy': 'Privacidad',
	'legal.terms': 'Términos',
	'auth.deleteFailed': 'No pudimos eliminar la cuenta ahora. Probá de nuevo o contactá soporte.',
	'ai.cardTitle': 'Insights de IA',
	'ai.gated': 'Los insights de IA son de Everywhere/AI+.',
	'ai.upgradeCta': 'Mejorar',
	'ai.loading': 'Pensando…',
	'ai.error': 'La IA no está disponible ahora. Probá más tarde.',
	'ai.empty': 'Sin insights de IA para este período — completá unas sesiones primero.',
	'ai.highlights': 'Lo destacado',
	'ai.insights': 'Insights',
	'ai.optimalHours': 'Horas óptimas',
	'ai.burnout': 'Riesgo de burnout',
	'settings.dailyReminder': 'Recordatorio diario',
	'settings.reminderHour': 'Hora',
	'settings.reminderMinute': 'Minuto',
	'settings.reminderNext': 'próximo en {time}',
	'settings.weeklyRecap': 'Notificación de repaso semanal',
	'settings.streak.title': 'Racha',
	'settings.celebrateRecords': 'Celebrar nuevos récords',
	'settings.privacy.title': 'Privacidad',
	'settings.analytics': 'Compartir métricas anónimas de uso',
	'settings.analytics.hint': 'Estadísticas agregadas sin datos personales. Apagado por defecto; no se envía nada sin tu consentimiento.',
	'settings.startup.title': 'Inicio',
	'settings.startup.hint': 'La sección donde abre la app (paridad con Mac).',
	'landing.nav.guides': 'Guías',
	'landing.nav.macmanual': 'Manual de macOS',
	'landing.nav.pricing': 'Precios',
	'landing.guides.title': 'Aprende a usar cada rincón',
	'landing.guides.sub': 'El manual de usuario completo de macOS, con capturas reales de la app: desde tu primera sesión hasta cada atajo de teclado.',
	'landing.guides.cta': 'Leer el manual de macOS',
	'landing.nav.open': 'Abrir app',
	'landing.nav.home': 'Inicio',
	'landing.meta': 'Pepinillo es un compañero nativo de deep work: planificá con intención, enfocate sin ruido y celebrá lo que cultivás. iPhone, iPad, Mac, Android, Wear OS y web.',
	'landing.kicker': 'Deep work, nativo',
	'landing.hero.title': 'Planificá con intención. Enfocate sin ruido. Celebrá lo que cultivás.',
	'landing.hero.sub': 'Pepinillo es un compañero nativo de deep work en todas tus pantallas — un timer que respeta tu cerebro, tareas organizadas por energía y estadísticas que te ayudan a entender tus patrones.',
	'landing.hero.hint': 'La app web funciona offline y se instala como una app nativa.',
	'landing.cta.web': 'Abrir la app web',
	'landing.cta.stores': 'Descargar las apps nativas',
	'landing.flow.label': 'El flujo Pepinillo',
	'landing.flow.plan': 'Planificá',
	'landing.flow.focus': 'Enfocate',
	'landing.flow.complete': 'Completá',
	'landing.flow.reflect': 'Reflexioná',
	'landing.feat.modes.title': 'Cuatro formas de enfocarte',
	'landing.feat.modes.body': 'Pomodoro para el ritmo, Flowtime para la inmersión profunda, Bloques para sesiones planificadas, Cronómetro para trabajo abierto. Tu motor corre con honestidad en cada dispositivo.',
	'landing.feat.tasks.title': 'Tareas que respetan tu energía',
	'landing.feat.tasks.body': 'Organizá por prioridad y energía mental — profunda, superficial, admin — con subtareas, recurrencia y una sugerencia diaria basada en tu cronobiología.',
	'landing.feat.stats.title': 'Rachas que vale la pena celebrar',
	'landing.feat.stats.body': 'Repasos semanales y mensuales, puntaje de foco, récords personales e hitos que se disparan justo cuando te los ganás. Tu huerto crece con cada sesión.',
	'landing.feat.sync.title': 'En todos lados donde trabajás',
	'landing.feat.sync.body': 'Everywhere/AI+ sincroniza tus datos entre dispositivos igual que las apps nativas, y suma insights de IA: repasos, tips y predicciones.',
	'landing.download.title': 'Nativo en cada pantalla',
	'landing.download.body': 'Widgets, complicaciones de reloj, Live Activities, barra de menú — Pepinillo se siente de casa en cada plataforma. Esta app web es el nuevo miembro de la familia.',
	'landing.download.ios': 'iPhone y iPad',
	'landing.download.android': 'Android',
	'landing.download.web': 'Usar la app web',
	'landing.pricing.title': 'Precios simples y honestos',
	'landing.pricing.cta': 'Ver precios completos',
	'landing.faq.title': 'Preguntas frecuentes',
	'landing.faq.offline.q': '¿Funciona sin conexión?',
	'landing.faq.offline.a': 'Sí — todo corre primero en tu dispositivo. La app web guarda tus datos localmente y funciona sin conexión; la sync cloud es un extra de Everywhere/AI+.',
	'landing.faq.devices.q': '¿Qué dispositivos están soportados?',
	'landing.faq.devices.a': 'iPhone, iPad, Mac, Android, Wear OS y esta app web. Tu motor, tareas y estadísticas se comportan igual en todos lados.',
	'landing.faq.price.q': '¿La versión web es gratis?',
	'landing.faq.price.a': 'Sí. La app web es gratis con los mismos límites que mobile free: Pomodoro + Cronómetro, 3 tareas activas y 7 días de analítica. Pepinillo+ y Everywhere/AI+ desbloquean el resto.',
	'landing.faq.account.q': '¿Necesito una cuenta?',
	'landing.faq.account.a': 'No. Podés usar todo offline sin registrarte. La cuenta solo hace falta para la sync cloud y la IA (Everywhere/AI+).',
	'guides.title': 'Guías de usuario',
	'guides.meta': 'Guías paso a paso de Pepinillo en Mac, iPhone, iPad, watchOS, Android, Wear OS y web.',
	'guides.intro': 'Aprendé cada rincón de Pepinillo, plataforma por plataforma.',
	'guides.soon': 'Pronto disponible',
	'guides.list.macos': 'Mac — manual y guía touch',
	'guides.list.macos.body': 'Barra de menú, panel Notch, Quick Capture, atajos de teclado y los nuevos gestos táctiles.',
	'guides.list.iphone': 'iPhone y iPad',
	'guides.list.watchos': 'watchOS',
	'guides.list.android': 'Android',
	'guides.list.wearos': 'Wear OS',
	'guides.list.web': 'App web',
	'guides.list.generic.body': 'La guía completa de esta plataforma está en camino.',
	'sync.title': 'Sync cloud',
	'sync.hint': 'Last-Write-Wins con el reloj del servidor, como en las apps nativas.',
	'sync.last': 'Última sync',
	'sync.live': 'Actualizaciones en vivo conectadas',
	'sync.offline': 'Actualizaciones en vivo apagadas',
	'sync.mergeTitle': 'Encontramos datos en la nube',
	'sync.mergeBody': 'Esta cuenta ya tiene datos en la nube. ¿Te quedás con la versión de la nube o pisás la nube con lo que hay en este dispositivo?',
	'sync.mergePull': 'Usar los datos de la nube',
	'sync.mergeUpload': 'Subir este dispositivo'
};

const pt: Dict = {
	...en,
	'app.tagline': 'Planeje, concentre-se e celebre seu deep work — nativo, em todas as suas telas.',
	'nav.focus': 'Foco',
	'nav.plan': 'Plano',
	'nav.dashboard': 'Painel',
	'nav.account': 'Conta',
	'footer.companion':
		'Extra companheiro — não substitui o SO. Melhor com a aba aberta durante as sessões.',
	'onboarding.title': 'Bem-vindo ao companheiro web do Pepinillo',
	'onboarding.body':
		'Use Focus, Plan e Dashboard em tela grande sem instalar outro app. É uma superfície companheira — widgets, bandeja, relógio e Live Activity ficam nos apps nativos.',
	'onboarding.limits':
		'Free inclui Pomodoro + Cronômetro, até 3 tarefas ativas e analytics de hoje + últimos 7 dias.',
	'onboarding.browserOnly':
		'Os dados Free ficam só neste navegador. Limpar dados do site, usar outro navegador ou resetar o perfil os perde.',
	'onboarding.timerHonesty':
		'Melhor experiência: mantenha esta aba aberta. Navegadores podem limitar timers em segundo plano — não prometemos sobrevivência em nível de SO.',
	'onboarding.continue': 'Começar a focar',
	'onboarding.skip': 'Pular',
	'focus.title': 'Foco',
	'focus.honesty':
		'Mantenha esta aba aberta para tempo confiável. Abas em segundo plano podem ser limitadas.',
	'focus.start': 'Iniciar',
	'focus.pause': 'Pausar',
	'focus.resume': 'Retomar',
	'focus.skip': 'Pular',
	'focus.complete': 'Concluir',
	'focus.reset': 'Nova sessão',
	'focus.journal': 'Diário da sessão',
	'focus.linkTask': 'Vincular tarefa',
	'focus.noTask': 'Sem tarefa',
	'focus.mode.pomodoro': 'Pomodoro',
	'focus.mode.stopwatch': 'Cronômetro',
	'focus.mode.flowtime': 'Flowtime',
	'focus.mode.timeblock': 'Time Block',
	'focus.mode.locked': 'Everywhere',
	'focus.upgradeTeaser':
		'Flowtime e Time Block desbloqueiam com Everywhere (assine ou restaure no iOS, Android ou Windows). Ainda sem compra na web.',
	'focus.autoStart': 'Autoiniciar próximo segmento',
	'focus.suggest.title': 'Sugerido agora',
	'focus.suggest.apply': 'Aplicar',
	'focus.suggest.locked': 'Desbloqueie com Everywhere',
	'focus.suggest.morning': 'Energia matinal — sprints curtos funcionam bem.',
	'focus.suggest.deep': 'Janela de deep work — Flowtime ajuda no fluxo.',
	'focus.suggest.afternoon': 'Estrutura da tarde — Time Block protege a agenda.',
	'focus.suggest.evening': 'Encerramento — mais um Pomodoro e descanse.',
	'focus.suggest.flexible': 'Horário flexível — cronômetro sem pressão.',
	'focus.phase.idle': 'Pronto',
	'focus.phase.running': 'Em sessão',
	'focus.phase.paused': 'Pausado',
	'focus.phase.completed': 'Concluído',
	'plan.title': 'Plano',
	'plan.add': 'Adicionar tarefa',
	'plan.search': 'Buscar tarefas',
	'plan.newTask': 'Nova tarefa',
	'plan.search.empty': 'Nenhuma tarefa corresponde à sua busca',
	'dashboard.refresh': 'Atualizar',
	'plan.empty': 'Nenhuma tarefa ainda. No Free você pode ter até 3 ativas.',
	'plan.capBlocked': 'Free permite até 3 tarefas ativas.',
	'plan.upgradeTeaser':
		'Precisa de mais de 3 tarefas ativas, subtarefas ou recorrência? Everywhere desbloqueia após restaurar em um app de loja.',
	'plan.priority': 'Prioridade',
	'plan.energy': 'Energia',
	'plan.estPomos': 'Pomodoros est.',
	'plan.complete': 'Concluir',
	'plan.delete': 'Excluir',
	'plan.filter.all': 'Todas',
	'plan.filter.today': 'Hoje',
	'plan.filter.upcoming': 'Próximas',
	'plan.filter.inbox': 'Caixa de entrada',
	'plan.quickPlaceholder': 'No que focar?',
	'plan.activeCap': 'ativas',
	'plan.priority.low': 'Baixa',
	'plan.priority.medium': 'Média',
	'plan.priority.high': 'Alta',
	'plan.energy.low': 'Leve',
	'plan.energy.medium': 'Média',
	'plan.energy.high': 'Profunda',
	'plan.listLabel': 'Lista',
	'plan.showOptions': 'Mais',
	'plan.hideOptions': 'Menos',
	'plan.focusTask': 'Foco',
	'plan.reorder': 'Ordem',
	'dashboard.title': 'Painel',
	'dashboard.today': 'Hoje',
	'dashboard.last7': 'Últimos 7 dias',
	'dashboard.sessions': 'Sessões',
	'dashboard.minutes': 'Minutos de foco',
	'dashboard.extendedGated':
		'Visões de 30 dias e 1 ano desbloqueiam com Everywhere. Free mostra hoje + últimos 7 dias.',
	'dashboard.empty': 'Conclua uma sessão para ver o resumo aqui.',
	'dashboard.subtitle': 'Reflita sobre o que funcionou',
	'dashboard.heroCta': 'Começar a focar',
	'dashboard.recent': 'Sessões recentes',
	'dashboard.avgSession': 'Min méd. / sessão',
	'account.title': 'Conta',
	'account.tier': 'Plano',
	'account.tierFree': 'Free · apenas navegador local',
	'account.locale': 'Idioma',
	'account.theme': 'Tema',
	'account.theme.system': 'Sistema',
	'account.theme.light': 'Claro',
	'account.theme.dark': 'Escuro',
	'account.storageWarning':
		'Seus dados Free ficam só neste perfil do navegador. Limpar armazenamento ou trocar de navegador os perde. Sync multi-dispositivo não está no Free.',
	'account.everywhereTeaser':
		'Pepinillo Everywhere (sync + premium web) é restaurado via compra da loja e conta — Pepinillo+ não é vendido na web. Login chega em um slice posterior.',
	'account.about':
		'A web é um extra companheiro para foco em tela grande. Não substitui recursos nativos do SO.',
	'account.nonGoals':
		'Não na web: bandeja, atalhos globais, widgets, Live Activity, relógio, Health, CloudKit, colaboração em equipe, editor de notas.',
	'account.deviceId': 'Id do dispositivo (local)',
	'account.subtitle': 'Identidade, preferências e limites do companion',
	'account.premiumThemes': 'Forest / Ocean / Sunset desbloqueiam com Everywhere.',
	'account.settings': 'Preferências',
	'account.storage': 'Armazenamento local',
	'account.upgradeTitle': 'Everywhere',
	'account.pomodoro': 'Durações Pomodoro',
	'account.workMinutes': 'Trabalho (minutos)',
	'account.breakMinutes': 'Pausa (minutos)',
	'account.export': 'Exportar dados locais',
	'account.exportHint': 'Baixe tarefas, sessões e preferências como JSON deste navegador.',
	'toast.sessionComplete': 'Sessão salva. Bom trabalho.',
	'toast.sessionSkipped': 'Sessão pulada e salva.',
	'toast.exportDone': 'Exportação baixada.',
	'toast.signedIn': 'Sessão iniciada.',
	'toast.registered': 'Conta criada.',
	'toast.signedOut': 'Sessão encerrada.',
	'toast.syncOk': 'Dados locais enviados.',
	'toast.syncMerged': 'Dados combinados dos seus dispositivos.',
	'toast.syncPullDone': 'Atualizado da nuvem.',
	'account.signIn': 'Entrar',
	'account.signUp': 'Criar conta',
	'account.signOut': 'Sair',
	'account.email': 'Email',
	'account.password': 'Senha',
	'account.name': 'Nome',
	'account.syncNow': 'Enviar dados locais (Everywhere)',
	'account.syncing': 'Sincronizando…',
	'account.apiMissing':
		'API não configurada. Defina PUBLIC_API_BASE_URL em web/.env para conta + sync.',
	'account.everywhereActive': 'Everywhere ativo — sync na nuvem disponível.',
	'account.everywhereInactive':
		'Sessão Free. Assine ou restaure Everywhere no iOS, Android ou Windows e atualize.',
	'account.signedInAs': 'Conectado como',
	'account.refreshEntitlement': 'Atualizar assinatura',
	'sync.everywhereRequired': 'Everywhere é necessário para sync na nuvem.',
	'sync.mergeExisting':
		'O servidor já tinha dados. Local foi mesclado (LWW). Revise nos outros dispositivos.',
	'sync.ok': 'Envio concluído.',
	'sync.pullError': 'Não foi possível atualizar da nuvem. Tente novamente.',
	'sync.lastSync': 'Última sync',
	'sync.autoSyncOn': 'Auto-sync ativo — as mudanças sincronizam entre dispositivos.',
	'auth.required': 'Entre primeiro.',
	'account.appearance': 'Aparência',
	'account.theme.classic': 'Clássico',
	'account.theme.forest': 'Floresta',
	'account.theme.ocean': 'Oceano',
	'account.theme.sunset': 'Pôr do sol',
	'landing.openApp': 'Abrir o app',
	'landing.wipNote': 'A nova web está sendo construída com tudo dos apps nativos.',
	'common.wip.title': 'Chega no próximo lote',
	'common.wip.body': 'Esta superfície está sendo reconstruída com tudo dos apps nativos.',
	'common.proLocked': 'Recurso do Pepinillo+',
	'focus.phase.work': 'Foco',
	'focus.phase.shortBreak': 'Pausa curta',
	'focus.phase.longBreak': 'Pausa longa',
	'focus.waitingBreak': 'A pausa fica pronta quando você estiver pronto.',
	'focus.waitingWork': 'O próximo foco fica pronto quando você estiver pronto.',
	'focus.startBreak': 'Iniciar pausa',
	'focus.startWork': 'Iniciar foco',
	'focus.takeBreak': 'Fazer uma pausa',
	'focus.ghost.title': 'Sessão inacabada',
	'focus.ghost.body': 'Você deixou uma sessão de {mode} rodando ({time} registrados). Retome ou descarte.',
	'focus.ghost.resume': 'Retomar',
	'focus.ghost.discard': 'Descartar',
	'celebration.firstSession.title': 'Primeira sessão!',
	'celebration.firstSession.body': 'A parte mais difícil é começar. Você conseguiu!',
	'celebration.streak.title': 'Sequência de {days} dias!',
	'celebration.streak.body': 'Aparecer dia após dia é assim que a horta cresce.',
	'celebration.sessionCount.title': '{count} sessões!',
	'celebration.sessionCount.body': 'O impulso é real. Continue colhendo.',
	'celebration.personalBest.title': 'Recorde pessoal: {minutes}m',
	'celebration.personalBest.body': 'Seu maior período de foco até agora. Deep work combina com você.',
	'celebration.keepGoing': 'Continue assim!',
	'celebration.record.title': 'Novo recorde de sequência: {days} dias',
	'celebration.record.dismiss': 'Fechar aviso de recorde',
	'journal.title': 'Como foi?',
	'journal.subtitle': 'Uma nota rápida ajuda na sua revisão semanal.',
	'journal.rating.1': 'Puxado',
	'journal.rating.2': 'Meh',
	'journal.rating.3': 'Ok',
	'journal.rating.4': 'Bom',
	'journal.rating.5': 'Ótimo!',
	'journal.placeholder': 'No que você se concentrou? Algo para lembrar?',
	'journal.save': 'Salvar',
	'journal.skip': 'Pular',
	'taskPicker.title': 'Focar em uma tarefa',
	'taskPicker.empty': 'Ainda não há tarefas ativas — crie-as no Plano.',
	'taskPicker.unlink': 'Sem tarefa vinculada',
	'soundscape.title': 'Paisagens sonoras',
	'soundscape.none': 'Nenhuma',
	'soundscape.rain': 'Chuva',
	'soundscape.forest': 'Floresta',
	'soundscape.cafe': 'Café',
	'soundscape.whiteNoise': 'Ruído branco',
	'soundscape.ocean': 'Oceano',
	'soundscape.fireplace': 'Lareira',
	'soundscape.binaural': 'Binaural',
	'soundscape.lofi': 'Lo-fi',
	'soundscape.volume': 'Volume',
	'soundscape.hint': 'Áudio gerado por síntese no seu navegador, sem downloads.',
	'companion.focusToday': 'Foco hoje',
	'companion.sessionsToday': 'Sessões hoje',
	'companion.streak': 'Sequência',
	'companion.streakEmpty': 'Comece sua sequência',
	'companion.pomodoroNumber': 'Pomodoro n.º',
	'companion.activeTask': 'Tarefa ativa',
	'companion.suggest.title': 'Sugerido para agora',
	'companion.suggest.apply': 'Toque para aplicar',
	'adhd.breathe': 'Respire devagar',
	'adhd.stretch': 'Alongue-se um pouco',
	'adhd.hydrate': 'Beba água',
	'adhd.move': 'Movimente-se',
	'adhd.subtitle': 'Pausa guiada',
	'settings.focus.title': 'Foco',
	'settings.pomodoro.work': 'Trabalho (min)',
	'settings.pomodoro.break': 'Pausa curta (min)',
	'settings.pomodoro.longBreak': 'Pausa longa (min)',
	'settings.pomodoro.sessions': 'Sessões antes da pausa longa',
	'settings.autoStartBreaks': 'Iniciar pausas automaticamente',
	'settings.autoStartWork': 'Iniciar o próximo foco automaticamente',
	'settings.flowtime.min': 'Flowtime: sugerir pausa após (min)',
	'settings.timeblock.minutes': 'Bloco de tempo (min)',
	'settings.timeblock.midpoint': 'Check-in na metade',
	'settings.sound.title': 'Som',
	'settings.sound.enabled': 'Som de conclusão',
	'settings.behavior.title': 'Comportamento',
	'sound.classic': 'Clássico',
	'sound.chime': 'Sinos',
	'sound.bell': 'Campainha',
	'sound.digital': 'Digital',
	'sound.woodblock': 'Madeira',
	'settings.haptics': 'Vibração (se suportada)',
	'settings.keepScreenOn': 'Manter a tela ligada ao focar',
	'settings.journal': 'Diário após cada sessão',
	'settings.adhd': 'Pausas guiadas (modo TDAH)',
	'settings.notifications': 'Notificações de fase',
	'settings.notifications.hint': 'Notificações do navegador entre fases. A permissão será solicitada.',
	'plan.filter.completed': 'Concluídas',
	'plan.priority.none': 'Sem prioridade',
	'plan.energy.deep': 'Profunda',
	'plan.energy.shallow': 'Leve',
	'plan.energy.admin': 'Admin',
	'plan.energySuggest': 'Sugerir para agora',
	'plan.energyHint': 'Energia sugerida agora: {energy}',
	'plan.due.today': 'Hoje',
	'plan.due.overdue': 'Atrasada',
	'plan.dueDate': 'Data limite',
	'plan.focusToday': 'Foco hoje',
	'plan.recurrence': 'Repetir',
	'plan.recurrence.daily': 'Diária',
	'plan.recurrence.weekdays': 'Dias de semana',
	'plan.recurrence.weekly': 'Semanal',
	'plan.recurrence.biweekly': 'A cada 2 semanas',
	'plan.recurrence.monthly': 'Mensal',
	'plan.notes': 'Notas',
	'plan.notesPlaceholder': 'Notas, links, contexto…',
	'plan.subtasks': 'Subtarefas',
	'plan.subtaskAdd': 'Adicione uma subtarefa e aperte Enter',
	'plan.subtaskDelete': 'Excluir subtarefa',
	'plan.subtasksGate': 'Subtarefas são um recurso do Pepinillo+.',
	'plan.analytics': 'Histórico de foco',
	'plan.analytics.sessions': '{count} sessões',
	'plan.analytics.focus': '{time} de foco',
	'plan.deleteConfirm': 'Toque de novo para excluir',
	'plan.inspector': 'Detalhes da tarefa',
	'plan.empty.today': 'Nada para hoje',
	'plan.empty.inbox': 'Caixa zerada',
	'plan.empty.all': 'Nada por aqui ainda',
	'plan.empty.upcoming': 'Nada agendado',
	'plan.empty.completed': 'Ainda sem colheita',
	'plan.empty.body': 'Adicione sua primeira tarefa acima — sua horta começa aqui.',
	'quickCapture.title': 'Captura rápida',
	'quickCapture.placeholder': 'Capturar uma tarefa…',
	'quickCapture.hint': '⌘K / Ctrl+K de qualquer lugar',
	'quickCapture.captured': '{title} capturada na Inbox',
	'palette.placeholder': 'Busque comandos ou capture uma tarefa…',
	'palette.addTask': 'Adicionar tarefa',
	'palette.empty': 'Nenhum comando correspondente',
	'palette.focus': 'Focus',
	'palette.plan': 'Plan',
	'palette.dashboard': 'Dashboard',
	'palette.startFocus': 'Iniciar sessão de foco',
	'palette.toggleTheme': 'Alternar claro / escuro',
	'toast.undo': 'Desfazer',
	'period.7': '7D',
	'period.30': '30D',
	'period.365': '1A',
	'chart.week': 'Esta semana',
	'chart.window': 'Últimos {days} dias',
	'chart.modes': 'Modos',
	'chart.day.sun': 'Dom',
	'chart.day.mon': 'Seg',
	'chart.day.tue': 'Ter',
	'chart.day.wed': 'Qua',
	'chart.day.thu': 'Qui',
	'chart.day.fri': 'Sex',
	'chart.day.sat': 'Sáb',
	'dash.best': 'Recorde: {days}',
	'dash.focusScore': 'Pontuação de foco',
	'dash.peakHour': 'Hora de pico',
	'dash.completion': 'Conclusão',
	'dash.longest': 'Sessão mais longa',
	'dash.periodFocus': 'Foco do período',
	'score.exceptional': 'Semana excepcional',
	'score.strong': 'Ritmo forte',
	'score.steady': 'Constante',
	'score.warming': 'Aquecendo',
	'score.rest': 'Semana de descanso',
	'achievements.title': 'Conquistas',
	'achievements.firstFocus.title': 'Primeiro Foco',
	'achievements.weekWarrior.title': 'Guerreiro Semanal',
	'achievements.pomodoroMaster.title': 'Mestre Pomodoro',
	'achievements.deepDiver.title': 'Mergulhador Profundo',
	'achievements.centuryClub.title': 'Clube dos Cem',
	'achievements.earlyBird.title': 'Madrugador',
	'sessions.recent': 'Sessões recentes',
	'sessions.empty': 'Complete sua primeira sessão para vê-la aqui.',
	'review.weekly': 'Revisão semanal',
	'review.monthly': 'Revisão mensual',
	'review.dataTab': 'Dados',
	'review.aiTab': 'Insights IA',
	'review.aiSoon': 'Insights de IA chegam com Everywhere+ (em breve na web).',
	'review.focus': 'Foco',
	'review.sessions': 'Sessões',
	'review.trendUp': 'Você subiu {pct}% vs o período anterior',
	'review.trendDown': 'Você caiu {pct}% vs o período anterior',
	'review.trendFlat': 'Igual ao período anterior',
	'review.topTasks': 'Tarefas top',
	'review.modes': 'Modos',
	'review.bestDay': 'Melhor dia:',
	'auth.title': 'Conta',
	'auth.subtitle': 'Entre para sincronizar sua horta entre dispositivos.',
	'auth.signIn': 'Entrar',
	'auth.signUp': 'Criar conta',
	'auth.nameField': 'Nome',
	'auth.emailField': 'Email',
	'auth.passwordField': 'Senha (8+ caracteres)',
	'auth.working': 'Um momento…',
	'auth.needAccount': 'Não tem conta?',
	'auth.haveAccount': 'Já tenho conta',
	'auth.forgot.link': 'Esqueceu a senha?',
	'auth.forgot.submit': 'Enviar link de recuperação',
	'auth.forgot.sent': 'Se o email existir, o link está a caminho.',
	'auth.error.generic': 'Algo deu errado. Tente de novo.',
	'auth.error.invalidCredentials': 'Email ou senha incorretos.',
	'auth.error.invalidEmail': 'Esse email não parece válido.',
	'auth.error.emailTaken': 'Esse email já tem uma conta.',
	'auth.error.weakPassword': 'Use pelo menos 8 caracteres.',
	'auth.error.apiMissing': 'O API de sync não está configurado neste build.',
	'auth.syncHint': 'A sync requer Everywhere/AI+. Seus dados sempre vivem primeiro neste dispositivo.',
	'auth.verifyPending': 'Verifique seu email na caixa de entrada — a sync ativa depois disso.',
	'auth.apiMissing': 'A sync cloud não está configurada neste build (PUBLIC_API_BASE_URL vazio). Tudo funciona offline.',
	'auth.dangerTitle': 'Sessão',
	'auth.deleteConfirm': 'Isso remove sua conta na nuvem. Seu email, para confirmar:',
	'auth.deleteAccount': 'Excluir conta',
	'upgrade.title': 'Preços',
	'upgrade.meta': 'Preços do Pepinillo: free para sempre, Pepinillo+ compra única, Everywhere/AI+ assinatura com sync cloud e IA.',
	'upgrade.headline': 'Cultive seu foco, do seu jeito',
	'upgrade.sub': 'Comece grátis para sempre. Pepinillo+ é uma compra, sua para sempre — não é assinatura. Everywhere/AI+ adiciona sync cloud e IA em todas as suas telas.',
	'upgrade.signedIn': 'Conectado como {email}',
	'upgrade.signInFirst': 'Entre primeiro para comprar na web',
	'upgrade.plan.free': 'Free',
	'upgrade.plan.plus': 'Pepinillo+',
	'upgrade.plan.everywhere': 'Everywhere/AI+',
	'upgrade.price.free': '$0',
	'upgrade.price.plus': '$19.99 uma vez',
	'upgrade.price.everywhere': '$4.99/mês · $34.99/ano',
	'upgrade.note.free': 'Tudo para começar o hábito',
	'upgrade.note.plus': 'Uma compra. Sua para sempre. Não é assinatura.',
	'upgrade.note.everywhere': 'Tudo do Pepinillo+, em todas as suas telas.',
	'upgrade.flag.best': 'O mais completo',
	'upgrade.free.pomodoro': 'Pomodoro + Cronômetro',
	'upgrade.free.stopwatch': '3 tarefas ativas',
	'upgrade.free.tasks': 'Métricas: hoje + 7 dias',
	'upgrade.free.analytics': 'Offline completo, sem conta',
	'upgrade.plus.modes': 'Flowtime + Blocos de tempo',
	'upgrade.plus.tasks': 'Tarefas ilimitadas',
	'upgrade.plus.subtasks': 'Subtarefas + recorrência',
	'upgrade.plus.themes': 'Temas Floresta, Oceano e Pôr do sol',
	'upgrade.plus.analytics': 'Métricas completas (30 dias + 1 ano)',
	'upgrade.plus.soundscapes': 'Todas as paisagens sonoras',
	'upgrade.everywhere.plusIncluded': 'Tudo do Pepinillo+',
	'upgrade.everywhere.sync': 'Sync cloud entre dispositivos (LWW, como nos apps nativos)',
	'upgrade.everywhere.ai': 'Insights de IA: revisões, dicas e previsões',
	'upgrade.everywhere.recovery': 'Recuperação de conta — seus dados a salvo mesmo se perder um dispositivo',
	'upgrade.everywhere.web': 'Acesso completo a este app web',
	'upgrade.cta.free': 'Abrir o app',
	'upgrade.cta.plus': 'Comprar uma vez',
	'upgrade.cta.everywhere': 'Assinar',
	'upgrade.working': 'Abrindo…',
	'upgrade.checkoutError': 'Não conseguimos abrir o checkout. Tente em instantes.',
	'upgrade.portalError': 'Não conseguimos abrir o portal de pagos. Você tem uma assinatura web?',
	'upgrade.storesTitle': 'Prefere os apps nativos?',
	'upgrade.storesBody': 'O Pepinillo vive nativo no iPhone, iPad, Mac, Android e Wear OS — com widgets, complicações de relógio e Live Activities.',
	'upgrade.storeApp': 'App Store',
	'upgrade.storePlay': 'Google Play',
	'upgrade.manageTitle': 'Gerencie sua assinatura web',
	'upgrade.manageBody': 'Mude de plano, atualize o meio de pagamento ou cancele — direto no portal do Stripe.',
	'upgrade.manageCta': 'Abrir portal de pagos',
	'legal.privacy': 'Privacidade',
	'legal.terms': 'Termos',
	'auth.deleteFailed': 'Não conseguimos excluir a conta agora. Tente de novo ou contate o suporte.',
	'ai.cardTitle': 'Insights de IA',
	'ai.gated': 'Insights de IA são um recurso do Everywhere/AI+.',
	'ai.upgradeCta': 'Fazer upgrade',
	'ai.loading': 'Pensando…',
	'ai.error': 'A IA não está disponível agora. Tente mais tarde.',
	'ai.empty': 'Sem insights de IA para este período — complete algumas sessões primeiro.',
	'ai.highlights': 'Destaques',
	'ai.insights': 'Insights',
	'ai.optimalHours': 'Horas ideais',
	'ai.burnout': 'Risco de burnout',
	'settings.dailyReminder': 'Lembrete diário',
	'settings.reminderHour': 'Hora',
	'settings.reminderMinute': 'Minuto',
	'settings.reminderNext': 'próximo em {time}',
	'settings.weeklyRecap': 'Notificação de revisão semanal',
	'settings.streak.title': 'Sequência',
	'settings.celebrateRecords': 'Celebrar novos recordes',
	'settings.privacy.title': 'Privacidade',
	'settings.analytics': 'Compartilhar métricas anônimas de uso',
	'settings.analytics.hint': 'Estatísticas agregadas sem dados pessoais. Desligado por padrão; nada é enviado sem consentimento.',
	'settings.startup.title': 'Inicialização',
	'settings.startup.hint': 'A seção onde o app abre (paridade com o Mac).',
	'landing.nav.guides': 'Guias',
	'landing.nav.macmanual': 'Manual do macOS',
	'landing.nav.pricing': 'Preços',
	'landing.guides.title': 'Aprenda a usar cada canto',
	'landing.guides.sub': 'O manual de usuário completo do macOS, com capturas de tela reais do app: da sua primeira sessão a cada atalho de teclado.',
	'landing.guides.cta': 'Ler o manual do macOS',
	'landing.nav.open': 'Abrir app',
	'landing.nav.home': 'Início',
	'landing.meta': 'Pepinillo é um companheiro nativo de deep work: planeje com intenção, concentre-se sem ruído e celebre o que você cultiva. iPhone, iPad, Mac, Android, Wear OS e web.',
	'landing.kicker': 'Deep work, nativo',
	'landing.hero.title': 'Planeje com intenção. Concentre-se sem ruído. Celebre o que você cultiva.',
	'landing.hero.sub': 'Pepinillo é um companheiro nativo de deep work em todas as suas telas — um timer que respeita seu cérebro, tarefas organizadas por energia e estatísticas que ajudam você a entender seus padrões.',
	'landing.hero.hint': 'O app web funciona offline e se instala como um app nativo.',
	'landing.cta.web': 'Abrir o app web',
	'landing.cta.stores': 'Baixar os apps nativos',
	'landing.flow.label': 'O fluxo Pepinillo',
	'landing.flow.plan': 'Planeje',
	'landing.flow.focus': 'Concentre-se',
	'landing.flow.complete': 'Complete',
	'landing.flow.reflect': 'Reflita',
	'landing.feat.modes.title': 'Quatro formas de se concentrar',
	'landing.feat.modes.body': 'Pomodoro para o ritmo, Flowtime para imersão profunda, Blocos para sessões planejadas, Cronômetro para trabalho aberto. Seu motor roda com honestidade em cada dispositivo.',
	'landing.feat.tasks.title': 'Tarefas que respeitam sua energia',
	'landing.feat.tasks.body': 'Organize por prioridade e energia mental — profunda, leve, admin — com subtarefas, recorrência e uma sugestão diária baseada na sua cronobiologia.',
	'landing.feat.stats.title': 'Sequências que valem celebração',
	'landing.feat.stats.body': 'Revisões semanais e mensuais, pontuação de foco, recordes pessoais e marcos que disparam exatamente quando você os ganha. Sua horta cresce a cada sessão.',
	'landing.feat.sync.title': 'Onde você trabalha',
	'landing.feat.sync.body': 'Everywhere/AI+ sincroniza seus dados entre dispositivos como os apps nativos, e adiciona insights de IA: revisões, dicas e previsões.',
	'landing.download.title': 'Nativo em cada tela',
	'landing.download.body': 'Widgets, complicações de relógio, Live Activities, barra de menu — o Pepinillo se sente em casa em cada plataforma. Este app web é o novo membro da família.',
	'landing.download.ios': 'iPhone e iPad',
	'landing.download.android': 'Android',
	'landing.download.web': 'Usar o app web',
	'landing.pricing.title': 'Preços simples e honestos',
	'landing.pricing.cta': 'Ver preços completos',
	'landing.faq.title': 'Perguntas frequentes',
	'landing.faq.offline.q': 'Funciona offline?',
	'landing.faq.offline.a': 'Sim — tudo roda primeiro no seu dispositivo. O app web guarda seus dados localmente e funciona sem conexão; a sync cloud é um extra do Everywhere/AI+.',
	'landing.faq.devices.q': 'Quais dispositivos são suportados?',
	'landing.faq.devices.a': 'iPhone, iPad, Mac, Android, Wear OS e este app web. Seu motor, tarefas e estatísticas se comportam igual em todos.',
	'landing.faq.price.q': 'A versão web é grátis?',
	'landing.faq.price.a': 'Sim. O app web é grátis com os mesmos limites do mobile free: Pomodoro + Cronômetro, 3 tarefas ativas e 7 dias de métricas. Pepinillo+ e Everywhere/AI+ desbloqueiam o resto.',
	'landing.faq.account.q': 'Preciso de uma conta?',
	'landing.faq.account.a': 'Não. Você pode usar tudo offline sem cadastro. A conta só é necessária para sync cloud e IA (Everywhere/AI+).',
	'guides.title': 'Guias do usuário',
	'guides.meta': 'Guias passo a passo do Pepinillo no Mac, iPhone, iPad, watchOS, Android, Wear OS e web.',
	'guides.intro': 'Aprenda cada canto do Pepinillo, plataforma por plataforma.',
	'guides.soon': 'Em breve',
	'guides.list.macos': 'Mac — manual e guia touch',
	'guides.list.macos.body': 'Barra de menu, painel Notch, Quick Capture, atalhos de teclado e os novos gestos touch.',
	'guides.list.iphone': 'iPhone e iPad',
	'guides.list.watchos': 'watchOS',
	'guides.list.android': 'Android',
	'guides.list.wearos': 'Wear OS',
	'guides.list.web': 'App web',
	'guides.list.generic.body': 'O guia completo desta plataforma está a caminho.',
	'sync.title': 'Sync cloud',
	'sync.hint': 'Last-Write-Wins com o relógio do servidor, como nos apps nativos.',
	'sync.last': 'Última sync',
	'sync.live': 'Atualizações ao vivo conectadas',
	'sync.offline': 'Atualizações ao vivo desligadas',
	'sync.mergeTitle': 'Encontramos dados na nuvem',
	'sync.mergeBody': 'Esta conta já tem dados na nuvem. Fica com a versão da nuvem ou sobrescreve a nuvem com o que há neste dispositivo?',
	'sync.mergePull': 'Usar os dados da nuvem',
	'sync.mergeUpload': 'Enviar deste dispositivo'
};

const catalogs: Record<LocaleCode, Dict> = { en, es, pt };

export function t(locale: LocaleCode, key: MessageKey): string {
	return catalogs[locale][key] ?? catalogs.en[key] ?? key;
}

export function detectLocale(navLang?: string): LocaleCode {
	const raw = (navLang ?? (typeof navigator !== 'undefined' ? navigator.language : 'en')).toLowerCase();
	if (raw.startsWith('es')) return 'es';
	if (raw.startsWith('pt')) return 'pt';
	return 'en';
}

export const LOCALES: LocaleCode[] = ['en', 'es', 'pt'];
