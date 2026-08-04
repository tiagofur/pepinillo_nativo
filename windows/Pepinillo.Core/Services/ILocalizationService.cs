using System.Collections.Generic;

namespace Pepinillo.Core.Services;

/// <summary>
/// Lightweight in-memory localizer (EN / ES / PT).
/// Full WinUI .resw dictionaries can wrap the same keys later without changing call sites.
/// </summary>
public interface ILocalizationService
{
    string CurrentLanguage { get; }
    void SetLanguage(string languageCode);
    string GetString(string key);

    /// <summary>All keys registered for a language (used by catalog parity tests).</summary>
    IReadOnlyCollection<string> GetKeys(string languageCode);
}
