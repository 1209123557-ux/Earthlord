//
//  BuildingManager.swift
//  Earthlord
//
//  建造系统核心逻辑：模板加载、资源检查、建造、升级。
//

import Foundation
import Combine
import Supabase
import OSLog
import CoreLocation

@MainActor
final class BuildingManager: ObservableObject {

    static let shared = BuildingManager()

    private let logger = Logger(subsystem: "com.earthlord", category: "BuildingManager")

    // MARK: - Published

    @Published private(set) var buildingTemplates: [BuildingTemplate] = []
    @Published private(set) var playerBuildings: [PlayerBuilding] = []
    @Published private(set) var isLoading = false
    @Published var errorMessage: String?
    @Published private(set) var buildingUpdateVersion: Int = 0

    /// 单个领地最多建造数量上限
    private let maxBuildingsPerTerritory = 10

    // MARK: - 加载模板（从 Bundle JSON）

    func loadTemplates() {
        guard let url = Bundle.main.url(forResource: "building_templates", withExtension: "json") else {
            logger.error("[Building] 找不到 building_templates.json")
            return
        }
        do {
            let data = try Data(contentsOf: url)
            let decoder = JSONDecoder()
            buildingTemplates = try decoder.decode([BuildingTemplate].self, from: data)
            logger.info("[Building] ✅ 成功加载 \(self.buildingTemplates.count) 个建筑模板")
        } catch {
            logger.error("[Building] 模板解析失败: \(error.localizedDescription)")
        }
    }

    // MARK: - 检查是否可以建造

    /// 检查资源是否充足、建筑数量是否超上限
    func canBuild(template: BuildingTemplate, territoryId: String) throws {
        // 检查数量上限
        let existing = playerBuildings.filter { $0.territoryId == territoryId }
        if existing.count >= maxBuildingsPerTerritory {
            throw BuildingError.maxBuildingsReached(limit: maxBuildingsPerTerritory)
        }

        // 检查资源
        let inventoryMap = Dictionary(
            uniqueKeysWithValues: InventoryManager.shared.items.map { ($0.itemId, $0.quantity) }
        )
        for (itemId, required) in template.requiredResources {
            let available = inventoryMap[itemId] ?? 0
            if available < required {
                throw BuildingError.insufficientResources(
                    itemId: itemId,
                    required: required,
                    available: available
                )
            }
        }
    }

    // MARK: - 开始建造

    func startConstruction(
        templateId: String,
        territoryId: String,
        location: CLLocationCoordinate2D? = nil
    ) async throws {
        guard let userId = AuthManager.shared.currentUser?.id else {
            throw BuildingError.notAuthenticated
        }
        guard let template = buildingTemplates.first(where: { $0.id == templateId }) else {
            throw BuildingError.templateNotFound(templateId: templateId)
        }

        // 检查资源和数量
        try canBuild(template: template, territoryId: territoryId)

        isLoading = true
        defer { isLoading = false }

        // 扣减资源
        for (itemId, quantity) in template.requiredResources {
            try await InventoryManager.shared.removeItem(itemId, quantity: quantity)
        }

        // 计算完成时间
        let completedAt = Date().addingTimeInterval(TimeInterval(template.buildTimeSeconds))

        // INSERT player_buildings
        struct InsertPayload: Encodable {
            let user_id: String
            let territory_id: String
            let template_id: String
            let building_name: String
            let status: String
            let location_lat: Double?
            let location_lon: Double?
            let build_completed_at: String
        }

        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]

        let payload = InsertPayload(
            user_id: userId.uuidString.lowercased(),
            territory_id: territoryId,
            template_id: templateId,
            building_name: template.name,
            status: BuildingStatus.constructing.rawValue,
            location_lat: location?.latitude,
            location_lon: location?.longitude,
            build_completed_at: formatter.string(from: completedAt)
        )

        let inserted: PlayerBuilding = try await supabase
            .from("player_buildings")
            .insert(payload)
            .select()
            .single()
            .execute()
            .value

        playerBuildings.append(inserted)
        buildingUpdateVersion += 1
        logger.info("[Building] ✅ 开始建造 \(template.name)，预计完成：\(formatter.string(from: completedAt))")

        // 倒计时后自动完成
        let buildingId = inserted.id
        let delay = UInt64(template.buildTimeSeconds) * 1_000_000_000
        Task {
            try? await Task.sleep(nanoseconds: delay)
            await completeConstruction(buildingId: buildingId)
        }
    }

    // MARK: - 完成建造

    func completeConstruction(buildingId: String) async {
        do {
            struct UpdatePayload: Encodable {
                let status: String
                let updated_at: String
            }
            let formatter = ISO8601DateFormatter()
            formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
            let payload = UpdatePayload(
                status: BuildingStatus.active.rawValue,
                updated_at: formatter.string(from: Date())
            )
            try await supabase
                .from("player_buildings")
                .update(payload)
                .eq("id", value: buildingId)
                .execute()

            if let idx = playerBuildings.firstIndex(where: { $0.id == buildingId }) {
                // 重新拉取单条以更新本地状态
                let updated: PlayerBuilding = try await supabase
                    .from("player_buildings")
                    .select()
                    .eq("id", value: buildingId)
                    .single()
                    .execute()
                    .value
                playerBuildings[idx] = updated
                buildingUpdateVersion += 1
            }
            logger.info("[Building] ✅ 建筑 \(buildingId) 建造完成")
        } catch {
            logger.error("[Building] 完成建造失败: \(error.localizedDescription)")
        }
    }

    // MARK: - 升级建筑

    func upgradeBuilding(buildingId: String) async throws {
        guard let building = playerBuildings.first(where: { $0.id == buildingId }) else {
            throw BuildingError.templateNotFound(templateId: buildingId)
        }
        guard building.status == .active else {
            throw BuildingError.invalidStatus(current: building.status, expected: .active)
        }
        guard let template = buildingTemplates.first(where: { $0.id == building.templateId }) else {
            throw BuildingError.templateNotFound(templateId: building.templateId)
        }
        guard building.level < template.maxLevel else {
            throw BuildingError.maxLevelReached(maxLevel: template.maxLevel)
        }

        isLoading = true
        defer { isLoading = false }

        struct UpdatePayload: Encodable {
            let level: Int
            let updated_at: String
        }
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        let payload = UpdatePayload(
            level: building.level + 1,
            updated_at: formatter.string(from: Date())
        )
        try await supabase
            .from("player_buildings")
            .update(payload)
            .eq("id", value: buildingId)
            .execute()

        if let idx = playerBuildings.firstIndex(where: { $0.id == buildingId }) {
            let updated: PlayerBuilding = try await supabase
                .from("player_buildings")
                .select()
                .eq("id", value: buildingId)
                .single()
                .execute()
                .value
            playerBuildings[idx] = updated
        }
        logger.info("[Building] ✅ 建筑 \(buildingId) 升级至 \(building.level + 1) 级")
    }

    // MARK: - 拆除建筑

    func demolishBuilding(buildingId: String) async throws {
        try await supabase
            .from("player_buildings")
            .delete()
            .eq("id", value: buildingId)
            .execute()
        playerBuildings.removeAll { $0.id == buildingId }
        buildingUpdateVersion += 1
        logger.info("[Building] 拆除建筑 \(buildingId)")
    }

    // MARK: - 拉取所有建筑（主地图用）

    func fetchAllPlayerBuildings() async {
        guard let userId = AuthManager.shared.currentUser?.id else { return }
        do {
            let all: [PlayerBuilding] = try await supabase
                .from("player_buildings")
                .select()
                .eq("user_id", value: userId.uuidString.lowercased())
                .execute()
                .value
            playerBuildings = all
            buildingUpdateVersion += 1
            logger.info("[Building] 拉取全部建筑 \(all.count) 栋")
        } catch {
            logger.error("[Building] 拉取全部建筑失败: \(error)")
        }
    }

    // MARK: - 模板字典（id → template）

    var templateDict: [String: BuildingTemplate] {
        Dictionary(uniqueKeysWithValues: buildingTemplates.map { ($0.id, $0) })
    }

    // MARK: - 拉取领地建筑列表

    func fetchPlayerBuildings(territoryId: String) async {
        guard AuthManager.shared.currentUser != nil else { return }

        isLoading = true
        defer { isLoading = false }

        do {
            let buildings: [PlayerBuilding] = try await supabase
                .from("player_buildings")
                .select()
                .eq("territory_id", value: territoryId)
                .order("created_at", ascending: false)
                .execute()
                .value

            playerBuildings = buildings
            buildingUpdateVersion += 1
            logger.info("[Building] 拉取到 \(buildings.count) 栋建筑（领地 \(territoryId)）")

            // 自动完成已过期的 constructing 建筑
            let now = Date()
            for building in buildings
            where building.status == .constructing &&
                  building.buildCompletedAt != nil &&
                  building.buildCompletedAt! <= now {
                await completeConstruction(buildingId: building.id)
            }
        } catch {
            logger.error("[Building] 拉取建筑失败: \(error.localizedDescription)")
            errorMessage = "加载建筑失败：\(error.localizedDescription)"
        }
    }
}
