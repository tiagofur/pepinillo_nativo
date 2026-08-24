import Foundation
#if !os(watchOS)
enum TasksWidgetAccess {
    static let everywhereOfflineGracePeriod: TimeInterval = 7 * 24 * 60 * 60
    static func isAuthorized(tierIdentifier: String?, capabilities: UserCapabilities?,
                             lastVerifiedDate: Date?, expirationDate: Date?, now: Date = Date()) -> Bool {
        if tierIdentifier == "pepinillo_plus", capabilities == .pepinilloPlus { return true }
        guard tierIdentifier == "everywhere_plus", capabilities == .everywherePlus else { return false }
        guard let lastVerifiedDate else { return false }
        let verificationAge = now.timeIntervalSince(lastVerifiedDate)
        guard verificationAge >= 0, verificationAge < everywhereOfflineGracePeriod else { return false }
        return expirationDate.map { $0 > now } ?? true
    }
    static func isCurrentUserAuthorized(now: Date = Date()) -> Bool {
        isAuthorized(tierIdentifier: AppGroupDefaults.subscriptionTierIdentifier,
                     capabilities: AppGroupDefaults.userCapabilities,
                     lastVerifiedDate: AppGroupDefaults.lastVerifiedDate,
                     expirationDate: AppGroupDefaults.subscriptionExpirationDate, now: now)
    }
    static func nextRefreshDate(now: Date, normalRefresh: Date) -> Date {
        guard isCurrentUserAuthorized(now: now) else { return normalRefresh }
        let expiration = AppGroupDefaults.subscriptionExpirationDate.flatMap { $0 > now ? $0 : nil } ?? normalRefresh
        guard AppGroupDefaults.subscriptionTierIdentifier == "everywhere_plus",
              let verified = AppGroupDefaults.lastVerifiedDate else { return min(normalRefresh, expiration) }
        return min(normalRefresh, min(expiration, verified.addingTimeInterval(everywhereOfflineGracePeriod)))
    }
    static func loadIfAuthorized<Value>(now: Date = Date(), _ load: () throws -> Value) rethrows -> Value? {
        isCurrentUserAuthorized(now: now) ? try load() : nil
    }
}
#endif
