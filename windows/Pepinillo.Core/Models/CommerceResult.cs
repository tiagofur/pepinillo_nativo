namespace Pepinillo.Core.Models;

/// <summary>
/// Result of a store purchase or restore attempt with an honest user-facing message.
/// </summary>
public sealed record CommerceResult(bool Success, string Message, SubscriptionStatus? Status = null)
{
    public static CommerceResult Ok(string message, SubscriptionStatus? status = null) =>
        new(true, message, status);

    public static CommerceResult Fail(string message, SubscriptionStatus? status = null) =>
        new(false, message, status);
}
