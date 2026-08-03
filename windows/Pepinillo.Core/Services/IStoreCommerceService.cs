using System.Threading.Tasks;
using Pepinillo.Core.Models;

namespace Pepinillo.Core.Services;

public interface IStoreCommerceService
{
    Task<SubscriptionStatus> CheckStoreEntitlementsAsync();
    Task<bool> PurchasePepinilloPlusAsync();
    Task<bool> SubscribeEverywherePlusAsync(bool annual = false);
}
