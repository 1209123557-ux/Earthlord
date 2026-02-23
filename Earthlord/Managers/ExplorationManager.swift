//
//  ExplorationManager.swift
//  Earthlord
//
//  负责探索模式下的 GPS 距离追踪、计时、速度限制检测，
//  以及 POI 搜索、手动距离检测和搜刮弹窗状态。
//
//  ⚠️ POI 接近检测采用手动距离计算而非地理围栏，原因：
//  1. MKLocalSearch 在中国返回 GCJ-02 坐标，CLCircularRegion 按 WGS-84 解析，
//     导致围栏中心偏移 100-500m，触发不准确。
//  2. 地理围栏不触发"已在范围内"时的 didEnterRegion，而是 didDetermineState(.inside)。
//  手动方案：每次 GPS 更新时将设备坐标转换为 GCJ-02，再与 POI 坐标（GCJ-02）比距离。
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
    /// 当前触发弹窗的 POI（nil = 无弹窗）
    @Published private(set) var currentNearbyPOI: GamePOI? = nil
    /// 控制 POI 接近弹窗显示
    @Published private(set) var showPOIPopup: Bool = false
    /// 当前接近 POI 的距离（米），用于弹窗显示
    @Published private(set) var currentNearbyPOIDistanceM: Double = 0
    /// 版本号：每次 POI 列表变化时自增，用于驱动地图刷新
    @Published private(set) var poiVersion: Int = 0

    // MARK: - 私有

    private let clManager = CLLocationManager()
    private var timer:        Timer?
    private var lastLocation: CLLocation?
    private var lastLocationTime: Date?
    private var startTime:    Date?

    /// 本次探索中已触发过弹窗的 POI id（避免重复弹出）
    private var triggeredPOIIds: Set<String> = []

    // GPS 过滤参数
    private let maxAccuracyM:   Double = 50
    private let maxJumpM:       Double = 100
    private let minIntervalSec: Double = 1.0

    // 速度限制：20 km/h = 5.555... m/s
    private let speedLimitMS: Double = 20_000.0 / 3_600.0

    // POI 触发半径（米）
    private let poiTriggerRadiusM: Double = 50

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
        triggeredPOIIds   = []

        logger.info("[ExploreManager] 开始探索")
        expLogger.log("🚀 探索开始")

        if clManager.authorizationStatus == .notDetermined {
            clManager.requestWhenInUseAuthorization()
        }
        clManager.startUpdatingLocation()

        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            self?.durationSeconds += 1
        }

        // POI 搜索：异步完成后回到主线程更新列表
        if let center = location {
            Task {
                expLogger.log("🔍 开始搜索附近 POI...")
                let pois = await POISearchManager.searchNearbyPOIs(center: center)
                await MainActor.run {
                    self.nearbyPOIs = pois
                    self.poiVersion += 1
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
        nearbyPOIs              = []
        showPOIPopup            = false
        currentNearbyPOI        = nil
        currentNearbyPOIDistanceM = 0
        triggeredPOIIds         = []
        poiVersion             += 1

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
        currentNearbyPOIDistanceM = 0
    }

    /// 标记 POI 已搜刮，更新地图标注
    func markPOILooted(_ poiId: String) {
        guard let idx = nearbyPOIs.firstIndex(where: { $0.id == poiId }) else { return }
        nearbyPOIs[idx].isLooted = true
        poiVersion += 1
    }

    // MARK: - POI 接近检测（手动距离计算）

    /// 在每次有效 GPS 更新后调用，检测是否进入任何 POI 的触发半径。
    ///
    /// **坐标处理**：
    /// MKLocalSearch 在中国返回 GCJ-02 坐标（与地图显示对齐），
    /// 设备 GPS 返回 WGS-84，需先转换为 GCJ-02 再比较距离，
    /// 否则偏差可达 100-500m 导致触发失败。
    private func checkPOIProximity(from rawLocation: CLLocation) {
        guard !nearbyPOIs.isEmpty, !showPOIPopup else { return }

        // 将 GPS(WGS-84) 转换为 GCJ-02，与 POI 坐标系对齐
        let gcj02 = CoordinateConverter.wgs84ToGcj02(rawLocation.coordinate)
        let gcj02Loc = CLLocation(latitude: gcj02.latitude, longitude: gcj02.longitude)

        for poi in nearbyPOIs where !poi.isLooted && !triggeredPOIIds.contains(poi.id) {
            let poiLoc = CLLocation(latitude: poi.coordinate.latitude,
                                    longitude: poi.coordinate.longitude)
            let dist = gcj02Loc.distance(from: poiLoc)

            if dist <= poiTriggerRadiusM {
                triggeredPOIIds.insert(poi.id)
                let distInt = Int(dist)
                logger.info("[ExploreManager] 距 '\(poi.name)' 仅 \(distInt)m，触发搜刮弹窗")
                expLogger.log("🏪 进入 POI 范围: \(poi.name)（距离 \(distInt)m）")

                DispatchQueue.main.async { [weak self] in
                    self?.currentNearbyPOI        = poi
                    self?.currentNearbyPOIDistanceM = dist
                    self?.showPOIPopup             = true
                }
                break  // 每次只弹一个
            }
        }
    }

    // MARK: - 超速立即终止

    private func forceStopDueToSpeed() {
        let speedStr = String(format: "%.1f", currentSpeedKmh)
        logger.error("[ExploreManager] 超速 \(speedStr)km/h，立即终止探索")
        expLogger.log("🚫 超速 \(speedStr)km/h，探索已自动停止", type: .error)

        clManager.stopUpdatingLocation()
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

        // 3. 实时速度更新
        if newLoc.speed >= 0 {
            currentSpeedKmh = newLoc.speed * 3.6
        }

        // 4. POI 接近检测（每次有效位置都检查）
        checkPOIProximity(from: newLoc)

        // 5. 跳变过滤
        if let prev = lastLocation {
            let delta = newLoc.distance(from: prev)

            guard delta <= maxJumpM else {
                logger.debug("[ExploreManager] 跳变点 delta=\(delta, format: .fixed(precision: 1))m，跳过")
                lastLocation     = newLoc
                lastLocationTime = now
                return
            }

            // 6. 速度超限检测 → 立即停止
            if newLoc.speed >= 0 && newLoc.speed > speedLimitMS {
                logger.warning("[ExploreManager] 超速 \(self.currentSpeedKmh, format: .fixed(precision: 1))km/h，立即终止")
                forceStopDueToSpeed()
                return
            }

            // 7. 累加距离
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
