using System.Threading.Tasks;
using Pepinillo.Core.Models;

namespace Pepinillo.Core.Services;

public interface ISyncService
{
    Task<SyncResult> SyncNowAsync();
}

public class SyncResult
{
    public bool Success { get; set; }
    public bool WasAuthenticated { get; set; }
    public int SessionsPushed { get; set; }
    public int SessionsPulled { get; set; }
    public bool RequiresEverywhere { get; set; }
    public string Message { get; set; } = string.Empty;
    public SubscriptionStatus? Subscription { get; set; }
}
