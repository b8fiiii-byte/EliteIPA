//
//  AppLibraryView.swift
//  شاشة مكتبة التطبيقات: عرض التطبيقات المستوردة + الإحصائيات + خيارات كل تطبيق
//

import SwiftUI

struct AppLibraryView: View {
    @EnvironmentObject var appState: AppState
    @StateObject private var vm = AppLibraryViewModel()

    var body: some View {
        NavigationStack {
            ZStack {
                Theme.backgroundGradient.ignoresSafeArea()
                ScrollView {
                    VStack(spacing: 16) {
                        statsHeader
                        if appState.importedApps.isEmpty {
                            emptyState
                        } else {
                            ForEach(appState.importedApps) { app in
                                NavigationLink {
                                    AppDetailView(app: app)
                                } label: {
                                    AppCardRow(app: app)
                                }
                            }
                        }
                    }
                    .padding()
                }
            }
            .navigationTitle("التطبيقات")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button { vm.showImporter = true } label: {
                        Image(systemName: "plus.circle.fill").foregroundColor(Theme.accent)
                    }
                }
            }
            .fileImporter(isPresented: $vm.showImporter, allowedContentTypes: [.item], allowsMultipleSelection: false) { result in
                vm.importIPA(result, appState: appState)
            }
            .alert(vm.alertTitle, isPresented: $vm.showAlert) {
                Button("نعم") { vm.confirmImport(appState: appState) }
                Button("لا", role: .cancel) { vm.pendingMeta = nil }
            } message: { Text(vm.alertMessage) }
        }
    }

    var statsHeader: some View {
        HStack(spacing: 12) {
            StatBox(title: "التطبيقات", value: "\(appState.importedApps.count)", icon: "square.grid.2x2.fill")
            StatBox(title: "المساحة", value: vm.totalSize(appState.importedApps), icon: "internaldrive.fill")
            StatBox(title: "موقّعة", value: "\(appState.importedApps.filter { $0.isSigned }.count)", icon: "checkmark.seal.fill")
        }
    }

    var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "tray.and.arrow.down.fill")
                .font(.system(size: 48)).foregroundColor(Theme.textSecondary)
            Text("لا توجد تطبيقات بعد").foregroundColor(Theme.textSecondary)
            Text("اضغط + لاستيراد ملف IPA").font(.caption).foregroundColor(Theme.textSecondary)
        }
        .frame(maxWidth: .infinity).padding(.vertical, 60)
    }
}

struct StatBox: View {
    let title: String; let value: String; let icon: String
    var body: some View {
        VStack(spacing: 6) {
            Image(systemName: icon).foregroundColor(Theme.accent)
            Text(value).font(.headline).foregroundColor(Theme.textPrimary)
            Text(title).font(.caption2).foregroundColor(Theme.textSecondary)
        }
        .frame(maxWidth: .infinity).padding(.vertical, 14).glassCard()
    }
}

struct AppCardRow: View {
    let app: AppPackage
    var body: some View {
        HStack(spacing: 14) {
            AppIconView(fileName: app.iconFileName)
            VStack(alignment: .leading, spacing: 4) {
                Text(app.displayName).font(.headline).foregroundColor(Theme.textPrimary)
                Text(app.bundleId).font(.caption).foregroundColor(Theme.textSecondary).lineLimit(1)
                HStack(spacing: 8) {
                    Text("v\(app.version)").font(.caption2).foregroundColor(Theme.textSecondary)
                    Text(app.fileSizeReadable).font(.caption2).foregroundColor(Theme.textSecondary)
                    if app.isSigned {
                        Label("موقّع", systemImage: "checkmark.seal.fill")
                            .font(.caption2).foregroundColor(Theme.accentGreen)
                    }
                }
            }
            Spacer()
            Image(systemName: "chevron.left").foregroundColor(Theme.textSecondary)
        }
        .padding().glassCard()
    }
}

struct AppIconView: View {
    let fileName: String?
    var body: some View {
        Group {
            if let name = fileName,
               let img = UIImage(contentsOfFile: StorageManager.shared.iconsURL.appendingPathComponent(name).path) {
                Image(uiImage: img).resizable()
            } else {
                Image(systemName: "app.dashed").resizable().foregroundColor(Theme.textSecondary).padding(8)
            }
        }
        .frame(width: 54, height: 54)
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Theme.stroke, lineWidth: 1))
    }
}
