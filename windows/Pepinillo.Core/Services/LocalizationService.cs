using System;
using System.Collections.Generic;
using System.Linq;

namespace Pepinillo.Core.Services;

/// <summary>
/// In-memory EN / ES / PT catalog for primary Windows surfaces.
/// Professional neutral Spanish/Portuguese (not regional slang).
/// .resw can wrap the same keys later without changing call sites.
/// </summary>
public class LocalizationService : ILocalizationService
{
    /// <summary>Tuple order: Key, English, Spanish (neutral), Portuguese (neutral).</summary>
    private static readonly (string Key, string En, string Es, string Pt)[] Entries =
    {
        // ── Common ──────────────────────────────────────────────────────────
        ("Common.Cancel", "Cancel", "Cancelar", "Cancelar"),
        ("Common.Save", "Save", "Guardar", "Salvar"),
        ("Common.Upgrade", "Upgrade", "Mejorar plan", "Fazer upgrade"),
        ("Common.Loading", "Loading…", "Cargando…", "Carregando…"),
        ("Common.ErrorPrefix", "Error", "Error", "Erro"),
        ("Common.Never", "Never", "Nunca", "Nunca"),

        // ── Nav shell ───────────────────────────────────────────────────────
        ("Nav.Focus", "Focus", "Enfoque", "Foco"),
        ("Nav.Tasks", "Tasks", "Tareas", "Tarefas"),
        ("Nav.Calendar", "Calendar", "Calendario", "Calendário"),
        ("Nav.Analytics", "Analytics", "Analítica", "Análises"),
        ("Nav.Soundscapes", "Soundscapes", "Paisajes sonoros", "Paisagens sonoras"),
        ("Nav.Account", "Account", "Cuenta", "Conta"),
        ("Nav.Upgrade", "Upgrade", "Mejorar plan", "Upgrade"),
        ("Nav.Settings", "Settings", "Configuración", "Configurações"),
        ("Nav.Welcome", "Welcome", "Bienvenida", "Boas-vindas"),

        // ── Calendar / day planner (W13) ────────────────────────────────────
        ("Calendar.Title", "Plan day", "Planificar el día", "Planejar o dia"),
        ("Calendar.Subtitle", "Block deep-work hours on the desktop calendar. Start opens Focus in Time Blocking.", "Bloquea horas de trabajo profundo en el calendario de escritorio. Empezar abre Enfoque en Bloque de tiempo.", "Bloqueie horas de trabalho profundo no calendário de desktop. Iniciar abre o Foco em Bloco de tempo."),
        ("Calendar.Empty", "No time blocks for this day. Add one from the hour list.", "No hay bloques de tiempo para este día. Añade uno desde la lista de horas.", "Não há blocos de tempo para este dia. Adicione um na lista de horas."),
        ("Calendar.PrevDay", "Previous day", "Día anterior", "Dia anterior"),
        ("Calendar.NextDay", "Next day", "Día siguiente", "Próximo dia"),
        ("Calendar.Today", "Today", "Hoy", "Hoje"),
        ("Calendar.BlocksHeading", "Planned blocks", "Bloques planificados", "Blocos planejados"),
        ("Calendar.HoursHeading", "Hours", "Horas", "Horas"),
        ("Calendar.Start", "Start", "Empezar", "Iniciar"),
        ("Calendar.Delete", "Delete", "Eliminar", "Excluir"),
        ("Calendar.LinkTask", "Link task (optional)", "Vincular tarea (opcional)", "Vincular tarefa (opcional)"),
        ("Calendar.AddAtHour", "Add", "Añadir", "Adicionar"),
        ("Calendar.DefaultTitle", "Time Block", "Bloque de tiempo", "Bloco de tempo"),
        ("Calendar.DurationMinutes", "{0} min", "{0} min", "{0} min"),
        ("Calendar.PremiumRequired", "Time Blocking requires Pepinillo+ or Everywhere.", "El bloque de tiempo requiere Pepinillo+ o Everywhere.", "O bloco de tempo requer Pepinillo+ ou Everywhere."),
        ("Calendar.SessionBusy", "Finish or stop the current focus session before starting a block.", "Termina o detén la sesión de enfoque actual antes de empezar un bloque.", "Finalize ou pare a sessão de foco atual antes de iniciar um bloco."),

        // ── Settings ────────────────────────────────────────────────────────
        ("Settings.Title", "Settings", "Configuración", "Configurações"),
        ("Settings.TimerDurations", "Timer durations", "Duraciones del temporizador", "Durações do temporizador"),
        ("Settings.PomodoroFocus", "Pomodoro focus (minutes)", "Enfoque Pomodoro (minutos)", "Foco Pomodoro (minutos)"),
        ("Settings.ShortBreak", "Short break (minutes)", "Descanso corto (minutos)", "Pausa curta (minutos)"),
        ("Settings.LongBreak", "Long break (minutes)", "Descanso largo (minutos)", "Pausa longa (minutos)"),
        ("Settings.LongBreakInterval", "Long break every N pomodoros", "Descanso largo cada N pomodoros", "Pausa longa a cada N pomodoros"),
        ("Settings.FlowtimeTarget", "Flowtime target (minutes)", "Objetivo Flowtime (minutos)", "Meta Flowtime (minutos)"),
        ("Settings.TimeBlock", "Time block (minutes)", "Bloque de tiempo (minutos)", "Bloco de tempo (minutos)"),
        ("Settings.AutoStartBreaks", "Auto-start breaks", "Iniciar descansos automáticamente", "Iniciar pausas automaticamente"),
        ("Settings.AutoStartFocus", "Auto-start next focus after break", "Iniciar siguiente enfoque tras el descanso", "Iniciar próximo foco após a pausa"),
        ("Settings.Appearance", "Appearance", "Apariencia", "Aparência"),
        ("Settings.Theme", "Theme", "Tema", "Tema"),
        ("Settings.Save", "Save settings", "Guardar configuración", "Salvar configurações"),
        ("Settings.Saved", "Settings saved", "Configuración guardada", "Configurações salvas"),
        ("Settings.Language", "Language", "Idioma", "Idioma"),
        ("Settings.LanguageAppliesNote", "Language applies to screens when reopened.", "El idioma se aplica al reabrir las pantallas.", "O idioma é aplicado ao reabrir as telas."),
        ("Settings.Privacy", "Privacy policy", "Política de privacidad", "Política de privacidade"),
        ("Settings.Terms", "Terms of use", "Términos de uso", "Termos de uso"),
        ("Settings.Upgrade", "Upgrade", "Mejorar plan", "Fazer upgrade"),
        ("Settings.UpgradePlus", "Upgrade to Pepinillo+", "Mejorar a Pepinillo+", "Fazer upgrade para Pepinillo+"),
        ("Settings.Mica", "Mica / acrylic backdrop (when supported)", "Fondo Mica / acrílico (si es compatible)", "Fundo Mica / acrílico (quando suportado)"),
        ("Settings.SoundscapesSection", "Soundscapes", "Paisajes sonoros", "Paisagens sonoras"),
        ("Settings.EnableSoundscapes", "Enable soundscapes", "Activar paisajes sonoros", "Ativar paisagens sonoras"),
        ("Settings.AutoPlaySoundscape", "Auto-play preferred soundscape when focus starts", "Reproducir paisaje preferido al iniciar el enfoque", "Reproduzir paisagem preferida ao iniciar o foco"),
        ("Settings.SoundscapesHint", "Master volume and track selection live on the Soundscapes page. Preferred track updates when you press Play.", "El volumen y la selección de pistas están en la página de Paisajes sonoros. La pista preferida se actualiza al pulsar Reproducir.", "O volume e a seleção de faixas ficam na página de Paisagens sonoras. A faixa preferida é atualizada ao pressionar Reproduzir."),
        ("Settings.WindowsIntegration", "Windows integration", "Integración con Windows", "Integração com o Windows"),
        ("Settings.FocusAssist", "Sync with Focus Assist / Do Not Disturb", "Sincronizar con Asistente de concentración / No molestar", "Sincronizar com Assistente de foco / Não perturbe"),
        ("Settings.OpenFocusAssist", "Open Focus Assist settings", "Abrir configuración de Asistente de concentración", "Abrir configurações do Assistente de foco"),
        ("Settings.MinimizeToTray", "Minimize to system tray on close", "Minimizar a la bandeja del sistema al cerrar", "Minimizar para a bandeja do sistema ao fechar"),
        ("Settings.Toasts", "Toast notifications", "Notificaciones toast", "Notificações toast"),
        ("Settings.Startup", "Launch Pepinillo when Windows starts", "Iniciar Pepinillo al arrancar Windows", "Iniciar o Pepinillo com o Windows"),
        ("Settings.Hotkeys", "Global hotkeys", "Atajos globales", "Atalhos globais"),
        ("Settings.HotkeyHint", "If a hotkey does nothing, another app may own the chord (e.g. PowerToys).", "Si un atajo no responde, otra app puede usarlo (p. ej. PowerToys).", "Se um atalho não funcionar, outro app pode estar usando-o (ex.: PowerToys)."),
        ("Settings.KeyboardAcceleratorsCaption", "Focus: Ctrl+Enter start/resume · Ctrl+Space pause when available. Tasks: Ctrl+N focus add field.", "Enfoque: Ctrl+Enter iniciar/reanudar · Ctrl+Espacio pausar si está disponible. Tareas: Ctrl+N enfocar campo de alta.", "Foco: Ctrl+Enter iniciar/retomar · Ctrl+Espaço pausar quando disponível. Tarefas: Ctrl+N focar campo de nova tarefa."),
        ("Settings.PlayPauseHotkey", "Play / Pause", "Reproducir / Pausar", "Reproduzir / Pausar"),
        ("Settings.SkipHotkey", "Skip break", "Saltar descanso", "Pular pausa"),
        ("Settings.MiniTimerHotkey", "Mini timer", "Mini temporizador", "Mini temporizador"),
        ("Settings.ResetHotkeys", "Reset hotkeys to defaults", "Restablecer atajos predeterminados", "Redefinir atalhos padrão"),
        ("Settings.HotkeysReset", "Hotkeys reset to defaults (save to apply).", "Atajos restablecidos (guarde para aplicar).", "Atalhos redefinidos (salve para aplicar)."),
        ("Settings.Help", "Help", "Ayuda", "Ajuda"),
        ("Settings.OnboardingReplay", "Replay the first-run welcome guide (modes, tray, hotkeys, mini timer).", "Volver a ver la guía de bienvenida (modos, bandeja, atajos, mini temporizador).", "Rever o guia de boas-vindas (modos, bandeja, atalhos, mini temporizador)."),
        ("Settings.OnboardingReplayButton", "Show welcome guide", "Mostrar guía de bienvenida", "Mostrar guia de boas-vindas"),
        ("Settings.OpeningOnboarding", "Opening welcome guide…", "Abriendo guía de bienvenida…", "Abrindo guia de boas-vindas…"),
        ("Settings.Legal", "Legal", "Legal", "Legal"),
        ("Settings.PremiumThemesUpgrade", "Upgrade to Pepinillo+ for premium themes.", "Mejora a Pepinillo+ para temas premium.", "Faça upgrade para Pepinillo+ e use temas premium."),
        ("Settings.FocusAssistUnavailable", "Focus Assist: status unavailable", "Asistente de concentración: estado no disponible", "Assistente de foco: status indisponível"),
        ("Settings.SaveFailed", "Save failed: {0}", "Error al guardar: {0}", "Falha ao salvar: {0}"),
        ("Settings.HotkeyInvalidPlay", "Play/Pause hotkey is invalid. Use e.g. Win+Shift+P.", "El atajo Reproducir/Pausar no es válido. Use p. ej. Win+Shift+P.", "O atalho Reproduzir/Pausar é inválido. Use ex.: Win+Shift+P."),
        ("Settings.HotkeyInvalidSkip", "Skip hotkey is invalid. Use e.g. Win+Shift+S.", "El atajo Saltar no es válido. Use p. ej. Win+Shift+S.", "O atalho Pular é inválido. Use ex.: Win+Shift+S."),
        ("Settings.HotkeyInvalidMini", "Mini timer hotkey is invalid. Use e.g. Win+Shift+M.", "El atajo Mini temporizador no es válido. Use p. ej. Win+Shift+M.", "O atalho Mini temporizador é inválido. Use ex.: Win+Shift+M."),
        ("Settings.HotkeysMustBeUnique", "Hotkeys must be unique across Play/Pause, Skip, and Mini timer.", "Los atajos deben ser únicos entre Reproducir/Pausar, Saltar y Mini temporizador.", "Os atalhos devem ser únicos entre Reproduzir/Pausar, Pular e Mini temporizador."),

        // ── Focus ───────────────────────────────────────────────────────────
        ("Focus.Title", "Focus Engine", "Motor de enfoque", "Motor de foco"),
        ("Focus.Ready", "Ready", "Listo", "Pronto"),
        ("Focus.Focusing", "Focusing", "Enfocando", "Focando"),
        ("Focus.Paused", "Paused", "Pausado", "Pausado"),
        ("Focus.OnBreak", "On break", "En descanso", "Em pausa"),
        ("Focus.Completed", "Completed", "Completado", "Concluído"),
        ("Focus.Start", "Start / Resume", "Iniciar / Reanudar", "Iniciar / Retomar"),
        ("Focus.Pause", "Pause", "Pausar", "Pausar"),
        ("Focus.Stop", "Stop", "Detener", "Parar"),
        ("Focus.SkipBreak", "Skip break", "Saltar descanso", "Pular pausa"),
        ("Focus.LinkTask", "Link a task (optional)", "Vincular tarea (opcional)", "Vincular tarefa (opcional)"),
        ("Focus.FreeFocus", "Free focus (no task linked)", "Enfoque libre (sin tarea)", "Foco livre (sem tarefa)"),
        ("Focus.JournalTitle", "Session reflection", "Reflexión de sesión", "Reflexão da sessão"),
        ("Focus.JournalSave", "Save journal", "Guardar diario", "Salvar diário"),
        ("Focus.JournalDismiss", "Dismiss", "Descartar", "Dispensar"),
        ("Focus.ModePomodoro", "Pomodoro", "Pomodoro", "Pomodoro"),
        ("Focus.ModeStopwatch", "Stopwatch", "Cronómetro", "Cronômetro"),
        ("Focus.ModeFlowtime", "Flowtime", "Flowtime", "Flowtime"),
        ("Focus.ModeTimeBlocking", "Time Blocking", "Bloqueo de tiempo", "Bloco de tempo"),
        ("Focus.ModeRequiresUpgrade", "{0} requires Pepinillo+ or Everywhere.", "{0} requiere Pepinillo+ o Everywhere.", "{0} requer Pepinillo+ ou Everywhere."),
        ("Focus.ModeIntelligence", "Mode Intelligence", "Inteligencia de modo", "Inteligência de modo"),
        ("Focus.ModeIntelligenceUpgrade", "Upgrade for Mode Intelligence", "Mejora el plan para Inteligencia de modo", "Faça upgrade para Inteligência de modo"),
        ("Focus.SoundscapeChip", "Soundscape: {0}", "Paisaje sonoro: {0}", "Paisagem sonora: {0}"),
        ("Focus.SessionSaved", "Saved {0} min {1} session", "Sesión {1} de {0} min guardada", "Sessão {1} de {0} min salva"),
        ("Focus.SessionSaveFailed", "Session finished (save failed)", "Sesión finalizada (error al guardar)", "Sessão finalizada (falha ao salvar)"),
        ("Focus.MiniTimer", "Mini timer", "Mini temporizador", "Mini temporizador"),

        // ── Tasks ───────────────────────────────────────────────────────────
        ("Tasks.Title", "Tasks", "Tareas", "Tarefas"),
        ("Tasks.Subtitle", "Plan work into focus-sized tasks. Data is stored offline on this device.", "Planifica el trabajo en tareas del tamaño de un enfoque. Los datos se guardan sin conexión en este dispositivo.", "Planeje o trabalho em tarefas do tamanho de um foco. Os dados ficam offline neste dispositivo."),
        ("Tasks.FilterToday", "Today", "Hoy", "Hoje"),
        ("Tasks.FilterUpcoming", "Upcoming", "Próximas", "Próximas"),
        ("Tasks.FilterInbox", "Inbox", "Bandeja", "Caixa de entrada"),
        ("Tasks.FilterAll", "All", "Todas", "Todas"),
        ("Tasks.EmptyDefault", "Nothing scheduled here. Capture a focus-sized task and start a Pomodoro.", "Nada programado aquí. Captura una tarea del tamaño de un enfoque y empieza un Pomodoro.", "Nada agendado aqui. Capture uma tarefa do tamanho de um foco e inicie um Pomodoro."),
        ("Tasks.EmptyToday", "Nothing due today. Add a focus-sized task and start a Pomodoro.", "Nada para hoy. Añade una tarea del tamaño de un enfoque y empieza un Pomodoro.", "Nada para hoje. Adicione uma tarefa do tamanho de um foco e inicie um Pomodoro."),
        ("Tasks.EmptyUpcoming", "No upcoming tasks. Plan tomorrow or capture ideas in Inbox.", "No hay tareas próximas. Planifica mañana o captura ideas en Bandeja.", "Não há tarefas próximas. Planeje amanhã ou capture ideias na Caixa de entrada."),
        ("Tasks.EmptyInbox", "Inbox is clear. Capture an idea the moment it lands.", "La bandeja está vacía. Captura una idea en cuanto surja.", "A caixa de entrada está limpa. Capture uma ideia assim que surgir."),
        ("Tasks.EmptyTitle", "Ready when you are", "Listo cuando lo estés", "Pronto quando você estiver"),
        ("Tasks.EmptyCta", "Add a task", "Añadir una tarea", "Adicionar uma tarefa"),
        ("Tasks.KeyboardHints", "Ctrl+N new · Enter add", "Ctrl+N nueva · Enter añadir", "Ctrl+N nova · Enter adicionar"),
        ("Tasks.Add", "Add task", "Añadir tarea", "Adicionar tarefa"),
        ("Tasks.AddPlaceholder", "Add a new task…", "Añadir una tarea nueva…", "Adicionar uma nova tarefa…"),
        ("Tasks.TitleField", "Title", "Título", "Título"),
        ("Tasks.Estimate", "Est. (min)", "Est. (min)", "Est. (min)"),
        ("Tasks.Priority", "Priority (0–3)", "Prioridad (0–3)", "Prioridade (0–3)"),
        ("Tasks.Energy", "Energy", "Energía", "Energia"),
        ("Tasks.Recurrence", "Recurrence", "Recurrencia", "Recorrência"),
        ("Tasks.AddSubtask", "Add subtask", "Añadir subtarea", "Adicionar subtarefa"),
        ("Tasks.Delete", "Delete", "Eliminar", "Excluir"),
        ("Tasks.FreeLimit", "Free plan allows at most {0} incomplete tasks. Upgrade to Pepinillo+ for unlimited tasks.", "El plan gratuito permite como máximo {0} tareas incompletas. Mejora a Pepinillo+ para tareas ilimitadas.", "O plano gratuito permite no máximo {0} tarefas incompletas. Faça upgrade para Pepinillo+ e tenha tarefas ilimitadas."),
        ("Tasks.SubtasksPremium", "Subtasks require Pepinillo+ or Everywhere.", "Las subtareas requieren Pepinillo+ o Everywhere.", "Subtarefas requerem Pepinillo+ ou Everywhere."),
        ("Tasks.RecurrencePremium", "Recurring tasks require Pepinillo+ or Everywhere.", "Las tareas recurrentes requieren Pepinillo+ o Everywhere.", "Tarefas recorrentes requerem Pepinillo+ ou Everywhere."),

        // ── Analytics ───────────────────────────────────────────────────────
        ("Analytics.Title", "Analytics", "Analítica", "Análises"),
        ("Analytics.Subtitle", "Local session totals from SQLite (UTC). Charts use simple ProgressBars.", "Totales de sesión locales desde SQLite (UTC). Los gráficos usan ProgressBars simples.", "Totais de sessão locais do SQLite (UTC). Os gráficos usam ProgressBars simples."),
        ("Analytics.FocusToday", "Focus today", "Enfoque de hoy", "Foco de hoje"),
        ("Analytics.SevenDayFocus", "7-day focus", "Enfoque de 7 días", "Foco de 7 dias"),
        ("Analytics.CurrentStreak", "Current streak", "Racha actual", "Sequência atual"),
        ("Analytics.BestStreak", "Best streak", "Mejor racha", "Melhor sequência"),
        ("Analytics.Achievements", "Achievements", "Logros", "Conquistas"),
        ("Analytics.Export", "Export", "Exportar", "Exportar"),
        ("Analytics.ExportCsv", "Export CSV", "Exportar CSV", "Exportar CSV"),
        ("Analytics.ExportPdf", "Export PDF", "Exportar PDF", "Exportar PDF"),
        ("Analytics.WeeklyReview", "Weekly Review", "Resumen semanal", "Revisão semanal"),
        ("Analytics.MonthlyReview", "Monthly Review", "Resumen mensual", "Revisão mensal"),
        ("Analytics.ProtectionApplied", " · Applied to current streak", " · Aplicada a la racha actual", " · Aplicada à sequência atual"),
        ("Analytics.StreakProtectionPremium", "Streak protection: available (1 / week)", "Protección de racha: disponible (1 / semana)", "Proteção de sequência: disponível (1 / semana)"),
        ("Analytics.StreakProtectionUpgrade", "Upgrade for streak protection (1 skip / week)", "Mejora el plan para protección de racha (1 omisión / semana)", "Faça upgrade para proteção de sequência (1 pulo / semana)"),
        ("Analytics.ExportPremium", "Export is a Pepinillo+ feature.", "Exportar es una función de Pepinillo+.", "Exportar é um recurso do Pepinillo+."),
        ("Analytics.ExportUnavailable", "Export service is unavailable.", "El servicio de exportación no está disponible.", "O serviço de exportação está indisponível."),
        ("Analytics.ExportCsvReady", "CSV ready ({0} sessions).", "CSV listo ({0} sesiones).", "CSV pronto ({0} sessões)."),
        ("Analytics.ExportCsvEmpty", "CSV ready (no sessions in range).", "CSV listo (sin sesiones en el rango).", "CSV pronto (sem sessões no intervalo)."),
        ("Analytics.ExportPdfReady", "PDF ready ({0} sessions).", "PDF listo ({0} sesiones).", "PDF pronto ({0} sessões)."),
        ("Analytics.ExportPdfEmpty", "PDF ready (no sessions in range).", "PDF listo (sin sesiones en el rango).", "PDF pronto (sem sessões no intervalo)."),
        ("Analytics.EmptyState", "No focus history yet. Finish a Pomodoro or Stopwatch session — stats and streaks will show up here.", "Aún no hay historial de enfoque. Completa un Pomodoro o Cronómetro — las estadísticas y rachas aparecerán aquí.", "Ainda não há histórico de foco. Conclua um Pomodoro ou Cronômetro — estatísticas e sequências aparecerão aqui."),
        ("Analytics.InsightEmpty", "Your insights start after the first completed session. Full AI narrative reports unlock with Everywhere/AI+.", "Tus insights empiezan tras la primera sesión completada. Los informes narrativos con IA se desbloquean con Everywhere/AI+.", "Seus insights começam após a primeira sessão concluída. Relatórios narrativos com IA desbloqueiam com Everywhere/AI+."),
        ("Analytics.InsightSummary", "Last {0} days: {1}h focus · Streak {2}d (best {3}d){4}. AI narrative reports unlock with Everywhere/AI+.", "Últimos {0} días: {1}h de enfoque · Racha {2}d (mejor {3}d){4}. Los informes narrativos con IA se desbloquean con Everywhere/AI+.", "Últimos {0} dias: {1}h de foco · Sequência {2}d (melhor {3}d){4}. Relatórios narrativos com IA desbloqueiam com Everywhere/AI+."),

        // ── Soundscapes ─────────────────────────────────────────────────────
        ("Soundscapes.Title", "Soundscapes", "Paisajes sonoros", "Paisagens sonoras"),
        ("Soundscapes.MasterVolume", "Master volume", "Volumen general", "Volume principal"),
        ("Soundscapes.PremiumLocked", "Premium — upgrade to unlock", "Premium — mejora el plan para desbloquear", "Premium — faça upgrade para desbloquear"),
        ("Soundscapes.AssetMissing", "Audio asset missing", "Audio no disponible", "Áudio indisponível"),
        ("Soundscapes.Play", "Play", "Reproducir", "Reproduzir"),
        ("Soundscapes.Stop", "Stop", "Detener", "Parar"),
        ("Soundscapes.Stopped", "Stopped", "Detenido", "Parado"),
        ("Soundscapes.AllStopped", "All stopped", "Todo detenido", "Tudo parado"),
        ("Soundscapes.Playing", "Playing {0}", "Reproduciendo {0}", "Reproduzindo {0}"),
        ("Soundscapes.PlaybackError", "Playback error: {0}", "Error de reproducción: {0}", "Erro de reprodução: {0}"),

        // ── Account ─────────────────────────────────────────────────────────
        ("Account.Title", "Account", "Cuenta", "Conta"),
        ("Account.Subtitle", "Sign in to sync sessions with Everywhere. Local focus data always works offline — free/local users stay local-first.", "Inicia sesión para sincronizar sesiones con Everywhere. Los datos locales de enfoque funcionan sin conexión — usuarios gratuitos/locales permanecen en local-first.", "Entre para sincronizar sessões com Everywhere. Os dados locais de foco funcionam offline — usuários gratuitos/locais permanecem local-first."),
        ("Account.Login", "Sign in", "Iniciar sesión", "Entrar"),
        ("Account.Register", "Create account", "Crear cuenta", "Criar conta"),
        ("Account.Logout", "Sign out", "Cerrar sesión", "Sair"),
        ("Account.SyncNow", "Sync now", "Sincronizar ahora", "Sincronizar agora"),
        ("Account.Email", "Email", "Correo electrónico", "E-mail"),
        ("Account.Password", "Password", "Contraseña", "Senha"),
        ("Account.DisplayName", "Display name (register)", "Nombre visible (registro)", "Nome de exibição (registro)"),
        ("Account.LastSync", "Last sync: ", "Última sincronización: ", "Última sincronização: "),
        ("Account.LocalOnly", "Local only — not signed in", "Solo local — sin sesión", "Somente local — sem sessão"),
        ("Account.SignedInMode", "Signed in — cloud sync when Everywhere is active", "Sesión iniciada — sincronización en la nube con Everywhere activo", "Sessão ativa — sincronização na nuvem com Everywhere ativo"),
        ("Account.SignedInTokenRestored", "Signed in (token restored). Cloud sync needs Everywhere.", "Sesión iniciada (token restaurado). La sincronización en la nube requiere Everywhere.", "Sessão iniciada (token restaurado). Sincronização na nuvem requer Everywhere."),
        ("Account.NotSignedInOffline", "Not signed in — offline local mode. Cloud sync needs Everywhere. Local data always works.", "Sin sesión — modo local sin conexión. La sincronización en la nube requiere Everywhere. Los datos locales siempre funcionan.", "Sem sessão — modo local offline. Sincronização na nuvem requer Everywhere. Dados locais sempre funcionam."),
        ("Account.SignedInSuccess", "Signed in successfully.", "Sesión iniciada correctamente.", "Sessão iniciada com sucesso."),
        ("Account.LoginFailed", "Login failed (check credentials or network).", "Error de inicio de sesión (revise credenciales o red).", "Falha no login (verifique credenciais ou rede)."),
        ("Account.SignedOut", "Signed out. Local data always works offline.", "Sesión cerrada. Los datos locales siempre funcionan sin conexión.", "Sessão encerrada. Dados locais sempre funcionam offline."),
        ("Account.ValidEmail", "Enter a valid email address.", "Introduce un correo electrónico válido.", "Informe um e-mail válido."),
        ("Account.EmailPasswordRequired", "Email and password are required.", "Se requieren correo y contraseña.", "E-mail e senha são obrigatórios."),
        ("Account.AccountCreated", "Account created — signed in.", "Cuenta creada — sesión iniciada.", "Conta criada — sessão iniciada."),
        ("Account.AccountCreatedSignIn", "Account created. Sign in to continue.", "Cuenta creada. Inicia sesión para continuar.", "Conta criada. Entre para continuar."),
        ("Account.RegistrationFailed", "Registration failed (network or email already used).", "Error de registro (red o correo ya usado).", "Falha no registro (rede ou e-mail já usado)."),
        ("Account.CloudSyncNeedsEverywhere", "Cloud sync needs Everywhere. Local data always works.", "La sincronización en la nube requiere Everywhere. Los datos locales siempre funcionan.", "Sincronização na nuvem requer Everywhere. Dados locais sempre funcionam."),
        ("Account.AuthInitFailed", "Auth init failed: {0}", "Error al iniciar autenticación: {0}", "Falha na inicialização de autenticação: {0}"),
        ("Account.LoginError", "Login error: {0}", "Error de inicio de sesión: {0}", "Erro de login: {0}"),
        ("Account.RegistrationError", "Registration error: {0}", "Error de registro: {0}", "Erro de registro: {0}"),
        ("Account.LogoutError", "Logout error: {0}", "Error al cerrar sesión: {0}", "Erro ao sair: {0}"),
        ("Account.SyncFailed", "Sync failed: {0}", "Error de sincronización: {0}", "Falha na sincronização: {0}"),

        // ── Paywall ─────────────────────────────────────────────────────────
        ("Paywall.Title", "Upgrade Pepinillo", "Mejorar Pepinillo", "Fazer upgrade do Pepinillo"),
        ("Paywall.FreeBlurb", "Free includes Pomodoro, Stopwatch, 3 active tasks, and 7-day analytics. Upgrade for Flowtime, Time Blocking, unlimited tasks, premium themes, soundscapes, and cloud sync.", "Gratis incluye Pomodoro, Cronómetro, 3 tareas activas y analítica de 7 días. Mejora para Flowtime, Bloqueo de tiempo, tareas ilimitadas, temas premium, paisajes sonoros y sincronización en la nube.", "O gratuito inclui Pomodoro, Cronômetro, 3 tarefas ativas e análises de 7 dias. Faça upgrade para Flowtime, Bloco de tempo, tarefas ilimitadas, temas premium, paisagens sonoras e sincronização na nuvem."),
        ("Paywall.PlusFeatures", "Flowtime, Time Blocking, unlimited local tasks, premium themes (Forest, Ocean, Sunset), premium soundscapes, desktop power features.", "Flowtime, Bloqueo de tiempo, tareas locales ilimitadas, temas premium (Bosque, Océano, Atardecer), paisajes sonoros premium, potencias de escritorio.", "Flowtime, Bloco de tempo, tarefas locais ilimitadas, temas premium (Floresta, Oceano, Pôr do sol), paisagens sonoras premium, recursos de desktop."),
        ("Paywall.EverywhereFeatures", "Cloud sync across platforms, AI reports, and cross-device entitlement.", "Sincronización en la nube entre plataformas, informes con IA y derechos entre dispositivos.", "Sincronização na nuvem entre plataformas, relatórios com IA e direitos entre dispositivos."),
        ("Paywall.Subscription", "Subscription", "Suscripción", "Assinatura"),
        ("Paywall.BuyPlus", "Buy Pepinillo+", "Comprar Pepinillo+", "Comprar Pepinillo+"),
        ("Paywall.SubscribeMonthly", "Subscribe monthly", "Suscribirse mensualmente", "Assinar mensalmente"),
        ("Paywall.SubscribeAnnual", "Subscribe annual", "Suscribirse anualmente", "Assinar anualmente"),
        ("Paywall.Restore", "Restore purchases", "Restaurar compras", "Restaurar compras"),
        ("Paywall.ManageStore", "Manage purchases in Microsoft Store", "Administrar compras en Microsoft Store", "Gerenciar compras na Microsoft Store"),
        ("Paywall.NotASubscription", "One-time purchase — not a subscription", "Compra única — no es una suscripción", "Compra única — não é uma assinatura"),
        ("Paywall.CurrentTier", "Current tier: {0} · source: {1}", "Plan actual: {0} · origen: {1}", "Plano atual: {0} · origem: {1}"),
        ("Paywall.CurrentTierFree", "Current tier: Free", "Plan actual: Gratis", "Plano atual: Gratuito"),
        ("Paywall.TierFree", "Free", "Gratis", "Gratuito"),
        ("Paywall.TierPlus", "Pepinillo+", "Pepinillo+", "Pepinillo+"),
        ("Paywall.TierEverywhere", "Everywhere / AI+", "Everywhere / AI+", "Everywhere / AI+"),
        ("Paywall.RestoreSuccess", "Purchases restored. Your plan is active.", "Compras restauradas. Tu plan está activo.", "Compras restauradas. Seu plano está ativo."),
        ("Paywall.RestoreNone", "No active purchases found. You're on Free — upgrade anytime.", "No se encontraron compras activas. Estás en Gratis — mejora cuando quieras.", "Nenhuma compra ativa encontrada. Você está no Gratuito — faça upgrade quando quiser."),
        ("Paywall.RestoreError", "Restore error: {0}", "Error al restaurar: {0}", "Erro ao restaurar: {0}"),
        ("Paywall.PurchaseError", "Purchase error: {0}", "Error de compra: {0}", "Erro de compra: {0}"),

        // ── Onboarding ──────────────────────────────────────────────────────
        ("Onboarding.StepTitle0", "Welcome to Pepinillo", "Bienvenido a Pepinillo", "Bem-vindo ao Pepinillo"),
        ("Onboarding.StepTitle1", "Four ways to focus", "Cuatro formas de enfocarte", "Quatro formas de focar"),
        ("Onboarding.StepTitle2", "Desktop power", "Potencia de escritorio", "Poder no desktop"),
        ("Onboarding.StepTitle3", "Optional account", "Cuenta opcional", "Conta opcional"),
        ("Onboarding.StepTitle4", "You're ready", "Todo listo", "Você está pronto"),
        ("Onboarding.StepBody0", "Deep Work OS for Windows — timers, tasks, analytics, and ambient soundscapes. Built for long sessions at your desk.", "Sistema de trabajo profundo para Windows — temporizadores, tareas, analítica y paisajes sonoros. Hecho para sesiones largas en el escritorio.", "Sistema de deep work para Windows — temporizadores, tarefas, análises e paisagens sonoras. Feito para sessões longas na mesa."),
        ("Onboarding.StepBody1", "Pick a default mode. Pomodoro and Stopwatch are free. Flowtime and Time Blocking unlock with Pepinillo+.", "Elige un modo predeterminado. Pomodoro y Cronómetro son gratis. Flowtime y Bloqueo de tiempo se desbloquean con Pepinillo+.", "Escolha um modo padrão. Pomodoro e Cronômetro são gratuitos. Flowtime e Bloco de tempo desbloqueiam com Pepinillo+."),
        ("Onboarding.StepBody2", "Close to the tray, use global hotkeys, and keep a mini timer on top while you work in other apps.", "Cierra a la bandeja, usa atajos globales y mantén un mini temporizador encima mientras trabajas en otras apps.", "Feche para a bandeja, use atalhos globais e mantenha um mini temporizador no topo enquanto trabalha em outros apps."),
        ("Onboarding.StepBody3", "Stay local forever, or sign in later for Everywhere cloud session sync. You can skip this for now.", "Quédate en local para siempre, o inicia sesión más tarde para sincronizar sesiones con Everywhere. Puedes omitir esto por ahora.", "Fique local para sempre, ou entre depois para sincronizar sessões com Everywhere. Você pode pular isso por enquanto."),
        ("Onboarding.StepBody4", "Start a session from Focus. Open Settings anytime to replay this guide or tune durations and hotkeys.", "Inicia una sesión desde Enfoque. Abre Configuración cuando quieras para repetir esta guía o ajustar duraciones y atajos.", "Inicie uma sessão em Foco. Abra Configurações a qualquer momento para rever este guia ou ajustar durações e atalhos."),
        ("Onboarding.DesktopTray", "System tray — minimize or close keeps Pepinillo running in the background.", "Bandeja del sistema — minimizar o cerrar mantiene Pepinillo en segundo plano.", "Bandeja do sistema — minimizar ou fechar mantém o Pepinillo em segundo plano."),
        ("Onboarding.DesktopHotkeys", "Hotkeys — Win+Shift+P play/pause · Win+Shift+S skip break · Win+Shift+M mini timer.", "Atajos — Win+Shift+P reproducir/pausar · Win+Shift+S saltar descanso · Win+Shift+M mini temporizador.", "Atalhos — Win+Shift+P reproduzir/pausar · Win+Shift+S pular pausa · Win+Shift+M mini temporizador."),
        ("Onboarding.DesktopMini", "Mini timer — compact always-on-top overlay for multi-tasking.", "Mini temporizador — superposición compacta siempre visible para multitarea.", "Mini temporizador — sobreposição compacta sempre no topo para multitarefa."),
        ("Onboarding.AccountTeaser", "Account is optional. Free and paid local features work offline without signing in.", "La cuenta es opcional. Las funciones locales gratuitas y de pago funcionan sin conexión sin iniciar sesión.", "A conta é opcional. Recursos locais gratuitos e pagos funcionam offline sem entrar."),
        ("Onboarding.Skip", "Skip", "Omitir", "Pular"),
        ("Onboarding.Back", "Back", "Atrás", "Voltar"),
        ("Onboarding.Next", "Next", "Siguiente", "Próximo"),
        ("Onboarding.GetStarted", "Get started", "Empezar", "Começar"),
        ("Onboarding.StepProgress", "Step {0} of {1}", "Paso {0} de {1}", "Etapa {0} de {1}"),
        ("Onboarding.SaveFailed", "Could not save onboarding: {0}", "No se pudo guardar la bienvenida: {0}", "Não foi possível salvar o onboarding: {0}"),
    };

    private readonly Dictionary<string, Dictionary<string, string>> _catalog;

    public string CurrentLanguage { get; private set; } = "en";

    public LocalizationService()
    {
        _catalog = new Dictionary<string, Dictionary<string, string>>(StringComparer.OrdinalIgnoreCase)
        {
            ["en"] = new(StringComparer.OrdinalIgnoreCase),
            ["es"] = new(StringComparer.OrdinalIgnoreCase),
            ["pt"] = new(StringComparer.OrdinalIgnoreCase),
        };

        foreach (var (key, en, es, pt) in Entries)
        {
            _catalog["en"][key] = en;
            _catalog["es"][key] = es;
            _catalog["pt"][key] = pt;
        }
    }

    public void SetLanguage(string languageCode)
    {
        var code = Normalize(languageCode);
        CurrentLanguage = _catalog.ContainsKey(code) ? code : "en";
    }

    public string GetString(string key)
    {
        if (_catalog.TryGetValue(CurrentLanguage, out var dict)
            && dict.TryGetValue(key, out var value))
            return value;

        if (_catalog["en"].TryGetValue(key, out var en))
            return en;

        return key;
    }

    public IReadOnlyCollection<string> GetKeys(string languageCode)
    {
        var code = Normalize(languageCode);
        if (!_catalog.TryGetValue(code, out var dict))
            dict = _catalog["en"];
        return dict.Keys.ToList();
    }

    private static string Normalize(string? code)
    {
        if (string.IsNullOrWhiteSpace(code))
            return "en";
        code = code.Trim().ToLowerInvariant();
        if (code.StartsWith("es", StringComparison.Ordinal)) return "es";
        if (code.StartsWith("pt", StringComparison.Ordinal)) return "pt";
        return "en";
    }
}
