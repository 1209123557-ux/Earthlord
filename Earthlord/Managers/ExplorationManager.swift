//
//  ExplorationManager.swift
//  Earthlord
//
//  负责探索模式下的 GPS 距离追踪和计时。
//  与 LocationManager（圈地）独立运行，使用自己的 CLLocationManager 实例。
//

import Foundation
import CoreLocation
import Combine

final class ExplorationManager: NSObject, ObservableObject {

    // MARK: - Published（供 UI 绑定）

    @Published private(set) var isExploring     = false
    @Published private(set) var totalDistanceM  = 0.0   // 累计行走距离（米）
    @Published private(set) var durationSeconds = 0     // 探索时长（秒）

    // MARK: - 私有

    private let clManager = CLLocationManager()
    private var timer:        Timer?
    private var lastLocation: CLLocation?
    private var lastLocationTime: Date?
    private var sessionId:    String?           // 当前 exploration_session 的 DB id（暂存）
    private var startTime:    Date?

    // GPS 过滤参数
    private let maxAccuracyM:   Double = 50     // 精度阈值，超过则丢弃
    private let maxJumpM:       Double = 100    // 单次跳变阈值，超过则丢弃
    private let minIntervalSec: Double = 1.0    // 最短采样间隔

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

        totalDistanceM  = 0
        durationSeconds = 0
        lastLocation    = nil
        lastLocationTime = nil
        startTime       = Date()
        isExploring     = true

        if clManager.authorizationStatus == .notDetermined {
            clManager.requestWhenInUseAuthorization()
        }
        clManager.startUpdatingLocation()

        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            self?.durationSeconds += 1
        }
    }

    /// 结束探索：停止 GPS 和计时器，返回结算数据
    @discardableResult
    func stopExploration() -> (distanceM: Int, durationSeconds: Int, startTime: Date) {
        guard isExploring else {
            return (0, 0, Date())
        }

        clManager.stopUpdatingLocation()
        timer?.invalidate()
        timer = nil
        isExploring = false

        let dist  = Int(totalDistanceM)
        let dur   = durationSeconds
        let start = startTime ?? Date()

        lastLocation     = nil
        lastLocationTime = nil

        return (dist, dur, start)
    }
}

// MARK: - CLLocationManagerDelegate

extension ExplorationManager: CLLocationManagerDelegate {

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard isExploring, let newLoc = locations.last else { return }

        let now = Date()

        // 1. 精度过滤
        guard newLoc.horizontalAccuracy <= maxAccuracyM,
              newLoc.horizontalAccuracy >= 0 else { return }

        // 2. 时间间隔过滤
        if let prevTime = lastLocationTime,
           now.timeIntervalSince(prevTime) < minIntervalSec { return }

        // 3. 跳变过滤
        if let prev = lastLocation {
            let delta = newLoc.distance(from: prev)
            guard delta <= maxJumpM else {
                // 跳变点只更新位置引用，不计入距离
                lastLocation     = newLoc
                lastLocationTime = now
                return
            }
            totalDistanceM += delta
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
        // 静默失败：距离追踪继续（用上一个有效点）
    }
}
