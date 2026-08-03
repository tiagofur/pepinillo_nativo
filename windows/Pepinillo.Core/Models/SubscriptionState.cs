namespace Pepinillo.Core.Models;

/// <summary>
/// User entitlement tier for Pepinillo.
/// </summary>
public enum EntitlementTier
{
    /// <summary>
    /// Free core experience (Pomodoro + Stopwatch, 3 active tasks, 7d history).
    /// </summary>
    Free,

    /// <summary>
    /// Pepinillo+ (One-time purchase / Lifetime): Flowtime, Time Blocking, unlimited tasks, all local desktop features.
    /// </summary>
    PepinilloPlus,

    /// <summary>
    /// Everywhere / AI+ (Subscription): Cloud sync across iOS/Android/Windows, cloud AI reports, predictive insights.
    /// </summary>
    EverywherePlus
}

public class SubscriptionStatus
{
    public EntitlementTier Tier { get; set; } = EntitlementTier.Free;

    public bool IsActive => Tier != EntitlementTier.Free;

    public string SourceStore { get; set; } = "MicrosoftStore";

    public System.DateTime? ExpirationDate { get; set; }
}
