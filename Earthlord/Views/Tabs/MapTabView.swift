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
    @StateObject private var locationManager = LocationManager()

    // MARK: - State Properties
    @State private var hasLocatedUser = false  // 是否已完成首次定位

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

            // 右下角定位按钮（仅在已授权时显示）
            if locationManager.isAuthorized {
                VStack {
                    Spacer()
                    HStack {
                        Spacer()
                        recenterButton
                            .padding(.trailing, 20)
                            .padding(.bottom, 40)
                    }
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
        MapViewRepresentable(
            userLocation: $locationManager.userLocation,
            hasLocatedUser: $hasLocatedUser
        )
        .ignoresSafeArea()
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
}

#Preview {
    MapTabView()
}
