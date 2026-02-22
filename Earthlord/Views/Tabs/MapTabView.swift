//
//  MapTabView.swift
//  Earthlord
//
//  地图页面 - 显示真实地图、用户位置、定位权限管理
//

import SwiftUI
import MapKit
import UIKit
import Supabase
import OSLog

struct MapTabView: View {
    // MARK: - Environment
    @EnvironmentObject private var locationManager: LocationManager

    // MARK: - 地图/领地状态
    @State private var hasLocatedUser = false
    @State private var isUploading = false
    @State private var uploadError: String? = nil
    @State private var territories: [Territory] = []
    @State private var territoriesVersion = 0

    // MARK: - Day 19: 碰撞检测状态
    @State private var collisionCheckTimer: Timer?
    @State private var collisionWarning: String? = nil
    @State private var showCollisionWarning = false
    @State private var collisionWarningLevel: WarningLevel = .safe

    // MARK: - 探索状态
    @StateObject private var explorationManager = ExplorationManager()
    @State private var explorationResult: ExplorationResult? = nil
    @State private var isFinishingExploration = false
    @State private var showExplorationResult = false
    @State private var explorationErrorMessage: String? = nil

    private let mapLogger = Logger(subsystem: "com.earthlord", category: "MapTabView")

    // MARK: - Computed
    private var hasValidationResult: Bool {
        locationManager.territoryValidationPassed || locationManager.territoryValidationError != nil
    }

    private var currentUserId: String? {
        AuthManager.shared.currentUser?.id.uuidString
    }

    // MARK: - Body
    var body: some View {
        ZStack {
            ApocalypseTheme.background.ignoresSafeArea()

            if locationManager.isAuthorized {
                mapView
            } else if locationManager.isDenied {
                permissionDeniedView
            } else {
                permissionRequestView
            }

            if locationManager.isAuthorized {
                // 探索中：顶部状态悬浮条
                if explorationManager.isExploring {
                    VStack {
                        explorationStatusBanner
                        Spacer()
                    }
                }
                VStack {
                    Spacer()
                    bottomActionArea
                }
            }
        }
        .onAppear {
            if locationManager.authorizationStatus == .notDetermined {
                locationManager.requestPermission()
            } else if locationManager.isAuthorized {
                locationManager.startUpdatingLocation()
            }
            Task { await loadTerritories() }
        }
        .sheet(isPresented: $showExplorationResult, onDismiss: { explorationErrorMessage = nil }) {
            if let result = explorationResult {
                ExplorationResultView(result: result, errorMessage: explorationErrorMessage)
            }
        }
        .onReceive(explorationManager.$explorationFailed) { failed in
            if failed { handleExplorationFailed() }
        }
    }

    // MARK: - Map View
    private var mapView: some View {
        ZStack {
            MapViewRepresentable(
                userLocation: $locationManager.userLocation,
                hasLocatedUser: $hasLocatedUser,
                trackingPath: $locationManager.pathCoordinates,
                pathUpdateVersion: locationManager.pathUpdateVersion,
                isTracking: locationManager.isTracking,
                isPathClosed: locationManager.isPathClosed,
                territories: territories,
                currentUserId: currentUserId,
                territoriesVersion: territoriesVersion
            )
            .ignoresSafeArea()
            .colorMultiply(Color(red: 1.0, green: 0.88, blue: 0.72))
            .saturation(0.72)
            .brightness(-0.04)

            // 速度警告横幅（顶部）
            if let warning = locationManager.speedWarning {
                VStack {
                    speedWarningBanner(warning: warning)
                        .padding(.horizontal, 20)
                        .padding(.top, 60)
                    Spacer()
                }
            }

            // Day 19: 碰撞警告横幅（分级颜色）
            if showCollisionWarning, let warning = collisionWarning {
                collisionWarningBanner(message: warning, level: collisionWarningLevel)
            }
        }
        .onReceive(locationManager.$manualValidationTriggered) { triggered in
            if triggered {
                locationManager.manualValidationTriggered = false
            }
        }
    }

    // MARK: - Bottom Action Area
    private var bottomActionArea: some View {
        Group {
            if hasValidationResult {
                HStack(alignment: .bottom, spacing: 12) {
                    validationResultCard
                    VStack(spacing: 10) {
                        if locationManager.territoryValidationPassed {
                            confirmButton
                        }
                        compactClaimButton
                    }
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 40)
                .transition(.move(edge: .bottom).combined(with: .opacity))
            } else {
                // 三个按钮：左侧圈地 / 中间定位 / 右侧探索
                HStack(spacing: 0) {
                    claimTerritoryButton
                    Spacer()
                    recenterButton
                    Spacer()
                    exploreButton
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 40)
            }
        }
        .animation(.easeInOut(duration: 0.25), value: hasValidationResult)
    }

    // MARK: - Validation Result Card
    private var validationResultCard: some View {
        HStack(spacing: 12) {
            Image(systemName: locationManager.territoryValidationPassed
                  ? "checkmark.circle.fill"
                  : "xmark.circle.fill")
                .font(.title2)

            VStack(alignment: .leading, spacing: 3) {
                Text(locationManager.territoryValidationPassed ? "验证通过" : "验证失败")
                    .font(.headline).fontWeight(.bold)

                if locationManager.territoryValidationPassed {
                    Text("面积: \(String(format: "%.0f", locationManager.calculatedArea))m²")
                        .font(.subheadline)
                } else {
                    Text(locationManager.territoryValidationError ?? "验证失败")
                        .font(.subheadline)
                }
            }
            Spacer()
        }
        .foregroundColor(.white)
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(locationManager.territoryValidationPassed ? Color.green : Color.red)
        .cornerRadius(16)
        .shadow(color: .black.opacity(0.2), radius: 6, x: 0, y: 3)
    }

    // MARK: - Confirm Button
    private var confirmButton: some View {
        Button(action: {
            Task { await uploadCurrentTerritory() }
        }) {
            HStack(spacing: 6) {
                if isUploading {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                        .scaleEffect(0.75)
                } else {
                    Image(systemName: "checkmark.seal.fill")
                        .font(.system(size: 13))
                }
                Text(isUploading ? "登记中..." : "确认登记")
                    .font(.system(size: 13, weight: .semibold))
            }
            .foregroundColor(.white)
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background(isUploading ? Color.green.opacity(0.6) : Color.green)
            .cornerRadius(20)
            .shadow(color: .black.opacity(0.2), radius: 4, x: 0, y: 2)
        }
        .disabled(isUploading)
    }

    // MARK: - Compact Claim Button（验证结果区）
    private var compactClaimButton: some View {
        Button(action: {
            if locationManager.isTracking {
                stopCollisionMonitoring()
                locationManager.stopPathTracking()
            } else {
                startClaimingWithCollisionCheck()
            }
        }) {
            VStack(spacing: 2) {
                HStack(spacing: 6) {
                    Image(systemName: locationManager.isTracking ? "stop.fill" : "flag.fill")
                        .font(.system(size: 12))
                    Text(locationManager.isTracking ? "停止圈地" : "开始圈地")
                        .font(.system(size: 13, weight: .semibold))
                }
                if locationManager.isTracking && !locationManager.pathCoordinates.isEmpty {
                    Text("\(locationManager.pathCoordinates.count) 点")
                        .font(.caption2)
                }
            }
            .foregroundColor(.white)
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background(locationManager.isTracking ? ApocalypseTheme.danger : ApocalypseTheme.primary)
            .cornerRadius(20)
            .shadow(color: .black.opacity(0.2), radius: 4, x: 0, y: 2)
        }
    }

    // MARK: - Claim Territory Button（普通状态）
    private var claimTerritoryButton: some View {
        Button(action: {
            if locationManager.isTracking {
                stopCollisionMonitoring()
                locationManager.stopPathTracking()
            } else {
                startClaimingWithCollisionCheck()
            }
        }) {
            HStack(spacing: 8) {
                Image(systemName: locationManager.isTracking ? "stop.fill" : "flag.fill")
                    .font(.system(size: 16))
                Text(locationManager.isTracking ? "停止圈地" : "开始圈地")
                    .font(.system(size: 14, weight: .semibold))
                if locationManager.isTracking && !locationManager.pathCoordinates.isEmpty {
                    Text("(\(locationManager.pathCoordinates.count))")
                        .font(.system(size: 12))
                        .foregroundColor(.white.opacity(0.8))
                }
            }
            .foregroundColor(.white)
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(locationManager.isTracking ? ApocalypseTheme.danger : ApocalypseTheme.primary)
            .cornerRadius(25)
            .shadow(color: .black.opacity(0.3), radius: 8, x: 0, y: 4)
        }
    }

    // MARK: - Recenter Button
    private var recenterButton: some View {
        Button(action: { hasLocatedUser = false }) {
            Image(systemName: "location.fill")
                .font(.system(size: 20))
                .foregroundColor(.white)
                .frame(width: 50, height: 50)
                .background(ApocalypseTheme.primary)
                .cornerRadius(25)
                .shadow(color: .black.opacity(0.3), radius: 8, x: 0, y: 4)
        }
    }

    // MARK: - Explore Button
    private var exploreButton: some View {
        Button(action: {
            if explorationManager.isExploring {
                stopExploring()
            } else {
                startExploring()
            }
        }) {
            HStack(spacing: 8) {
                if isFinishingExploration {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                        .scaleEffect(0.75)
                } else if explorationManager.isExploring {
                    Image(systemName: "stop.fill")
                        .font(.system(size: 16))
                } else {
                    Image(systemName: "binoculars.fill")
                        .font(.system(size: 16))
                }
                Text(isFinishingExploration ? "结算中..." : explorationManager.isExploring ? "结束探索" : "探索")
                    .font(.system(size: 14, weight: .semibold))
            }
            .foregroundColor(.white)
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(
                isFinishingExploration    ? ApocalypseTheme.primary.opacity(0.55) :
                explorationManager.isExploring ? ApocalypseTheme.danger :
                ApocalypseTheme.primary
            )
            .cornerRadius(25)
            .shadow(color: .black.opacity(0.3), radius: 8, x: 0, y: 4)
        }
        .disabled(isFinishingExploration)
    }

    private func startExploring() {
        mapLogger.info("[MapTabView] 用户点击开始探索")
        explorationManager.startExploration()
    }

    private func stopExploring() {
        let (distanceM, durationSec, startTime) = explorationManager.stopExploration()
        mapLogger.info("[MapTabView] 用户点击结束探索 dist=\(distanceM)m dur=\(durationSec)s")
        isFinishingExploration = true

        Task {
            let rewards = RewardGenerator.generateRewards(distanceM: distanceM)
            let tier    = RewardGenerator.calculateTier(distanceM: distanceM)
            mapLogger.info("[MapTabView] rewards=\(rewards.count) items tier=\(tier.rawValue)")

            do {
                try await saveExplorationSession(
                    startTime:       startTime,
                    endTime:         Date(),
                    durationSeconds: durationSec,
                    distanceM:       distanceM,
                    tier:            tier,
                    items:           rewards
                )
                if !rewards.isEmpty {
                    try await InventoryManager.shared.addItems(rewards)
                }
            } catch {
                mapLogger.error("[MapTabView] 保存探索数据失败: \(error.localizedDescription)")
            }

            let result = ExplorationResult(
                walkDistanceM:   distanceM,
                rewardTier:      tier,
                durationSeconds: durationSec,
                lootedItems:     rewards
            )
            isFinishingExploration = false
            explorationResult      = result
            showExplorationResult  = true
        }
    }

    private func handleExplorationFailed() {
        mapLogger.error("[MapTabView] 探索被强制终止（超速）")
        explorationManager.resetFailedState()
        explorationErrorMessage = "行驶速度超过 30 km/h 达 10 秒，探索已自动终止。"
        let dummy = ExplorationResult(
            walkDistanceM:   Int(explorationManager.totalDistanceM),
            rewardTier:      .none,
            durationSeconds: explorationManager.durationSeconds,
            lootedItems:     []
        )
        explorationResult     = dummy
        showExplorationResult = true
    }

    private func saveExplorationSession(
        startTime:       Date,
        endTime:         Date,
        durationSeconds: Int,
        distanceM:       Int,
        tier:            RewardTier,
        items:           [(itemId: String, quantity: Int)]
    ) async throws {
        guard let userId = AuthManager.shared.currentUser?.id else { return }

        struct SessionRow: Encodable {
            let user_id:          String
            let start_time:       String
            let end_time:         String
            let duration_seconds: Int
            let total_distance:   Double
            let reward_tier:      String
            let items_rewarded:   [ItemEntry]
            let status:           String
            struct ItemEntry: Encodable { let item_id: String; let quantity: Int }
        }

        let fmt = ISO8601DateFormatter()
        try await supabase
            .from("exploration_sessions")
            .insert(SessionRow(
                user_id:          userId.uuidString.lowercased(),
                start_time:       fmt.string(from: startTime),
                end_time:         fmt.string(from: endTime),
                duration_seconds: durationSeconds,
                total_distance:   Double(distanceM),
                reward_tier:      tier.rawValue,
                items_rewarded:   items.map { .init(item_id: $0.itemId, quantity: $0.quantity) },
                status:           "completed"
            ))
            .execute()
    }

    // MARK: - 探索状态悬浮卡片

    private var explorationStatusBanner: some View {
        let isViolation = explorationManager.isSpeedViolation
        let distM       = Int(explorationManager.totalDistanceM)
        let currentTier = RewardGenerator.calculateTier(distanceM: distM)
        let nextTier    = RewardGenerator.nextTierInfo(distanceM: distM)
        let bannerColor: Color = isViolation ? .orange : ApocalypseTheme.success

        return VStack(spacing: 0) {

            // ── 上排：距离 | 时长 | GPS点数 + 结束按钮 ──
            HStack(spacing: 0) {
                // 距离
                HStack(spacing: 4) {
                    Image(systemName: "figure.walk").font(.system(size: 13))
                    Text("\(distM) m").font(.system(size: 14, weight: .bold))
                }
                // 分隔
                Rectangle()
                    .fill(Color.white.opacity(0.35))
                    .frame(width: 1, height: 14)
                    .padding(.horizontal, 10)
                // 时长
                HStack(spacing: 4) {
                    Image(systemName: "clock").font(.system(size: 13))
                    Text(formatExpDuration(explorationManager.durationSeconds))
                        .font(.system(size: 14, weight: .bold))
                }
                // 分隔
                Rectangle()
                    .fill(Color.white.opacity(0.35))
                    .frame(width: 1, height: 14)
                    .padding(.horizontal, 10)
                // GPS 点数
                HStack(spacing: 4) {
                    Image(systemName: "location.circle").font(.system(size: 13))
                    Text("\(explorationManager.locationCount)")
                        .font(.system(size: 14, weight: .bold))
                }
                Spacer()
                // 结束按钮
                Button(action: {
                    if explorationManager.isExploring { stopExploring() }
                }) {
                    HStack(spacing: 4) {
                        if isFinishingExploration {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                .scaleEffect(0.7)
                        } else {
                            Image(systemName: "stop.fill").font(.system(size: 11))
                        }
                        Text(isFinishingExploration ? "结算中" : "结束")
                            .font(.system(size: 13, weight: .semibold))
                    }
                    .foregroundColor(.white)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(ApocalypseTheme.danger)
                    .cornerRadius(16)
                }
                .disabled(isFinishingExploration)
            }
            .foregroundColor(.white)

            // ── 分隔线 ──
            Rectangle()
                .fill(Color.white.opacity(0.2))
                .frame(height: 1)
                .padding(.top, 10)
                .padding(.bottom, 8)

            // ── 下排：奖励等级 + 进度提示 ──
            HStack(spacing: 6) {
                if isViolation {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.system(size: 13))
                        .foregroundColor(.yellow)
                    Text("速度过快！\(explorationManager.speedViolationCountdown)s 后终止探索")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(.yellow)
                } else {
                    Text(currentTier.displayName)
                        .font(.system(size: 13, weight: .bold))
                        .foregroundColor(.white)
                    if let next = nextTier {
                        Text("距\(next.tierName)还差 \(next.remaining) m")
                            .font(.system(size: 13))
                            .foregroundColor(.white.opacity(0.85))
                    } else {
                        Text("已达最高奖励等级 🎉")
                            .font(.system(size: 13))
                            .foregroundColor(.white.opacity(0.85))
                    }
                }
                Spacer()
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(bannerColor.opacity(0.92))
        .cornerRadius(20)
        .shadow(color: bannerColor.opacity(0.4), radius: 8, x: 0, y: 4)
        .padding(.horizontal, 20)
        .padding(.top, 60)
        .transition(.move(edge: .top).combined(with: .opacity))
        .animation(.easeInOut(duration: 0.3), value: explorationManager.isExploring)
        .animation(.easeInOut(duration: 0.2), value: isViolation)
    }

    private func formatExpDuration(_ seconds: Int) -> String {
        String(format: "%02d:%02d", seconds / 60, seconds % 60)
    }

    // MARK: - Day 19: 带碰撞检测的开始圈地

    private func startClaimingWithCollisionCheck() {
        guard let location = locationManager.userLocation,
              let userId = currentUserId else {
            locationManager.startPathTracking()
            return
        }

        let result = TerritoryManager.shared.checkPointCollision(
            location: location,
            currentUserId: userId
        )

        if result.hasCollision {
            collisionWarning = result.message
            collisionWarningLevel = .violation
            showCollisionWarning = true

            let generator = UINotificationFeedbackGenerator()
            generator.prepare()
            generator.notificationOccurred(.error)

            TerritoryLogger.shared.log("起点碰撞：阻止圈地", type: .error)

            DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                showCollisionWarning = false
                collisionWarning = nil
                collisionWarningLevel = .safe
            }
            return
        }

        TerritoryLogger.shared.log("起始点安全，开始圈地", type: .info)
        locationManager.startPathTracking()
        startCollisionMonitoring()
    }

    // MARK: - Day 19: 碰撞监控定时器

    private func startCollisionMonitoring() {
        stopCollisionCheckTimer()
        collisionCheckTimer = Timer.scheduledTimer(withTimeInterval: 10.0, repeats: true) { _ in
            performCollisionCheck()
        }
        TerritoryLogger.shared.log("碰撞检测定时器已启动", type: .info)
    }

    /// 只停止定时器，不清除警告（violation 时保留横幅显示）
    private func stopCollisionCheckTimer() {
        collisionCheckTimer?.invalidate()
        collisionCheckTimer = nil
    }

    /// 完全停止：停止定时器 + 清除警告状态
    private func stopCollisionMonitoring() {
        stopCollisionCheckTimer()
        showCollisionWarning = false
        collisionWarning = nil
        collisionWarningLevel = .safe
    }

    // MARK: - Day 19: 执行碰撞检测

    private func performCollisionCheck() {
        guard locationManager.isTracking,
              let userId = currentUserId else { return }

        let path = locationManager.pathCoordinates
        guard path.count >= 2 else { return }

        let result = TerritoryManager.shared.checkPathCollisionComprehensive(
            path: path,
            currentUserId: userId
        )

        switch result.warningLevel {
        case .safe:
            showCollisionWarning = false
            collisionWarning = nil
            collisionWarningLevel = .safe

        case .caution:
            collisionWarning = result.message
            collisionWarningLevel = .caution
            showCollisionWarning = true
            triggerHapticFeedback(level: .caution)

        case .warning:
            collisionWarning = result.message
            collisionWarningLevel = .warning
            showCollisionWarning = true
            triggerHapticFeedback(level: .warning)

        case .danger:
            collisionWarning = result.message
            collisionWarningLevel = .danger
            showCollisionWarning = true
            triggerHapticFeedback(level: .danger)

        case .violation:
            // 1. 先设置横幅（必须在 stop 之前！）
            collisionWarning = result.message
            collisionWarningLevel = .violation
            showCollisionWarning = true

            // 2. 震动
            triggerHapticFeedback(level: .violation)

            // 3. 只停止定时器，不清除横幅
            stopCollisionCheckTimer()

            // 4. 停止圈地
            locationManager.stopPathTracking()

            TerritoryLogger.shared.log("碰撞违规，自动停止圈地", type: .error)

            // 5. 5 秒后清除横幅
            DispatchQueue.main.asyncAfter(deadline: .now() + 5) {
                showCollisionWarning = false
                collisionWarning = nil
                collisionWarningLevel = .safe
            }
        }
    }

    // MARK: - Day 19: 震动反馈

    private func triggerHapticFeedback(level: WarningLevel) {
        switch level {
        case .safe:
            break

        case .caution:
            let g = UINotificationFeedbackGenerator()
            g.prepare()
            g.notificationOccurred(.warning)

        case .warning:
            let g = UIImpactFeedbackGenerator(style: .medium)
            g.prepare()
            g.impactOccurred()
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) { g.impactOccurred() }

        case .danger:
            let g = UIImpactFeedbackGenerator(style: .heavy)
            g.prepare()
            g.impactOccurred()
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) { g.impactOccurred() }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) { g.impactOccurred() }

        case .violation:
            let g = UINotificationFeedbackGenerator()
            g.prepare()
            g.notificationOccurred(.error)
        }
    }

    // MARK: - Day 19: 碰撞警告横幅

    private func collisionWarningBanner(message: String, level: WarningLevel) -> some View {
        let bgColor: Color
        switch level {
        case .safe:    bgColor = .green
        case .caution: bgColor = .yellow
        case .warning: bgColor = .orange
        case .danger, .violation: bgColor = .red
        }

        let textColor: Color = (level == .caution) ? .black : .white
        let iconName = (level == .violation) ? "xmark.octagon.fill" : "exclamationmark.triangle.fill"

        return VStack {
            HStack(spacing: 8) {
                Image(systemName: iconName)
                    .font(.system(size: 18))
                Text(message)
                    .font(.system(size: 14, weight: .medium))
            }
            .foregroundColor(textColor)
            .padding(.horizontal, 20)
            .padding(.vertical, 12)
            .background(bgColor.opacity(0.95))
            .cornerRadius(25)
            .shadow(color: .black.opacity(0.3), radius: 4, x: 0, y: 2)
            .padding(.top, 120)

            Spacer()
        }
        .transition(.move(edge: .top).combined(with: .opacity))
        .animation(.easeInOut(duration: 0.3), value: showCollisionWarning)
    }

    // MARK: - Upload Logic

    private func uploadCurrentTerritory() async {
        guard locationManager.territoryValidationPassed else { return }

        isUploading = true
        uploadError = nil

        do {
            try await TerritoryManager.shared.uploadTerritory(
                coordinates: locationManager.pathCoordinates,
                area: locationManager.calculatedArea,
                startTime: locationManager.trackingStartTime
            )
            stopCollisionMonitoring()
            locationManager.stopPathTracking()
            locationManager.resetAfterUpload()
            await loadTerritories()
        } catch {
            uploadError = "上传失败: \(error.localizedDescription)"
            DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                uploadError = nil
            }
        }

        isUploading = false
    }

    // MARK: - Load Territories

    private func loadTerritories() async {
        do {
            territories = try await TerritoryManager.shared.loadAllTerritories()
            territoriesVersion += 1
            TerritoryLogger.shared.log("加载了 \(territories.count) 个领地", type: .info)
        } catch {
            TerritoryLogger.shared.log("加载领地失败: \(error.localizedDescription)", type: .error)
        }
    }

    // MARK: - Permission Request View
    private var permissionRequestView: some View {
        VStack(spacing: 24) {
            Image(systemName: "location.circle.fill")
                .font(.system(size: 80))
                .foregroundColor(ApocalypseTheme.primary)
            Text("获取位置权限")
                .font(.title2).fontWeight(.bold)
                .foregroundColor(ApocalypseTheme.textPrimary)
            Text("《地球新主》需要获取您的位置来显示您在末日世界中的坐标，帮助您探索和圈定领地。")
                .font(.body)
                .foregroundColor(ApocalypseTheme.textSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
            Button(action: { locationManager.requestPermission() }) {
                Text("允许定位")
                    .font(.headline).foregroundColor(.white)
                    .frame(maxWidth: .infinity).padding()
                    .background(ApocalypseTheme.primary).cornerRadius(12)
            }
            .padding(.horizontal, 40).padding(.top, 16)
        }
    }

    // MARK: - Permission Denied View
    private var permissionDeniedView: some View {
        VStack(spacing: 24) {
            Image(systemName: "location.slash.fill")
                .font(.system(size: 80))
                .foregroundColor(ApocalypseTheme.danger)
            Text("定位权限已关闭")
                .font(.title2).fontWeight(.bold)
                .foregroundColor(ApocalypseTheme.textPrimary)
            Text("请前往系统设置中开启定位权限，以便在地图上查看您的位置。")
                .font(.body)
                .foregroundColor(ApocalypseTheme.textSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
            Button(action: {
                if let url = URL(string: UIApplication.openSettingsURLString) {
                    UIApplication.shared.open(url)
                }
            }) {
                Text("前往设置")
                    .font(.headline).foregroundColor(.white)
                    .frame(maxWidth: .infinity).padding()
                    .background(ApocalypseTheme.primary).cornerRadius(12)
            }
            .padding(.horizontal, 40).padding(.top, 16)
            if let error = locationManager.locationError {
                Text(error).font(.caption)
                    .foregroundColor(ApocalypseTheme.danger).padding(.top, 8)
            }
        }
    }

    // MARK: - Speed Warning Banner
    private func speedWarningBanner(warning: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 20)).foregroundColor(.white)
            Text(warning)
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(.white).lineLimit(2)
            Spacer()
        }
        .padding()
        .background(locationManager.isTracking ? ApocalypseTheme.warning : ApocalypseTheme.danger)
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.3), radius: 8, x: 0, y: 4)
        .onAppear {
            DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                locationManager.speedWarning = nil
            }
        }
    }
}

#Preview {
    MapTabView()
}
