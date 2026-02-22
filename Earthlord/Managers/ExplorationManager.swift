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

    @Published private(set) var isExploring           = false
    @Published private(set) var totalDistanceM        = 0.0   // 累计行走距离（米）
    @Published private(set) var durationSeconds       = 0     // 探索时长（秒）
    @Published private(set) var locationCount         = 0     // 有效 GPS 点数量

    // 速度超限状态
    @Published private(set) var isSpeedViolation       = false
    @Published private(set) var speedViolationCountdown = 0   // 10 → 0（秒）

    // 强制终止标志（MapTabView 通过 onReceive 监听）
    @Published private(set) var explorationFailed      = false

    // MARK: - 私有

    private let clManager = CLLocationManager()
    private var timer:               Timer?
    private var speedViolationTimer: Timer?
    private var lastLocation:        CLLocation?
    private var lastLocationTime:    Date?
    private var startTime:           Date?

    // GPS 过滤参数
    private let maxAccuracyM:   Double = 50     // 精度阈值，超过则丢弃
    private let maxJumpM:       Double = 100    // 单次跳变阈值，超过则丢弃
    private let minIntervalSec: Double = 1.0    // 最短采样间隔

    // 速度限制：30 km/h = 8.333... m/s
    private let speedLimitMS: Double = 30_000.0 / 3_600.0

    // 日志
    private let logger = Logger(subsystem: "com.earthlord", category: "ExplorationManager")

    // MARK: - Init

    override init() {
        super.init()
        clManager.delegate          = self
        clManager.desiredAccuracy   = kCLLocationAccuracyNearestTenMeters
        clManager.distanceFilter    = 5          // 5m 以上才触发回调，减少噪点
        clManager.activityType      = .fitness
        clManager.pausesLocationUpdatesAutomatically = false
    }

    // MARK: - 开始 / 结束

    /// 开始探索：启动 GPS 和每秒计时器
    func startExploration() {
        guard !isExploring else { return }

        totalDistanceM          = 0
        durationSeconds         = 0
        locationCount           = 0
        isSpeedViolation        = false
        speedViolationCountdown = 0
        explorationFailed       = false
        lastLocation            = nil
        lastLocationTime        = nil
        startTime               = Date()
        isExploring             = true

        logger.info("[ExploreManager] 开始探索")

        if clManager.authorizationStatus == .notDetermined {
            clManager.requestWhenInUseAuthorization()
        }
        clManager.startUpdatingLocation()

        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            self?.durationSeconds += 1
        }
    }

    /// 结束探索（用户手动）：停止 GPS 和计时器，返回结算数据
    @discardableResult
    func stopExploration() -> (distanceM: Int, durationSeconds: Int, startTime: Date) {
        guard isExploring else {
            return (0, 0, Date())
        }

        clManager.stopUpdatingLocation()
        timer?.invalidate()
        timer = nil

        // 清理速度违规计时器
        speedViolationTimer?.invalidate()
        speedViolationTimer     = nil
        isSpeedViolation        = false
        speedViolationCountdown = 0

        isExploring = false

        let dist  = Int(totalDistanceM)
        let dur   = durationSeconds
        let start = startTime ?? Date()

        logger.info("[ExploreManager] 停止探索 dist=\(dist)m dur=\(dur)s")

        lastLocation     = nil
        lastLocationTime = nil

        return (dist, dur, start)
    }

    /// 重置失败标志（MapTabView 处理完后调用）
    func resetFailedState() {
        explorationFailed = false
    }

    // MARK: - 速度超限强制终止

    private func forceStopDueToSpeed() {
        logger.error("[ExploreManager] 速度超限 10s，强制终止探索")

        speedViolationTimer?.invalidate()
        speedViolationTimer = nil

        clManager.stopUpdatingLocation()
        timer?.invalidate()
        timer = nil

        isExploring             = false
        isSpeedViolation        = false
        speedViolationCountdown = 0
        explorationFailed       = true   // 触发 MapTabView 监听
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

        // 3. 跳变过滤 + 速度检测
        if let prev = lastLocation {
            let delta = newLoc.distance(from: prev)

            // 跳变过滤
            guard delta <= maxJumpM else {
                logger.debug("[ExploreManager] 跳变点 delta=\(delta, format: .fixed(precision: 1))m，更新引用但不计距")
                lastLocation     = newLoc
                lastLocationTime = now
                return
            }

            // 4. 速度检测（speed < 0 表示无效）
            if newLoc.speed >= 0 {
                let kmh = newLoc.speed * 3.6
                logger.debug("[ExploreManager] 位置更新 acc=\(newLoc.horizontalAccuracy, format: .fixed(precision: 1))m speed=\(kmh, format: .fixed(precision: 1))km/h delta=\(delta, format: .fixed(precision: 1))m total=\(self.totalDistanceM, format: .fixed(precision: 1))m")

                if newLoc.speed > speedLimitMS {
                    // 超速
                    if !isSpeedViolation {
                        logger.warning("[ExploreManager] 速度超限 \(kmh, format: .fixed(precision: 1))km/h，开始 10s 倒计时")
                        isSpeedViolation        = true
                        speedViolationCountdown = 10
                        speedViolationTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
                            guard let self else { return }
                            self.speedViolationCountdown -= 1
                            self.logger.warning("[ExploreManager] 超速倒计时 \(self.speedViolationCountdown)s")
                            if self.speedViolationCountdown <= 0 {
                                self.forceStopDueToSpeed()
                            }
                        }
                    }
                    // 超速期间跳过距离累加
                    lastLocation     = newLoc
                    lastLocationTime = now
                    return
                } else if isSpeedViolation {
                    // 速度恢复
                    logger.info("[ExploreManager] 速度恢复正常 \(kmh, format: .fixed(precision: 1))km/h，取消倒计时")
                    speedViolationTimer?.invalidate()
                    speedViolationTimer     = nil
                    isSpeedViolation        = false
                    speedViolationCountdown = 0
                }
            } else {
                logger.debug("[ExploreManager] 位置更新（speed 无效）acc=\(newLoc.horizontalAccuracy, format: .fixed(precision: 1))m delta=\(delta, format: .fixed(precision: 1))m")
            }

            // 5. 累加距离 + GPS点计数
            totalDistanceM += delta
            locationCount  += 1
        }

        lastLocation     = newLoc
        lastLocationTime = now
    }

    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        if isExploring, manager.authorizationStatus == .authorizedWhenInUse
            || manager.authorizationStatus == .authorizedAlways {
            manager.startUpdatingLocation()
        }
    }

    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        logger.error("[ExploreManager] CLLocationManager 错误: \(error.localizedDescription)")
    }
}
