//
//  RootTabView.swift
//  الواجهة الرئيسية: ثلاث تبويبات (الملفات، التطبيقات، الإعدادات)
//

import SwiftUI

struct RootTabView: View {
    @State private var selection = 1

    var body: some View {
        ZStack {
            Theme.backgroundGradient.ignoresSafeArea()

            TabView(selection: $selection) {
                FilesView()
                    .tabItem { Label("الملفات", systemImage: "folder.fill") }
                    .tag(0)

                AppLibraryView()
                    .tabItem { Label("التطبيقات", systemImage: "square.grid.2x2.fill") }
                    .tag(1)

                SettingsView()
                    .tabItem { Label("الإعدادات", systemImage: "gearshape.fill") }
                    .tag(2)
            }
            .tint(Theme.accent)
        }
        .environment(\.layoutDirection, .rightToLeft) // دعم العربية RTL
    }
}
