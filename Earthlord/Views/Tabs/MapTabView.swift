//
//  MapTabView.swift
//  Earthlord
//
//  地图页面 - 显示真实地图、用户位置、定位权限管理
//

import SwiftUI
import MapKit

struct MapTabView: View {
    // MARK: - State Objects
    // ⭐ 从 MainTabView 的 environmentObject 获取共享实例
    @EnvironmentObject private var locationManager: LocationManager

    // MARK: - State Properties
    @State private var hasLocatedUser = false       // 是否已完成首次定位
    @State private var showValidationBanner = false  // 是否显示验证结果横幅
    @State private var isUploading = false           // 是否正在上传（防止重复点击）
    @State private var uploadError: String? = nil    // 上传错误信息

    var body: some View {
        ZStack {
            // 背景色
            ApocalypseTheme.background
                .ignoresSafeArea()

            // 主内容
            if locationManager.isAuthorized {
                // 已授权：显示地图
                mapView
            } else if locationManager.isDenied {
                // 拒绝授权：显示提示
                permissionDeniedView
            } else {
                // 未决定：显示权限请求
                permissionRequestView
            }

            // 右下角按钮组（仅在已授权时显示）
            if locationManager.isAuthorized {
                VStack {
                    Spacer()

                    // 上传错误提示
                    if let error = uploadError {
                        Text(error)
                            .font(.caption)
                            .foregroundColor(.white)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                            .background(Color.red.opacity(0.9))
                            .cornerRadius(8)
                            .padding(.horizontal, 20)
                            .padding(.bottom, 8)
                            .transition(.opacity)
                    }

                    HStack(spacing: 12) {
                        Spacer()

                        // 验证通过时：显示「确认登记」按钮；否则显示正常圈地按钮
                        if locationManager.territoryValidationPassed {
                            confirmTerritoryButton
                        } else {
                            claimTerritoryButton
                        }

                        // 定位按钮
                        recenterButton
                    }
                    .padding(.trailing, 20)
                    .padding(.bottom, 40)
                }
            }
        }
        .onAppear {
            // 页面出现时请求定位权限
            if locationManager.authorizationStatus == .notDetermined {
                locationManager.requestPermission()
            } else if locationManager.isAuthorized {
                locationManager.startUpdatingLocation()
            }
        }
    }

    // MARK: - Map View
    /// 地图视图
    private var mapView: some View {
        ZStack {
            MapViewRepresentable(
                userLocation: $locationManager.userLocation,
                hasLocatedUser: $hasLocatedUser,
                trackingPath: $locationManager.pathCoordinates,
                pathUpdateVersion: locationManager.pathUpdateVersion,
                isTracking: locationManager.isTracking,
                isPathClosed: locationManager.isPathClosed
            )
            .ignoresSafeArea()
            // ⭐ 末世效果在 SwiftUI 层实现，避免影响轨迹线和多边形颜色
            // colorMultiply：轻微棕黄色调 (cyan×0.85→仍为青绿, green×0.80→仍为绿色)
            .colorMultiply(Color(red: 1.0, green: 0.88, blue: 0.72))
            .saturation(0.72)     // 降低饱和度，模拟末世灰暗感
            .brightness(-0.04)    // 略微压暗

            // 速度警告横幅
            if let warning = locationManager.speedWarning {
                VStack {
                    speedWarningBanner(warning: warning)
                        .padding(.horizontal, 20)
                        .padding(.top, 60)
                    Spacer()
                }
            }

            // 验证结果横幅
            if showValidationBanner {
                VStack {
                    validationResultBanner
                        .padding(.horizontal, 20)
                    Spacer()
                }
            }
        }
        // 监听闭环状态，闭环后根据验证结果显示横幅
        .onReceive(locationManager.$isPathClosed) { isClosed in
            if isClosed {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    showValidationBannerTemporarily()
                }
            }
        }
        // 监听手动停止时的验证触发
        .onReceive(locationManager.$manualValidationTriggered) { triggered in
            if triggered {
                showValidationBannerTemporarily()
                locationManager.manualValidationTriggered = false
            }
        }
    }

    // MARK: - Permission Request View
    /// 权限请求视图
    private var permissionRequestView: some View {
        VStack(spacing: 24) {
            // 图标
            Image(systemName: "location.circle.fill")
                .font(.system(size: 80))
                .foregroundColor(ApocalypseTheme.primary)

            // 标题
            Text("获取位置权限")
                .font(.title2)
                .fontWeight(.bold)
                .foregroundColor(ApocalypseTheme.textPrimary)

            // 描述
            Text("《地球新主》需要获取您的位置来显示您在末日世界中的坐标，帮助您探索和圈定领地。")
                .font(.body)
                .foregroundColor(ApocalypseTheme.textSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)

            // 授权按钮
            Button(action: {
                locationManager.requestPermission()
            }) {
                Text("允许定位")
                    .font(.headline)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(ApocalypseTheme.primary)
                    .cornerRadius(12)
            }
            .padding(.horizontal, 40)
            .padding(.top, 16)
        }
    }

    // MARK: - Permission Denied View
    /// 权限被拒绝视图
    private var permissionDeniedView: some View {
        VStack(spacing: 24) {
            // 图标
            Image(systemName: "location.slash.fill")
                .font(.system(size: 80))
                .foregroundColor(ApocalypseTheme.danger)

            // 标题
            Text("定位权限已关闭")
                .font(.title2)
                .fontWeight(.bold)
                .foregroundColor(ApocalypseTheme.textPrimary)

            // 描述
            Text("请前往系统设置中开启定位权限，以便在地图上查看您的位置。")
                .font(.body)
                .foregroundColor(ApocalypseTheme.textSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)

            // 前往设置按钮
            Button(action: {
                // 打开系统设置
                if let url = URL(string: UIApplication.openSettingsURLString) {
                    UIApplication.shared.open(url)
                }
            }) {
                Text("前往设置")
                    .font(.headline)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(ApocalypseTheme.primary)
                    .cornerRadius(12)
            }
            .padding(.horizontal, 40)
            .padding(.top, 16)

            // 错误信息（如果有）
            if let error = locationManager.locationError {
                Text(error)
                    .font(.caption)
                    .foregroundColor(ApocalypseTheme.danger)
                    .padding(.top, 8)
            }
        }
    }

    // MARK: - Claim Territory Button
    /// 圈地按钮
    private var claimTerritoryButton: some View {
        Button(action: {
            if locationManager.isTracking {
                // 停止追踪
                locationManager.stopPathTracking()
            } else {
                // 开始追踪
                locationManager.startPathTracking()
            }
        }) {
            HStack(spacing: 8) {
                Image(systemName: locationManager.isTracking ? "stop.fill" : "flag.fill")
                    .font(.system(size: 16))

                Text(locationManager.isTracking ? "停止圈地" : "开始圈地")
                    .font(.system(size: 14, weight: .semibold))

                // 显示当前点数（追踪时）
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
    /// 重新居中按钮
    private var recenterButton: some View {
        Button(action: {
            // 重置首次定位标志，触发重新居中
            hasLocatedUser = false
        }) {
            Image(systemName: "location.fill")
                .font(.system(size: 20))
                .foregroundColor(.white)
                .frame(width: 50, height: 50)
                .background(ApocalypseTheme.primary)
                .cornerRadius(25)
                .shadow(color: .black.opacity(0.3), radius: 8, x: 0, y: 4)
        }
    }

    // MARK: - Confirm Territory Button
    /// 确认登记领地按钮（验证通过后才显示）
    private var confirmTerritoryButton: some View {
        Button(action: {
            Task {
                await uploadCurrentTerritory()
            }
        }) {
            HStack(spacing: 8) {
                if isUploading {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                        .scaleEffect(0.8)
                } else {
                    Image(systemName: "checkmark.seal.fill")
                        .font(.system(size: 16))
                }
                Text(isUploading ? "登记中..." : "确认登记领地")
                    .font(.system(size: 14, weight: .semibold))
            }
            .foregroundColor(.white)
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(isUploading ? Color.green.opacity(0.6) : Color.green)
            .cornerRadius(25)
            .shadow(color: .black.opacity(0.3), radius: 8, x: 0, y: 4)
        }
        .disabled(isUploading)
    }

    // MARK: - Upload Logic
    /// 上传当前圈定的领地
    private func uploadCurrentTerritory() async {
        // ⚠️ 再次检查验证状态，防止绕过验证
        guard locationManager.territoryValidationPassed else {
            uploadError = "领地验证未通过，无法上传"
            return
        }

        isUploading = true
        uploadError = nil

        do {
            try await TerritoryManager.shared.uploadTerritory(
                coordinates: locationManager.pathCoordinates,
                area: locationManager.calculatedArea,
                startTime: locationManager.trackingStartTime
            )

            // ⚠️ 上传成功：先停止追踪（停计时器），再清除路径和验证状态
            locationManager.stopPathTracking()
            locationManager.resetAfterUpload()

        } catch {
            uploadError = "上传失败: \(error.localizedDescription)"
            // 错误提示 3 秒后自动消失
            DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                uploadError = nil
            }
        }

        isUploading = false
    }

    // MARK: - Helper Methods
    /// 显示验证结果横幅，3 秒后自动隐藏
    private func showValidationBannerTemporarily() {
        withAnimation {
            showValidationBanner = true
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
            withAnimation {
                showValidationBanner = false
            }
        }
    }

    // MARK: - Validation Result Banner
    /// 验证结果横幅（根据验证结果显示成功或失败）
    private var validationResultBanner: some View {
        HStack(spacing: 8) {
            Image(systemName: locationManager.territoryValidationPassed
                  ? "checkmark.circle.fill"
                  : "xmark.circle.fill")
                .font(.body)

            if locationManager.territoryValidationPassed {
                Text("圈地成功！领地面积: \(String(format: "%.0f", locationManager.calculatedArea))m²")
                    .font(.subheadline)
                    .fontWeight(.medium)
            } else {
                Text(locationManager.territoryValidationError ?? "验证失败")
                    .font(.subheadline)
                    .fontWeight(.medium)
            }
        }
        .foregroundColor(.white)
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .frame(maxWidth: .infinity)
        .background(locationManager.territoryValidationPassed ? Color.green : Color.red)
        .cornerRadius(12)
        .padding(.top, 50)
    }

    // MARK: - Speed Warning Banner
    /// 速度警告横幅
    private func speedWarningBanner(warning: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 20))
                .foregroundColor(.white)

            Text(warning)
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(.white)
                .lineLimit(2)

            Spacer()
        }
        .padding()
        .background(locationManager.isTracking ? ApocalypseTheme.warning : ApocalypseTheme.danger)
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.3), radius: 8, x: 0, y: 4)
        .onAppear {
            // 3 秒后自动隐藏警告
            DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                locationManager.speedWarning = nil
            }
        }
    }
}

#Preview {
    MapTabView()
}
