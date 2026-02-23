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

    /// 搜索 center 周围 radiusM 米内的真实 POI，最多返回 20 个（iOS 地理围栏限制）
    static func searchNearbyPOIs(
        center: CLLocationCoordinate2D,
        radiusM: Double = 1000
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

        logger.info("[POISearch] 搜索完成，去重后 \(deduped.count) 个 POI（限 20）")
        return Array(deduped.prefix(20))
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
