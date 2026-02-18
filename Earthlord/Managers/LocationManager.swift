//
//  LocationManager.swift
//  Earthlord
//
//  GPS 定位管理器 - 负责请求定位权限和获取用户位置
//

import Foundation
import CoreLocation
import Combine  // ⚠️ @Published 需要这个框架

// MARK: - LocationManager
/// GPS 定位管理器，负责处理定位权限和位置更新
class LocationManager: NSObject, ObservableObject {
    // MARK: - Published Properties
    /// 用户当前位置（经纬度）
    @Published var userLocation: CLLocationCoordinate2D?

    /// 定位授权状态
    @Published var authorizationStatus: CLAuthorizationStatus = .notDetermined

    /// 错误信息
    @Published var locationError: String?

    /// 是否正在追踪路径
    @Published var isTracking: Bool = false

    /// 路径坐标数组（存储原始 WGS-84 坐标）
    @Published var pathCoordinates: [CLLocationCoordinate2D] = []

    /// 路径更新版本号（触发 SwiftUI 更新）
    @Published var pathUpdateVersion: Int = 0

    /// 路径是否闭合
    @Published var isPathClosed: Bool = false

    /// 速度警告信息
    @Published var speedWarning: String?

    /// 是否超速
    @Published var isOverSpeed: Bool = false

    // MARK: - Private Properties
    private let locationManager = CLLocationManager()

    /// 当前位置（用于 Timer 采点）
    private var currentLocation: CLLocation?

    /// 路径采点定时器
    private var pathUpdateTimer: Timer?

    /// 上次位置的时间戳（用于速度检测）
    private var lastLocationTimestamp: Date?

    // MARK: - 验证状态属性
    /// 领地验证是否通过
    @Published var territoryValidationPassed: Bool = false
    /// 领地验证错误信息
    @Published var territoryValidationError: String? = nil
    /// 计算得到的领地面积（平方米）
    @Published var calculatedArea: Double = 0
    /// 手动停止时触发验证的信号（通知 UI 显示横幅）
    @Published var manualValidationTriggered: Bool = false

    // MARK: - Constants
    /// 闭环距离阈值（米）
    private let closureDistanceThreshold: Double = 30.0

    /// 最少路径点数
    private let minimumPathPoints: Int = 10

    /// 最小行走距离（米）
    private let minimumTotalDistance: Double = 50.0

    /// 最小领地面积（平方米）
    private let minimumEnclosedArea: Double = 100.0

    /// 记录新点的最小距离（米）
    private let minimumDistanceForNewPoint: Double = 10.0

    // MARK: - Computed Properties
    /// 是否已授权定位
    var isAuthorized: Bool {
        switch authorizationStatus {
        case .authorizedWhenInUse, .authorizedAlways:
            return true
        default:
            return false
        }
    }

    /// 是否被拒绝授权
    var isDenied: Bool {
        authorizationStatus == .denied || authorizationStatus == .restricted
    }

    // MARK: - Initialization
    override init() {
        super.init()

        // 配置定位管理器
        locationManager.delegate = self
        locationManager.desiredAccuracy = kCLLocationAccuracyBest  // 最高精度
        locationManager.distanceFilter = 10  // 移动 10 米才更新位置

        // 获取当前授权状态
        authorizationStatus = locationManager.authorizationStatus
    }

    // MARK: - Public Methods
    /// 请求定位权限（使用 App 期间）
    func requestPermission() {
        locationManager.requestWhenInUseAuthorization()
    }

    /// 开始更新位置
    func startUpdatingLocation() {
        guard isAuthorized else {
            locationError = "未获得定位权限"
            return
        }

        locationManager.startUpdatingLocation()
    }

    /// 停止更新位置
    func stopUpdatingLocation() {
        locationManager.stopUpdatingLocation()
    }

    // MARK: - Path Tracking Methods

    /// 开始路径追踪
    func startPathTracking() {
        guard isAuthorized else {
            locationError = "未获得定位权限"
            return
        }

        isTracking = true
        pathCoordinates.removeAll()
        pathUpdateVersion = 0
        isPathClosed = false
        speedWarning = nil
        isOverSpeed = false
        territoryValidationPassed = false
        territoryValidationError = nil
        calculatedArea = 0
        manualValidationTriggered = false

        TerritoryLogger.shared.log("开始圈地追踪", type: .info)

        // 启动 2 秒定时器，定期采点
        pathUpdateTimer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: true) { [weak self] _ in
            self?.recordPathPoint()
        }
    }

    /// 停止路径追踪
    func stopPathTracking() {
        isTracking = false
        pathUpdateTimer?.invalidate()
        pathUpdateTimer = nil

        TerritoryLogger.shared.log("停止追踪，共 \(pathCoordinates.count) 个点", type: .info)

        // 如果闭环检测未触发（点数不足等），手动停止时也执行验证给用户反馈
        if !isPathClosed && !pathCoordinates.isEmpty {
            let result = validateTerritory()
            territoryValidationPassed = result.isValid
            territoryValidationError = result.errorMessage
            // 标记需要显示横幅（通过 manualValidationTriggered 通知 UI）
            manualValidationTriggered = true
        }
    }

    /// 清除路径
    func clearPath() {
        pathCoordinates.removeAll()
        pathUpdateVersion = 0
        isPathClosed = false
    }

    /// 记录路径点（定时器回调）
    /// ⚠️ 关键：先检查距离，再检查速度！顺序不能反！
    private func recordPathPoint() {
        guard isTracking, let location = currentLocation else { return }

        // 如果是第一个点，直接添加
        if pathCoordinates.isEmpty {
            pathCoordinates.append(location.coordinate)
            pathUpdateVersion += 1
            lastLocationTimestamp = location.timestamp
            return
        }

        // 步骤1：先检查距离（过滤 GPS 漂移，距离不够就直接返回）
        guard let lastCoordinate = pathCoordinates.last else { return }
        let lastLocation = CLLocation(latitude: lastCoordinate.latitude, longitude: lastCoordinate.longitude)
        let distance = location.distance(from: lastLocation)

        guard distance > minimumDistanceForNewPoint else {
            return  // 距离不够，不进行速度检测，直接返回
        }

        // 步骤2：再检查速度（只对真实移动进行检测）
        guard validateMovementSpeed(newLocation: location) else {
            return  // 严重超速，不记录
        }

        // 步骤3：记录新点
        pathCoordinates.append(location.coordinate)
        pathUpdateVersion += 1
        lastLocationTimestamp = location.timestamp

        let count = pathCoordinates.count
        let distanceStr = String(format: "%.1f", distance)
        TerritoryLogger.shared.log("记录第 \(count) 个点，距上点 \(distanceStr)m", type: .info)

        // 步骤4：检测闭环
        checkPathClosure()
    }

    /// 检测路径是否闭环
    private func checkPathClosure() {
        // ⚠️ 已闭环则不再重复检测
        guard !isPathClosed else { return }

        // 检查点数是否足够
        guard pathCoordinates.count >= minimumPathPoints else {
            print("闭环检测：点数不足（当前 \(pathCoordinates.count)，需要 \(minimumPathPoints)）")
            return
        }

        // 获取起点和终点
        guard let startCoordinate = pathCoordinates.first,
              let endCoordinate = pathCoordinates.last else { return }

        // 计算距离
        let startLocation = CLLocation(latitude: startCoordinate.latitude, longitude: startCoordinate.longitude)
        let endLocation = CLLocation(latitude: endCoordinate.latitude, longitude: endCoordinate.longitude)
        let distance = endLocation.distance(from: startLocation)
        let distanceStr = String(format: "%.1f", distance)

        // 判断是否闭环
        if distance <= closureDistanceThreshold {
            isPathClosed = true
            print("✅ 闭环检测成功：距离起点 \(distanceStr) 米")
            TerritoryLogger.shared.log("闭环成功！距起点 \(distanceStr)m", type: .success)

            // 闭环成功后自动触发领地验证
            let result = validateTerritory()
            territoryValidationPassed = result.isValid
            territoryValidationError = result.errorMessage
        } else {
            print("闭环检测：距离起点 \(distanceStr) 米（需要 ≤ \(closureDistanceThreshold) 米）")
            TerritoryLogger.shared.log("距起点 \(distanceStr)m（需≤30m）", type: .info)
        }
    }

    /// 验证移动速度
    /// - Parameter newLocation: 新位置
    /// - Returns: true=可以记录该点，false=不记录
    private func validateMovementSpeed(newLocation: CLLocation) -> Bool {
        // 如果没有上次的时间戳，说明是第二个点，直接通过
        guard let lastTimestamp = lastLocationTimestamp,
              let lastCoordinate = pathCoordinates.last else {
            return true
        }

        // 计算时间差（秒）
        let timeInterval = newLocation.timestamp.timeIntervalSince(lastTimestamp)
        guard timeInterval > 0 else { return true }

        // 计算距离（米）
        let lastLocation = CLLocation(latitude: lastCoordinate.latitude, longitude: lastCoordinate.longitude)
        let distance = newLocation.distance(from: lastLocation)

        // 计算速度（km/h）
        let speedKmh = (distance / timeInterval) * 3.6

        // 清除旧的警告
        if speedKmh <= 15 {
            speedWarning = nil
            isOverSpeed = false
        }

        let speedStr = String(format: "%.1f", speedKmh)

        // 速度检测
        if speedKmh > 30 {
            // 严重超速：停止追踪
            speedWarning = "移动速度过快（\(speedStr) km/h），已停止圈地"
            isOverSpeed = true
            TerritoryLogger.shared.log("超速 \(speedStr) km/h，已停止追踪", type: .error)
            stopPathTracking()
            print("❌ 速度检测：\(speedStr) km/h，超过 30 km/h，停止追踪")
            return false
        } else if speedKmh > 15 {
            // 轻微超速：警告但继续记录
            speedWarning = "移动速度过快（\(speedStr) km/h），请放慢速度"
            isOverSpeed = true
            TerritoryLogger.shared.log("速度较快 \(speedStr) km/h", type: .warning)
            print("⚠️ 速度检测：\(speedStr) km/h，超过 15 km/h，发出警告")
            return true
        }

        // 正常速度（不记录日志，避免日志过多）
        print("✅ 速度检测：\(speedStr) km/h，正常")
        return true
    }
    // MARK: - 距离与面积计算

    /// 计算路径总距离（米）
    private func calculateTotalPathDistance() -> Double {
        var totalDistance: Double = 0
        for i in 0..<pathCoordinates.count - 1 {
            let current = CLLocation(latitude: pathCoordinates[i].latitude, longitude: pathCoordinates[i].longitude)
            let next = CLLocation(latitude: pathCoordinates[i + 1].latitude, longitude: pathCoordinates[i + 1].longitude)
            totalDistance += next.distance(from: current)
        }
        return totalDistance
    }

    /// 使用鞋带公式计算多边形面积（平方米，考虑地球曲率）
    private func calculatePolygonArea() -> Double {
        guard pathCoordinates.count >= 3 else { return 0 }

        let earthRadius: Double = 6371000  // 地球半径（米）
        var area: Double = 0

        for i in 0..<pathCoordinates.count {
            let current = pathCoordinates[i]
            let next = pathCoordinates[(i + 1) % pathCoordinates.count]  // 循环取点

            // 经纬度转弧度
            let lat1 = current.latitude * .pi / 180
            let lon1 = current.longitude * .pi / 180
            let lat2 = next.latitude * .pi / 180
            let lon2 = next.longitude * .pi / 180

            // 鞋带公式（球面修正）
            area += (lon2 - lon1) * (2 + sin(lat1) + sin(lat2))
        }

        area = abs(area * earthRadius * earthRadius / 2.0)
        return area
    }

    // MARK: - 自相交检测

    /// CCW 算法：判断两线段是否相交
    /// - Parameters: p1, p2 为第一条线段端点；p3, p4 为第二条线段端点
    /// - Returns: true = 两线段相交
    private func segmentsIntersect(p1: CLLocationCoordinate2D, p2: CLLocationCoordinate2D,
                                   p3: CLLocationCoordinate2D, p4: CLLocationCoordinate2D) -> Bool {
        // CCW 辅助函数：判断三点是否逆时针排列
        // ⚠️ 坐标映射：longitude = X轴，latitude = Y轴
        func ccw(_ A: CLLocationCoordinate2D, _ B: CLLocationCoordinate2D, _ C: CLLocationCoordinate2D) -> Bool {
            let crossProduct = (C.latitude - A.latitude) * (B.longitude - A.longitude) -
                               (B.latitude - A.latitude) * (C.longitude - A.longitude)
            return crossProduct > 0
        }

        // 两线段相交的充要条件：
        // ccw(p1, p3, p4) ≠ ccw(p2, p3, p4) 且 ccw(p1, p2, p3) ≠ ccw(p1, p2, p4)
        return ccw(p1, p3, p4) != ccw(p2, p3, p4) && ccw(p1, p2, p3) != ccw(p1, p2, p4)
    }

    /// 检测整条路径是否自相交（画"8"字形则返回 true）
    func hasPathSelfIntersection() -> Bool {
        // ✅ 防御性检查：至少需要4个点才可能自交
        guard pathCoordinates.count >= 4 else { return false }

        // ✅ 创建路径快照的深拷贝，避免并发修改问题
        let pathSnapshot = Array(pathCoordinates)

        // ✅ 再次检查快照是否有效
        guard pathSnapshot.count >= 4 else { return false }

        let segmentCount = pathSnapshot.count - 1

        // ✅ 防御性检查：确保有足够的线段
        guard segmentCount >= 2 else { return false }

        // ✅ 闭环时需要跳过的首尾线段数量（防止正常圈地被误判为自交）
        let skipHeadCount = 2
        let skipTailCount = 2

        for i in 0..<segmentCount {
            guard i < pathSnapshot.count - 1 else { break }
            let p1 = pathSnapshot[i]
            let p2 = pathSnapshot[i + 1]

            let startJ = i + 2
            guard startJ < segmentCount else { continue }

            for j in startJ..<segmentCount {
                guard j < pathSnapshot.count - 1 else { break }

                // ✅ 跳过首尾附近线段的比较
                let isHeadSegment = i < skipHeadCount
                let isTailSegment = j >= segmentCount - skipTailCount
                if isHeadSegment && isTailSegment {
                    continue
                }

                let p3 = pathSnapshot[j]
                let p4 = pathSnapshot[j + 1]

                if segmentsIntersect(p1: p1, p2: p2, p3: p3, p4: p4) {
                    TerritoryLogger.shared.log("自交检测: 线段\(i)-\(i+1) 与 线段\(j)-\(j+1) 相交", type: .error)
                    return true
                }
            }
        }

        TerritoryLogger.shared.log("自交检测: 无交叉 ✓", type: .info)
        return false
    }

    // MARK: - 综合验证

    /// 综合验证领地是否有效
    /// - Returns: (isValid: 是否通过, errorMessage: 失败原因)
    func validateTerritory() -> (isValid: Bool, errorMessage: String?) {
        TerritoryLogger.shared.log("开始领地验证", type: .info)

        // 1. 点数检查
        let pointCount = pathCoordinates.count
        if pointCount < minimumPathPoints {
            let msg = "点数不足: \(pointCount)个 (需≥\(minimumPathPoints)个)"
            TerritoryLogger.shared.log("点数检查: \(pointCount)个 ✗", type: .error)
            TerritoryLogger.shared.log("领地验证失败：\(msg)", type: .error)
            return (false, msg)
        }
        TerritoryLogger.shared.log("点数检查: \(pointCount)个点 ✓", type: .info)

        // 2. 距离检查
        let totalDistance = calculateTotalPathDistance()
        let distanceStr = String(format: "%.0f", totalDistance)
        if totalDistance < minimumTotalDistance {
            let msg = "距离不足: \(distanceStr)m (需≥\(Int(minimumTotalDistance))m)"
            TerritoryLogger.shared.log("距离检查: \(distanceStr)m ✗", type: .error)
            TerritoryLogger.shared.log("领地验证失败：\(msg)", type: .error)
            return (false, msg)
        }
        TerritoryLogger.shared.log("距离检查: \(distanceStr)m ✓", type: .info)

        // 3. 自交检测
        if hasPathSelfIntersection() {
            let msg = "轨迹自相交，请勿画8字形"
            TerritoryLogger.shared.log("领地验证失败：\(msg)", type: .error)
            return (false, msg)
        }

        // 4. 面积检查
        let area = calculatePolygonArea()
        calculatedArea = area
        let areaStr = String(format: "%.0f", area)
        if area < minimumEnclosedArea {
            let msg = "面积不足: \(areaStr)m² (需≥\(Int(minimumEnclosedArea))m²)"
            TerritoryLogger.shared.log("面积检查: \(areaStr)m² ✗", type: .error)
            TerritoryLogger.shared.log("领地验证失败：\(msg)", type: .error)
            return (false, msg)
        }
        TerritoryLogger.shared.log("面积检查: \(areaStr)m² ✓", type: .info)

        TerritoryLogger.shared.log("领地验证通过！面积: \(areaStr)m²", type: .success)
        return (true, nil)
    }
}

// MARK: - CLLocationManagerDelegate
extension LocationManager: CLLocationManagerDelegate {
    /// 授权状态改变时调用
    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        authorizationStatus = manager.authorizationStatus

        // 如果已授权，自动开始定位
        if isAuthorized {
            startUpdatingLocation()
        }
    }

    /// 位置更新时调用
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.last else { return }

        // ⭐ 更新当前位置（Timer 需要用这个）
        self.currentLocation = location

        // 更新用户位置
        DispatchQueue.main.async {
            self.userLocation = location.coordinate
            self.locationError = nil
        }
    }

    /// 定位失败时调用
    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        DispatchQueue.main.async {
            self.locationError = "定位失败: \(error.localizedDescription)"
        }
    }
}
