//
//  OFFSignApp.swift
//  OFFSign — bديل ESign لأجهزة الجيلبريك
//
//  نقطة دخول التطبيق الرئيسية
//

import SwiftUI

@main
struct OFFSignApp: App {
    @StateObject private var appState = AppState()

    init() {
        // إعداد المجلدات الأساسية عند أول تشغيل
        StorageManager.shared.bootstrap()
    }

    var body: some Scene {
        WindowGroup {
            RootTabView()
                .environmentObject(appState)
                .preferredColorScheme(.dark) // الوضع الداكن افتراضياً
        }
    }
}

/// الحالة العامة للتطبيق التي تتشاركها الواجهات
final class AppState: ObservableObject {
    @Published var importedApps: [AppPackage] = []
    @Published var certificates: [SigningCertificate] = []
    @Published var activeCertificate: SigningCertificate?

    init() {
        reload()
    }

    /// إعادة تحميل البيانات من التخزين
    func reload() {
        importedApps = StorageManager.shared.loadApps()
        certificates = StorageManager.shared.loadCertificates()
        activeCertificate = certificates.first(where: { $0.isActive })
    }
}
