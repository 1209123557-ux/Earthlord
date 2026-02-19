//
//  MapTabView.swift
//  Earthlord
//
//  地图页面 - 显示真实地图、用户位置、定位权限管理
//

import SwiftUI
import MapKit
import Supabase

struct MapTabView: View {
    // MARK: - Environment
    @EnvironmentObject private var locationManager: LocationManager

    // MARK: - State Properties
    @State private var hasLocatedUser = false
    @State private var isUploading = false
    @State private var uploadError: String? = nil
    @State private var territories: [Territory] = []
    @State private var territoriesVersion = 0

    // MARK: - Computed: 是否有验证结果
    private var hasValidationResult: Bool {
        locationManager.territoryValidationPassed || locationManager.territoryValidationError != nil
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

            // 底部操作区（仅已授权时）
            if locationManager.isAuthorized {
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
                currentUserId: AuthManager.shared.currentUser?.id.uuidString,
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
        }
        .onReceive(locationManager.$manualValidationTriggered) { triggered in
            if triggered {
                locationManager.manualValidationTriggered = false
            }
        }
    }

    // MARK: - Bottom Action Area
    /// 底部操作区：有验证结果时显示卡片+按钮；否则显示普通按钮
    private var bottomActionArea: some View {
        Group {
            if hasValidationResult {
                // 验证结果卡片布局（对齐参考图）
                HStack(alignment: .bottom, spacing: 12) {
                    validationResultCard
                    // 右侧按钮组
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
                // 普通圈地按钮布局
                HStack(spacing: 12) {
                    Spacer()
                    claimTerritoryButton
                    recenterButton
                }
                .padding(.trailing, 20)
                .padding(.bottom, 40)
            }
        }
        .animation(.easeInOut(duration: 0.25), value: hasValidationResult)
    }

    // MARK: - Validation Result Card
    /// 验证结果卡片（成功=绿色，失败=红色）
    private var validationResultCard: some View {
        HStack(spacing: 12) {
            Image(systemName: locationManager.territoryValidationPassed
                  ? "checkmark.circle.fill"
                  : "xmark.circle.fill")
                .font(.title2)

            VStack(alignment: .leading, spacing: 3) {
                Text(locationManager.territoryValidationPassed ? "验证通过" : "验证失败")
                    .font(.headline)
                    .fontWeight(.bold)

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

    // MARK: - Confirm Button (compact)
    /// 确认登记按钮（仅验证通过时显示）
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

    // MARK: - Compact Claim Button (shown in validation area)
    /// 验证结果区右侧的停止/开始按钮（带点数）
    private var compactClaimButton: some View {
        Button(action: {
            if locationManager.isTracking {
                locationManager.stopPathTracking()
            } else {
                locationManager.startPathTracking()
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

    // MARK: - Claim Territory Button (normal)
    /// 普通圈地按钮（无验证结果时显示）
    private var claimTerritoryButton: some View {
        Button(action: {
            if locationManager.isTracking {
                locationManager.stopPathTracking()
            } else {
                locationManager.startPathTracking()
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
            locationManager.stopPathTracking()
            locationManager.resetAfterUpload()
            // 上传成功后刷新地图上的领地
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
