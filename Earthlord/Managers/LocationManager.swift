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

    /// 路径是否闭合（Day16 会用到）
    @Published var isPathClosed: Bool = false

    // MARK: - Private Properties
    private let locationManager = CLLocationManager()

    /// 当前位置（用于 Timer 采点）
    private var currentLocation: CLLocation?

    /// 路径采点定时器
    private var pathUpdateTimer: Timer?

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
    }

    /// 清除路径
    func clearPath() {
        pathCoordinates.removeAll()
        pathUpdateVersion = 0
        isPathClosed = false
    }

    /// 记录路径点（定时器回调）
    private func recordPathPoint() {
        guard let location = currentLocation else { return }

        // 如果是第一个点，直接添加
        if pathCoordinates.isEmpty {
            pathCoordinates.append(location.coordinate)
            pathUpdateVersion += 1
            return
        }

        // 检查距离上个点是否超过 10 米
        guard let lastCoordinate = pathCoordinates.last else { return }
        let lastLocation = CLLocation(latitude: lastCoordinate.latitude, longitude: lastCoordinate.longitude)
        let distance = location.distance(from: lastLocation)

        // 距离超过 10 米才记录新点
        if distance > 10 {
            pathCoordinates.append(location.coordinate)
            pathUpdateVersion += 1
        }
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
