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
	| 'account.deviceId';

type Dict = Record<MessageKey, string>;

const en: Dict = {
	'app.name': 'Pepinillo',
	'app.tagline': 'Web companion · large screen focus',
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
	'auth.required': 'Sign in first.',
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
	'app.tagline': 'Compañero web · foco en pantalla grande',
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
	'auth.required': 'Iniciá sesión primero.'
};

const pt: Dict = {
	...en,
	'app.tagline': 'Companheiro web · foco em tela grande',
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
	'auth.required': 'Entre primeiro.'
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
