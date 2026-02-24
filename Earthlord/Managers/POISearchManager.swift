//
//  POISearchManager.swift
//  Earthlord
//
//  使用 MapKit MKLocalSearch 搜索附近真实地点（POI）。
//  @MainActor：MKLocalSearch.start() 要求在主线程调用。
//

import Foundation
import MapKit
import CoreLocation
import OSLog

@MainActor
enum POISearchManager {

    private static let logger = Logger(subsystem: "com.earthlord", category: "POISearchManager")

    // 搜索的类别及映射的游戏类型
    private static let searchConfigs: [(MKPointOfInterestCategory, GamePOIType)] = [
        (.store,      .store),
        (.hospital,   .hospital),
        (.pharmacy,   .pharmacy),
        (.gasStation, .gasStation),
        (.restaurant, .restaurant),
        (.cafe,       .cafe),
    ]

    // MARK: - 公开接口

    /// 搜索 center 周围 radiusM 米内的真实 POI，返回数量由 limit 控制。
    /// - limit 由玩家密度等级决定（PlayerLocationManager.shared.densityLevel.poiLimit）
    /// - 独行者保底：limit == 1 且 1km 内无结果时自动扩大到 2km 重搜一次
    static func searchNearbyPOIs(
        center:  CLLocationCoordinate2D,
        radiusM: Double = 1000,
        limit:   Int    = 20
    ) async -> [GamePOI] {
        var pois = await _search(center: center, radiusM: radiusM, limit: limit)
        // 独行者保底：1km 无结果则扩至 2km
        if limit == 1 && pois.isEmpty {
            logger.info("[POISearch] 独行者 1km 无结果，扩大至 2km 重搜")
            pois = await _search(center: center, radiusM: radiusM * 2, limit: 1)
        }
        return pois
    }

    private static func _search(
        center:  CLLocationCoordinate2D,
        radiusM: Double,
        limit:   Int
    ) async -> [GamePOI] {
        var allResults: [GamePOI] = []

        for (category, poiType) in searchConfigs {
            let batch = await searchCategory(
                center:   center,
                radiusM:  radiusM,
                category: category,
                poiType:  poiType
            )
            allResults.append(contentsOf: batch)
        }

        // 按名称+坐标近似值去重
        var seen = Set<String>()
        let deduped = allResults.filter { poi in
            let latKey = Int(poi.coordinate.latitude  * 10_000)
            let lngKey = Int(poi.coordinate.longitude * 10_000)
            let key = "\(poi.name)_\(latKey)_\(lngKey)"
            return seen.insert(key).inserted
        }

        logger.info("[POISearch] 搜索完成，去重后 \(deduped.count) 个 POI（上限 \(limit)）")
        return Array(deduped.prefix(limit))
    }

    // MARK: - 私有：单类别搜索

    private static func searchCategory(
        center:   CLLocationCoordinate2D,
        radiusM:  Double,
        category: MKPointOfInterestCategory,
        poiType:  GamePOIType
    ) async -> [GamePOI] {

        let request = MKLocalSearch.Request()
        request.resultTypes = .pointOfInterest
        request.region = MKCoordinateRegion(
            center: center,
            latitudinalMeters:  radiusM * 2,
            longitudinalMeters: radiusM * 2
        )
        request.pointOfInterestFilter = MKPointOfInterestFilter(including: [category])

        do {
            let search   = MKLocalSearch(request: request)
            let response = try await search.start()
            let centerLoc = CLLocation(latitude: center.latitude, longitude: center.longitude)

            return response.mapItems.compactMap { item in
                let coord = item.placemark.coordinate
                let dist  = centerLoc.distance(
                    from: CLLocation(latitude: coord.latitude, longitude: coord.longitude)
                )
                guard dist <= radiusM else { return nil }

                let name = item.name ?? item.placemark.name ?? "未知地点"
                return GamePOI(
                    id:         UUID().uuidString,
                    name:       name,
                    coordinate: coord,
                    poiType:    poiType
                )
            }
        } catch {
            logger.warning("[POISearch] \(category.rawValue) 搜索失败: \(error.localizedDescription)")
            return []
        }
    }
}
