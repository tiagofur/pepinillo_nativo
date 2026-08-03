using System.Net.Http;
using System.Threading.Tasks;
using Pepinillo.Core.Models;
using Pepinillo.Core.Services;
using Xunit;

namespace Pepinillo.Core.Tests;

public class CommerceAndSyncTests
{
    [Fact]
    public async Task CheckStoreEntitlements_ShouldDefaultToFree_WhenNotAuthenticated()
    {
        var httpClient = new HttpClient();
        var backendClient = new BackendApiClient(httpClient);
        var commerceService = new StoreCommerceService(backendClient);

        var status = await commerceService.CheckStoreEntitlementsAsync();

        Assert.NotNull(status);
        Assert.Equal(EntitlementTier.Free, status.Tier);
        Assert.False(status.IsActive);
    }
}
