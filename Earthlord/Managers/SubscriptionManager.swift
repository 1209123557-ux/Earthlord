//
//  SubscriptionManager.swift
//  Earthlord
//
//  订阅状态管理：读取 StoreKit Transaction 确定当前档位，查询/发放每日补给。
//

import Foundation
import StoreKit
import Supabase
import Combine
import OSLog

@MainActor
final class SubscriptionManager: ObservableObject {

    static let shared = SubscriptionManager()
    private let logger = Logger(subsystem: "com.earthlord", category: "SubscriptionManager")

    // MARK: - Published

    @Published private(set) var tier: SubscriptionTier = .none
    @Published private(set) var expirationDate: Date? = nil
    @Published private(set) var canClaimToday: Bool = false
    @Published private(set) var isClaimLoading: Bool = false

    var isSubscribed: Bool { tier != .none }

    // MARK: - Init

    private var updateListenerTask: Task<Void, Never>?

    private init() {
        updateListenerTask = listenForUpdates()
        Task { await refreshStatus() }
    }

    deinit {
        updateListenerTask?.cancel()
    }

    // MARK: - Refresh Subscription Status

    func refreshStatus() async {
        var highestTier: SubscriptionTier = .none
        var latestExpiration: Date? = nil

        for await result in Transaction.currentEntitlements {
            guard case .verified(let transaction) = result else { continue }
            guard transaction.revocationDate == nil else { continue }

            let productId = transaction.productID
            if productId == SubscriptionTier.yearly.rawValue {
                highestTier = .yearly
                latestExpiration = transaction.expirationDate
            } else if productId == SubscriptionTier.monthly.rawValue, highestTier == .none {
                highestTier = .monthly
                latestExpiration = transaction.expirationDate
            }
        }

        tier = highestTier
        expirationDate = latestExpiration
        logger.info("[Subscription] 当前档位: \(highestTier.tierName)")

        if highestTier != .none {
            await checkDailyClaimStatus()
        } else {
            canClaimToday = false
        }
    }

    // MARK: - Check Daily Claim

    func checkDailyClaimStatus() async {
        guard let userId = AuthManager.shared.currentUser?.id else { return }
        guard tier != .none else { canClaimToday = false; return }

        let today = todayDateString()
        do {
            struct ClaimRow: Decodable {
                let claimDate: String
                enum CodingKeys: String, CodingKey {
                    case claimDate = "claim_date"
                }
            }
            let rows: [ClaimRow] = try await supabase
                .from("subscription_daily_claims")
                .select("claim_date")
                .eq("user_id", value: userId.uuidString.lowercased())
                .eq("claim_date", value: today)
                .execute()
                .value
            canClaimToday = rows.isEmpty
            logger.info("[Subscription] 今日补给可领取: \(self.canClaimToday)")
        } catch {
            logger.error("[Subscription] 检查每日领取状态失败: \(error.localizedDescription)")
        }
    }

    // MARK: - Claim Daily Reward

    @discardableResult
    func claimDailyReward() async -> Bool {
        guard let userId = AuthManager.shared.currentUser?.id else { return false }
        guard tier != .none, canClaimToday else { return false }

        isClaimLoading = true
        defer { isClaimLoading = false }

        let today = todayDateString()
        let params: [String: AnyJSON] = [
            "p_user_id": .string(userId.uuidString.lowercased()),
            "p_date":    .string(today),
            "p_tier":    .string(tier.rawValue == "com.earthlord.sub.monthly" ? "monthly" : "yearly")
        ]

        do {
            let result: Bool = try await supabase
                .rpc("grant_daily_subscription_reward", params: params)
                .execute()
                .value
            if result {
                canClaimToday = false
                await MailboxManager.shared.fetchMailbox()
                logger.info("[Subscription] 每日补给领取成功（\(self.tier.tierName)）")
                return true
            } else {
                logger.info("[Subscription] 今日已领取")
                return false
            }
        } catch {
            logger.error("[Subscription] 领取每日补给失败: \(error.localizedDescription)")
            return false
        }
    }

    // MARK: - Listen for StoreKit Updates

    private func listenForUpdates() -> Task<Void, Never> {
        Task(priority: .background) { [weak self] in
            for await _ in Transaction.updates {
                guard let self else { return }
                await self.refreshStatus()
            }
        }
    }

    // MARK: - Helpers

    private func todayDateString() -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.timeZone = TimeZone.current
        return formatter.string(from: Date())
    }
}
