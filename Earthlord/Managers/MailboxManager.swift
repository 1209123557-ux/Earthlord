//
//  MailboxManager.swift
//  Earthlord
//
//  邮箱管理：加载、领取、一键全领
//

import Foundation
import Supabase
import OSLog
import Combine

@MainActor
final class MailboxManager: ObservableObject {

    static let shared = MailboxManager()
    private let logger = Logger(subsystem: "com.earthlord", category: "MailboxManager")

    // MARK: - Published

    @Published private(set) var items: [MailboxItem] = []
    @Published private(set) var isLoading = false
    @Published private(set) var claimError: String? = nil
    @Published private(set) var isClaiming = false

    /// 未领取且未过期的邮件数量（用于红点提示）
    var unclaimedCount: Int {
        items.filter { !$0.isClaimed && !$0.isExpired }.count
    }

    // MARK: - Fetch

    func fetchMailbox() async {
        guard let userId = AuthManager.shared.currentUser?.id else { return }
        isLoading = true
        do {
            let rows: [MailboxItem] = try await supabase
                .from("player_mailbox")
                .select("id, item_id, quantity, source, product_id, expires_at, claimed_at, created_at")
                .eq("user_id", value: userId.uuidString.lowercased())
                .order("created_at", ascending: false)
                .execute()
                .value
            items = rows
            logger.info("[Mailbox] 加载完成，共 \(rows.count) 封邮件，未领取 \(self.unclaimedCount) 封")
        } catch {
            logger.error("[Mailbox] 加载失败: \(error.localizedDescription)")
        }
        isLoading = false
    }

    // MARK: - Claim Single Item

    func claimItem(_ mailboxItem: MailboxItem) async -> ClaimResult {
        guard !mailboxItem.isClaimed else { return .alreadyClaimed }
        guard !mailboxItem.isExpired  else { return .expired }

        let inventoryManager = InventoryManager.shared
        let remaining = inventoryManager.maxCapacity - inventoryManager.totalCount
        guard remaining >= mailboxItem.quantity else {
            return .bagFull(need: mailboxItem.quantity, available: remaining)
        }

        isClaiming = true
        claimError = nil
        defer { isClaiming = false }

        do {
            // 写入背包
            try await inventoryManager.addItems(
                [(itemId: mailboxItem.itemId, quantity: mailboxItem.quantity)],
                reason: "邮箱领取"
            )
            // 标记已领取
            try await supabase
                .from("player_mailbox")
                .update(["claimed_at": AnyJSON.string(ISO8601DateFormatter().string(from: Date()))])
                .eq("id", value: mailboxItem.id)
                .execute()

            await fetchMailbox()
            logger.info("[Mailbox] 领取成功: \(mailboxItem.itemId) x\(mailboxItem.quantity)")
            return .success
        } catch {
            claimError = "领取失败：\(error.localizedDescription)"
            logger.error("[Mailbox] 领取失败: \(error.localizedDescription)")
            return .failed(error.localizedDescription)
        }
    }

    // MARK: - Claim All

    func claimAll() async {
        let claimable = items.filter { !$0.isClaimed && !$0.isExpired }
        guard !claimable.isEmpty else { return }

        let inventoryManager = InventoryManager.shared
        let totalNeeded = claimable.reduce(0) { $0 + $1.quantity }
        let remaining = inventoryManager.maxCapacity - inventoryManager.totalCount

        if remaining < totalNeeded {
            claimError = "背包空间不足（需要 \(totalNeeded) 格，剩余 \(remaining) 格），请先清理背包或购买扩容包"
            return
        }

        isClaiming = true
        claimError = nil
        defer { isClaiming = false }

        do {
            // 批量写入背包
            let list = claimable.map { (itemId: $0.itemId, quantity: $0.quantity) }
            try await inventoryManager.addItems(list, reason: "邮箱批量领取")

            // 批量标记已领取
            let ids = claimable.map { $0.id }
            try await supabase
                .from("player_mailbox")
                .update(["claimed_at": AnyJSON.string(ISO8601DateFormatter().string(from: Date()))])
                .in("id", values: ids)
                .execute()

            await fetchMailbox()
            logger.info("[Mailbox] 一键领取成功，共 \(claimable.count) 封")
        } catch {
            claimError = "批量领取失败：\(error.localizedDescription)"
            logger.error("[Mailbox] 批量领取失败: \(error.localizedDescription)")
        }
    }

    // MARK: - ClaimResult

    enum ClaimResult {
        case success
        case alreadyClaimed
        case expired
        case bagFull(need: Int, available: Int)
        case failed(String)
    }
}
