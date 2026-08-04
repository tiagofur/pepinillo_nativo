using System.Collections.Generic;
using Pepinillo.Core.Models;

namespace Pepinillo.Core.Services;

/// <summary>
/// Builds export payloads for focus session history (CSV / simple PDF). Premium-gated at call sites.
/// </summary>
public interface IExportService
{
    /// <summary>
    /// Builds UTF-8 CSV (with BOM) of completed sessions.
    /// Columns: Id, Mode, StartedAtUtc, CompletedAtUtc, ElapsedSeconds, TargetDurationSeconds, JournalNote, EnergyRating, TaskItemId
    /// </summary>
    string BuildSessionsCsv(IReadOnlyList<FocusSession> sessions);

    /// <summary>
    /// Minimal PDF 1.4 (text-only, multipage) summarizing sessions. No external packages.
    /// </summary>
    byte[] BuildSessionsPdfSimple(IReadOnlyList<FocusSession> sessions, string title = "Pepinillo Focus Sessions");
}
