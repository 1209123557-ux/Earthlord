//
//  ExplorationManager.swift
//  Earthlord
//
//  负责探索模式下的 GPS 距离追踪、计时、速度限制检测，
//  以及 POI 搜索、地理围栏管理和搜刮弹窗状态。
//

import Foundation
import CoreLocation
import Combine
import OSLog

final class ExplorationManager: NSObject, ObservableObject {

    // MARK: - Published（供 UI 绑定）

    @Published private(set) var isExploring      = false
    @Published private(set) var totalDistanceM   = 0.0   // 累计行走距离（米）
    @Published private(set) var durationSeconds  = 0     // 探索时长（秒）
    @Published private(set) var locationCount    = 0     // 有效 GPS 点数量
    @Published private(set) var currentSpeedKmh  = 0.0  // 实时速度（km/h）

    // 强制终止标志（MapTabView 通过 onReceive 监听）
    @Published private(set) var explorationFailed = false

    // MARK: - POI 相关 Published

    /// 本次探索搜索到的附近 POI 列表
    @Published private(set) var nearbyPOIs: [GamePOI] = []
    /// 当前进入围栏的 POI（nil = 无弹窗）
    @Published private(set) var currentNearbyPOI: GamePOI? = nil
    /// 控制 POI 接近弹窗显示
    @Published private(set) var showPOIPopup: Bool = false
    /// 版本号：每次 POI 列表变化时自增，用于驱动地图刷新
    @Published private(set) var poiVersion: Int = 0

    // MARK: - 私有

    private let clManager = CLLocationManager()
    private var timer:        Timer?
    private var lastLocation: CLLocation?
    private var lastLocationTime: Date?
    private var startTime:    Date?

    // GPS 过滤参数
    private let maxAccuracyM:   Double = 50     // 精度阈值，超过则丢弃
    private let maxJumpM:       Double = 100    // 单次跳变阈值，超过则丢弃
    private let minIntervalSec: Double = 1.0    // 最短采样间隔

    // 速度限制：20 km/h = 5.555... m/s
    private let speedLimitMS: Double = 20_000.0 / 3_600.0

    // 日志
    private let logger = Logger(subsystem: "com.earthlord", category: "ExplorationManager")
    private var expLogger: ExplorationLogger { ExplorationLogger.shared }

    // MARK: - Init

    override init() {
        super.init()
        clManager.delegate          = self
        clManager.desiredAccuracy   = kCLLocationAccuracyNearestTenMeters
        clManager.distanceFilter    = 5
        clManager.activityType      = .fitness
        clManager.pausesLocationUpdatesAutomatically = false
    }

    // MARK: - 开始 / 结束

    /// from: 用于 POI 搜索的起始坐标（传 nil 则跳过 POI 搜索）
    func startExploration(from location: CLLocationCoordinate2D? = nil) {
        guard !isExploring else { return }

        totalDistanceM    = 0
        durationSeconds   = 0
        locationCount     = 0
        currentSpeedKmh   = 0
        explorationFailed = false
        lastLocation      = nil
        lastLocationTime  = nil
        startTime         = Date()
        isExploring       = true

        logger.info("[ExploreManager] 开始探索")
        expLogger.log("🚀 探索开始")

        if clManager.authorizationStatus == .notDetermined {
            clManager.requestWhenInUseAuthorization()
        }
        clManager.startUpdatingLocation()

        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            self?.durationSeconds += 1
        }

        // POI 搜索：在后台异步完成，结果回到主线程更新
        if let center = location {
            Task {
                expLogger.log("🔍 开始搜索附近 POI...")
                let pois = await POISearchManager.searchNearbyPOIs(center: center)
                // MainActor.run 确保 @Published 更新在主线程
                await MainActor.run {
                    self.nearbyPOIs = pois
                    self.poiVersion += 1
                    self.setupGeofences(for: pois)
                    self.expLogger.log("📍 已加载 \(pois.count) 个附近 POI", type: .success)
                }
            }
        }
    }

    @discardableResult
    func stopExploration() -> (distanceM: Int, durationSeconds: Int, startTime: Date) {
        guard isExploring else { return (0, 0, Date()) }

        clManager.stopUpdatingLocation()
        timer?.invalidate()
        timer           = nil
        isExploring     = false
        currentSpeedKmh = 0

        // 清理 POI 状态
        clearGeofences()
        nearbyPOIs       = []
        showPOIPopup     = false
        currentNearbyPOI = nil
        poiVersion      += 1

        let dist  = Int(totalDistanceM)
        let dur   = durationSeconds
        let start = startTime ?? Date()

        logger.info("[ExploreManager] 停止探索 dist=\(dist)m dur=\(dur)s")
        expLogger.log("🏁 最终距离: \(String(format: "%.2f", totalDistanceM)) 米")
        expLogger.log("⏱️ 探索时长: \(dur) 秒")
        expLogger.log("🔄 探索已停止，同步 UI 状态")

        lastLocation     = nil
        lastLocationTime = nil

        return (dist, dur, start)
    }

    func resetFailedState() {
        explorationFailed = false
    }

    // MARK: - POI 弹窗控制

    /// 关闭 POI 接近弹窗（用户点击"稍后再说"）
    func dismissPOIPopup() {
        showPOIPopup     = false
        currentNearbyPOI = nil
    }

    /// 标记 POI 已搜刮，更新地图标注
    func markPOILooted(_ poiId: String) {
        guard let idx = nearbyPOIs.firstIndex(where: { $0.id == poiId }) else { return }
        nearbyPOIs[idx].isLooted = true
        poiVersion += 1
    }

    // MARK: - 地理围栏

    private func setupGeofences(for pois: [GamePOI]) {
        for poi in pois {
            let region = CLCircularRegion(
                center:     poi.coordinate,
                radius:     50,
                identifier: "poi_\(poi.id)"
            )
            region.notifyOnEntry = true
            region.notifyOnExit  = false
            clManager.startMonitoring(for: region)
        }
        logger.info("[ExploreManager] 已设置 \(pois.count) 个地理围栏（50m）")
        expLogger.log("🔔 已为 \(pois.count) 个 POI 设置 50m 地理围栏")
    }

    private func clearGeofences() {
        let toRemove = clManager.monitoredRegions.filter { $0.identifier.hasPrefix("poi_") }
        toRemove.forEach { clManager.stopMonitoring(for: $0) }
        if !toRemove.isEmpty {
            logger.info("[ExploreManager] 已清除 \(toRemove.count) 个地理围栏")
        }
    }

    // MARK: - 超速立即终止

    private func forceStopDueToSpeed() {
        let speedStr = String(format: "%.1f", currentSpeedKmh)
        logger.error("[ExploreManager] 超速 \(speedStr)km/h，立即终止探索")
        expLogger.log("🚫 超速 \(speedStr)km/h，探索已自动停止", type: .error)

        clManager.stopUpdatingLocation()
        clearGeofences()
        timer?.invalidate()
        timer           = nil
        isExploring     = false
        currentSpeedKmh = 0
        explorationFailed = true
    }
}

// MARK: - CLLocationManagerDelegate

extension ExplorationManager: CLLocationManagerDelegate {

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard isExploring, let newLoc = locations.last else { return }

        let now = Date()

        // 1. 精度过滤
        guard newLoc.horizontalAccuracy <= maxAccuracyM,
              newLoc.horizontalAccuracy >= 0 else {
            logger.debug("[ExploreManager] 精度不足 acc=\(newLoc.horizontalAccuracy, format: .fixed(precision: 1))m，丢弃")
            return
        }

        // 2. 时间间隔过滤
        if let prevTime = lastLocationTime,
           now.timeIntervalSince(prevTime) < minIntervalSec { return }

        // 3. 实时速度更新（不依赖位移计算，直接读 CLLocation.speed）
        if newLoc.speed >= 0 {
            currentSpeedKmh = newLoc.speed * 3.6
        }

        // 4. 跳变过滤
        if let prev = lastLocation {
            let delta = newLoc.distance(from: prev)

            guard delta <= maxJumpM else {
                logger.debug("[ExploreManager] 跳变点 delta=\(delta, format: .fixed(precision: 1))m，跳过")
                lastLocation     = newLoc
                lastLocationTime = now
                return
            }

            // 5. 速度超限检测 → 立即停止
            if newLoc.speed >= 0 && newLoc.speed > speedLimitMS {
                logger.warning("[ExploreManager] 超速 \(self.currentSpeedKmh, format: .fixed(precision: 1))km/h，立即终止")
                forceStopDueToSpeed()
                return
            }

            // 6. 累加距离
            totalDistanceM += delta
            locationCount  += 1

            let kmhStr    = String(format: "%.1f", currentSpeedKmh)
            let totalStr  = String(format: "%.0f", totalDistanceM)
            logger.debug("[ExploreManager] acc=\(newLoc.horizontalAccuracy, format: .fixed(precision: 1))m speed=\(kmhStr)km/h delta=\(delta, format: .fixed(precision: 1))m total=\(totalStr)m")

            if locationCount % 10 == 0 {
                expLogger.log("📍 GPS #\(locationCount)  累计 \(totalStr)m  速度 \(kmhStr)km/h")
            }
        }

        lastLocation     = newLoc
        lastLocationTime = now
    }

    // MARK: 地理围栏进入事件

    func locationManager(_ manager: CLLocationManager, didEnterRegion region: CLRegion) {
        guard isExploring, region.identifier.hasPrefix("poi_") else { return }

        guard let poi = nearbyPOIs.first(where: { "poi_\($0.id)" == region.identifier }),
              !poi.isLooted else { return }

        DispatchQueue.main.async { [weak self] in
            self?.currentNearbyPOI = poi
            self?.showPOIPopup     = true
        }
        logger.info("[ExploreManager] 进入 POI 围栏: \(poi.name)")
        expLogger.log("🏪 进入 POI 范围: \(poi.name)（50m 内）")
    }

    func locationManager(_ manager: CLLocationManager, monitoringDidFailFor region: CLRegion?, withError error: Error) {
        logger.warning("[ExploreManager] 围栏监控失败: \(error.localizedDescription)")
    }

    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        if isExploring,
           manager.authorizationStatus == .authorizedWhenInUse ||
           manager.authorizationStatus == .authorizedAlways {
            manager.startUpdatingLocation()
        }
    }

    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        logger.error("[ExploreManager] GPS 错误: \(error.localizedDescription)")
        expLogger.log("❌ GPS 错误: \(error.localizedDescription)", type: .error)
    }
}
