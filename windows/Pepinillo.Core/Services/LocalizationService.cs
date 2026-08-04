using System;
using System.Collections.Generic;

namespace Pepinillo.Core.Services;

/// <summary>
/// Lightweight in-memory localizer for EN / ES / PT shell strings.
/// Full .resw dictionaries can replace this later without changing call sites.
/// </summary>
public class LocalizationService : ILocalizationService
{
    private readonly Dictionary<string, Dictionary<string, string>> _catalog;

    public string CurrentLanguage { get; private set; } = "en";

    public LocalizationService()
    {
        _catalog = new Dictionary<string, Dictionary<string, string>>(StringComparer.OrdinalIgnoreCase)
        {
            ["en"] = new(StringComparer.OrdinalIgnoreCase)
            {
                ["Settings.Title"] = "Settings",
                ["Settings.TimerDurations"] = "Timer durations",
                ["Settings.PomodoroFocus"] = "Pomodoro focus (minutes)",
                ["Settings.ShortBreak"] = "Short break (minutes)",
                ["Settings.LongBreak"] = "Long break (minutes)",
                ["Settings.AutoStartBreaks"] = "Auto-start breaks",
                ["Settings.AutoStartFocus"] = "Auto-start next focus after break",
                ["Settings.Appearance"] = "Appearance",
                ["Settings.Theme"] = "Theme",
                ["Settings.Save"] = "Save settings",
                ["Settings.Saved"] = "Settings saved",
                ["Settings.Language"] = "Language",
                ["Settings.Privacy"] = "Privacy policy",
                ["Settings.Terms"] = "Terms of use",
                ["Settings.Upgrade"] = "Upgrade",
                ["Focus.Title"] = "Focus Engine",
                ["Focus.Ready"] = "Ready",
                ["Focus.Focusing"] = "Focusing",
                ["Focus.Paused"] = "Paused",
                ["Focus.OnBreak"] = "On break",
                ["Focus.Completed"] = "Completed",
                ["Focus.Start"] = "Start / Resume",
                ["Focus.Pause"] = "Pause",
                ["Focus.Stop"] = "Stop",
                ["Focus.SkipBreak"] = "Skip break",
                ["Focus.LinkTask"] = "Link a task (optional)",
                ["Focus.JournalTitle"] = "Session reflection",
                ["Focus.JournalSave"] = "Save journal",
                ["Focus.JournalDismiss"] = "Dismiss",
                ["Account.Title"] = "Account",
                ["Account.Login"] = "Sign in",
                ["Account.Register"] = "Create account",
                ["Account.Logout"] = "Sign out",
                ["Account.SyncNow"] = "Sync now",
                ["Paywall.Title"] = "Upgrade Pepinillo",
                ["Soundscapes.Title"] = "Soundscapes",
                ["Soundscapes.MasterVolume"] = "Master volume",
                ["Soundscapes.PremiumLocked"] = "Premium — upgrade to unlock",
                ["Soundscapes.AssetMissing"] = "Audio asset missing"
            },
            ["es"] = new(StringComparer.OrdinalIgnoreCase)
            {
                ["Settings.Title"] = "Configuración",
                ["Settings.TimerDurations"] = "Duraciones del temporizador",
                ["Settings.PomodoroFocus"] = "Enfoque Pomodoro (minutos)",
                ["Settings.ShortBreak"] = "Descanso corto (minutos)",
                ["Settings.LongBreak"] = "Descanso largo (minutos)",
                ["Settings.AutoStartBreaks"] = "Iniciar descansos automáticamente",
                ["Settings.AutoStartFocus"] = "Iniciar siguiente enfoque tras el descanso",
                ["Settings.Appearance"] = "Apariencia",
                ["Settings.Theme"] = "Tema",
                ["Settings.Save"] = "Guardar configuración",
                ["Settings.Saved"] = "Configuración guardada",
                ["Settings.Language"] = "Idioma",
                ["Settings.Privacy"] = "Política de privacidad",
                ["Settings.Terms"] = "Términos de uso",
                ["Settings.Upgrade"] = "Mejorar plan",
                ["Focus.Title"] = "Motor de enfoque",
                ["Focus.Ready"] = "Listo",
                ["Focus.Focusing"] = "Enfocando",
                ["Focus.Paused"] = "Pausado",
                ["Focus.OnBreak"] = "En descanso",
                ["Focus.Completed"] = "Completado",
                ["Focus.Start"] = "Iniciar / Reanudar",
                ["Focus.Pause"] = "Pausar",
                ["Focus.Stop"] = "Detener",
                ["Focus.SkipBreak"] = "Saltar descanso",
                ["Focus.LinkTask"] = "Vincular tarea (opcional)",
                ["Focus.JournalTitle"] = "Reflexión de sesión",
                ["Focus.JournalSave"] = "Guardar diario",
                ["Focus.JournalDismiss"] = "Descartar",
                ["Account.Title"] = "Cuenta",
                ["Account.Login"] = "Iniciar sesión",
                ["Account.Register"] = "Crear cuenta",
                ["Account.Logout"] = "Cerrar sesión",
                ["Account.SyncNow"] = "Sincronizar ahora",
                ["Paywall.Title"] = "Mejorar Pepinillo",
                ["Soundscapes.Title"] = "Paisajes sonoros",
                ["Soundscapes.MasterVolume"] = "Volumen general",
                ["Soundscapes.PremiumLocked"] = "Premium — mejora para desbloquear",
                ["Soundscapes.AssetMissing"] = "Audio no disponible"
            },
            ["pt"] = new(StringComparer.OrdinalIgnoreCase)
            {
                ["Settings.Title"] = "Configurações",
                ["Settings.TimerDurations"] = "Durações do temporizador",
                ["Settings.PomodoroFocus"] = "Foco Pomodoro (minutos)",
                ["Settings.ShortBreak"] = "Pausa curta (minutos)",
                ["Settings.LongBreak"] = "Pausa longa (minutos)",
                ["Settings.AutoStartBreaks"] = "Iniciar pausas automaticamente",
                ["Settings.AutoStartFocus"] = "Iniciar próximo foco após a pausa",
                ["Settings.Appearance"] = "Aparência",
                ["Settings.Theme"] = "Tema",
                ["Settings.Save"] = "Salvar configurações",
                ["Settings.Saved"] = "Configurações salvas",
                ["Settings.Language"] = "Idioma",
                ["Settings.Privacy"] = "Política de privacidade",
                ["Settings.Terms"] = "Termos de uso",
                ["Settings.Upgrade"] = "Fazer upgrade",
                ["Focus.Title"] = "Motor de foco",
                ["Focus.Ready"] = "Pronto",
                ["Focus.Focusing"] = "Focando",
                ["Focus.Paused"] = "Pausado",
                ["Focus.OnBreak"] = "Em pausa",
                ["Focus.Completed"] = "Concluído",
                ["Focus.Start"] = "Iniciar / Retomar",
                ["Focus.Pause"] = "Pausar",
                ["Focus.Stop"] = "Parar",
                ["Focus.SkipBreak"] = "Pular pausa",
                ["Focus.LinkTask"] = "Vincular tarefa (opcional)",
                ["Focus.JournalTitle"] = "Reflexão da sessão",
                ["Focus.JournalSave"] = "Salvar diário",
                ["Focus.JournalDismiss"] = "Dispensar",
                ["Account.Title"] = "Conta",
                ["Account.Login"] = "Entrar",
                ["Account.Register"] = "Criar conta",
                ["Account.Logout"] = "Sair",
                ["Account.SyncNow"] = "Sincronizar agora",
                ["Paywall.Title"] = "Fazer upgrade do Pepinillo",
                ["Soundscapes.Title"] = "Paisagens sonoras",
                ["Soundscapes.MasterVolume"] = "Volume principal",
                ["Soundscapes.PremiumLocked"] = "Premium — faça upgrade para desbloquear",
                ["Soundscapes.AssetMissing"] = "Áudio indisponível"
            }
        };
    }

    public void SetLanguage(string languageCode)
    {
        var code = Normalize(languageCode);
        if (_catalog.ContainsKey(code))
            CurrentLanguage = code;
        else
            CurrentLanguage = "en";
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
