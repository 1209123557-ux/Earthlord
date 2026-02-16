//
//  CoordinateConverter.swift
//  Earthlord
//
//  坐标转换工具 - WGS-84 (GPS) → GCJ-02 (中国地图)
//  解决中国地图偏移问题，让轨迹显示在正确位置
//

import Foundation
import CoreLocation

// MARK: - CoordinateConverter
/// 坐标转换工具类
/// - WGS-84: GPS 硬件返回的国际标准坐标
/// - GCJ-02: 中国法规要求的加密坐标（火星坐标系）
enum CoordinateConverter {

    // MARK: - Constants
    private static let a: Double = 6378245.0  // 克拉索夫斯基椭球参数 a
    private static let ee: Double = 0.00669342162296594323  // 椭球的偏心率平方

    // MARK: - Public Methods

    /// WGS-84 → GCJ-02 转换（GPS 坐标 → 中国地图坐标）
    /// - Parameter wgs84: WGS-84 坐标（GPS 原始坐标）
    /// - Returns: GCJ-02 坐标（中国地图坐标）
    static func wgs84ToGcj02(_ wgs84: CLLocationCoordinate2D) -> CLLocationCoordinate2D {
        // 判断是否在中国境外（境外不需要转换）
        if outOfChina(wgs84.latitude, wgs84.longitude) {
            return wgs84
        }

        // 计算偏移量
        var dLat = transformLatitude(wgs84.longitude - 105.0, wgs84.latitude - 35.0)
        var dLon = transformLongitude(wgs84.longitude - 105.0, wgs84.latitude - 35.0)

        let radLat = wgs84.latitude / 180.0 * Double.pi
        var magic = sin(radLat)
        magic = 1 - ee * magic * magic
        let sqrtMagic = sqrt(magic)

        dLat = (dLat * 180.0) / ((a * (1 - ee)) / (magic * sqrtMagic) * Double.pi)
        dLon = (dLon * 180.0) / (a / sqrtMagic * cos(radLat) * Double.pi)

        // 返回加密后的坐标
        let gcj02Lat = wgs84.latitude + dLat
        let gcj02Lon = wgs84.longitude + dLon

        return CLLocationCoordinate2D(latitude: gcj02Lat, longitude: gcj02Lon)
    }

    /// 批量转换坐标数组
    /// - Parameter wgs84Coordinates: WGS-84 坐标数组
    /// - Returns: GCJ-02 坐标数组
    static func convertPath(_ wgs84Coordinates: [CLLocationCoordinate2D]) -> [CLLocationCoordinate2D] {
        return wgs84Coordinates.map { wgs84ToGcj02($0) }
    }

    // MARK: - Private Methods

    /// 判断坐标是否在中国境外
    /// - Parameters:
    ///   - lat: 纬度
    ///   - lon: 经度
    /// - Returns: true=境外, false=境内
    private static func outOfChina(_ lat: Double, _ lon: Double) -> Bool {
        if lon < 72.004 || lon > 137.8347 {
            return true
        }
        if lat < 0.8293 || lat > 55.8271 {
            return true
        }
        return false
    }

    /// 纬度偏移计算
    private static func transformLatitude(_ x: Double, _ y: Double) -> Double {
        var ret = -100.0 + 2.0 * x + 3.0 * y + 0.2 * y * y + 0.1 * x * y + 0.2 * sqrt(abs(x))
        ret += (20.0 * sin(6.0 * x * Double.pi) + 20.0 * sin(2.0 * x * Double.pi)) * 2.0 / 3.0
        ret += (20.0 * sin(y * Double.pi) + 40.0 * sin(y / 3.0 * Double.pi)) * 2.0 / 3.0
        ret += (160.0 * sin(y / 12.0 * Double.pi) + 320.0 * sin(y * Double.pi / 30.0)) * 2.0 / 3.0
        return ret
    }

    /// 经度偏移计算
    private static func transformLongitude(_ x: Double, _ y: Double) -> Double {
        var ret = 300.0 + x + 2.0 * y + 0.1 * x * x + 0.1 * x * y + 0.1 * sqrt(abs(x))
        ret += (20.0 * sin(6.0 * x * Double.pi) + 20.0 * sin(2.0 * x * Double.pi)) * 2.0 / 3.0
        ret += (20.0 * sin(x * Double.pi) + 40.0 * sin(x / 3.0 * Double.pi)) * 2.0 / 3.0
        ret += (150.0 * sin(x / 12.0 * Double.pi) + 300.0 * sin(x / 30.0 * Double.pi)) * 2.0 / 3.0
        return ret
    }
}
