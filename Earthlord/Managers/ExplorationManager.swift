//
//  ExplorationManager.swift
//  Earthlord
//
//  负责探索模式下的 GPS 距离追踪、计时和速度限制检测。
//  与 LocationManager（圈地）独立运行，使用自己的 CLLocationManager 实例。
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

    func startExploration() {
        guard !isExploring else { return }

        totalDistanceM   = 0
        durationSeconds  = 0
        locationCount    = 0
        currentSpeedKmh  = 0
        explorationFailed = false
        lastLocation     = nil
        lastLocationTime = nil
        startTime        = Date()
        isExploring      = true

        logger.info("[ExploreManager] 开始探索")
        expLogger.log("🚀 探索开始")

        if clManager.authorizationStatus == .notDetermined {
            clManager.requestWhenInUseAuthorization()
        }
        clManager.startUpdatingLocation()

        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            self?.durationSeconds += 1
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
