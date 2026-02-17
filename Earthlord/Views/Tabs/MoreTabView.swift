//
//  MoreTabView.swift
//  Earthlord
//
//  Created by 许意晗 on 2026/2/8.
//

import SwiftUI

struct MoreTabView: View {
    @EnvironmentObject var locationManager: LocationManager

    var body: some View {
        NavigationView {
            TestMenuView()
                .environmentObject(locationManager)
        }
    }
}

#Preview {
    MoreTabView()
}
