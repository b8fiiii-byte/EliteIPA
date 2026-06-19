//
//  SettingsViewModel.swift
//

import Foundation
import SwiftUI

@MainActor
final class SettingsViewModel: ObservableObject {
    @Published var showCertImporter = false
    @Published var showIPAImporter = false
    @Published var askPassword = false
    @Published var passwordInput = ""
    @Published var showAlert = false
    @Published var alertTitle = ""
    @Published var alertMessage = ""

    private var pendingP12: URL?
    private var pendingProvision: URL?

    // MARK: - استرداد الشهادة
    func handleCertImport(_ result: Result<[URL], Error>) {
        guard case let .success(urls) = result else { return }
        for url in urls {
            guard url.startAccessingSecurityScopedResource() else { continue }
            defer { url.stopAccessingSecurityScopedResource() }
            let ext = url.pathExtension.lowercased()
            let dest = StorageManager.shared.certsURL.appendingPathComponent(url.lastPathComponent)
            try? FileManager.default.removeItem(at: dest)
            try? FileManager.default.copyItem(at: url, to: dest)
            if ext == "p12" || ext == "pfx" { pendingP12 = dest }
            if ext == "mobileprovision" { pendingProvision = dest }
        }
        if pendingP12 != nil {
            askPassword = true   // التطبيق يطلب كلمة سر الشهادة
        } else {
            alert("تنبيه", "الرجاء اختيار ملف الشهادة (.p12).")
        }
    }

    func savePassword(appState: AppState) {
        guard let p12 = pendingP12 else { return }
        let cert = SigningCertificate(
            name: p12.deletingPathExtension().lastPathComponent,
            p12FileName: p12.lastPathComponent,
            provisionFileName: pendingProvision?.lastPathComponent ?? ""
        )
        // تخزين كلمة السر بأمان في Keychain
        KeychainManager.save(passwordInput, for: cert.keychainKey)
        StorageManager.shared.addCertificate(cert)
        passwordInput = ""
        appState.reload()

        // فحص الصلاحية تلقائياً بعد الإضافة
        check(cert, appState: appState)
        cancelCertImport()
    }

    func cancelCertImport() {
        pendingP12 = nil; pendingProvision = nil; passwordInput = ""
    }

    // MARK: - فحص الشهادة
    func check(_ cert: SigningCertificate, appState: AppState) {
        Task {
            let status = await CertificateChecker.shared.check(certificate: cert)
            var certs = StorageManager.shared.loadCertificates()
            if let i = certs.firstIndex(where: { $0.id == cert.id }) {
                certs[i].status = status
                StorageManager.shared.saveCertificates(certs)
                appState.reload()
            }
            alert("نتيجة الفحص", "حالة الشهادة: \(status.arabicLabel)")
        }
    }

    func activate(_ cert: SigningCertificate, appState: AppState) {
        var certs = StorageManager.shared.loadCertificates()
        for i in certs.indices { certs[i].isActive = (certs[i].id == cert.id) }
        StorageManager.shared.saveCertificates(certs)
        appState.reload()
    }

    func delete(_ cert: SigningCertificate, appState: AppState) {
        var certs = StorageManager.shared.loadCertificates()
        certs.removeAll { $0.id == cert.id }
        StorageManager.shared.saveCertificates(certs)
        KeychainManager.delete(cert.keychainKey)
        appState.reload()
    }

    // MARK: - استرداد IPA
    func handleIPAImport(_ result: Result<[URL], Error>, appState: AppState) {
        guard case let .success(urls) = result, let url = urls.first else { return }
        guard url.startAccessingSecurityScopedResource() else { return }
        defer { url.stopAccessingSecurityScopedResource() }
        let dest = StorageManager.shared.ipaURL.appendingPathComponent(url.lastPathComponent)
        try? FileManager.default.removeItem(at: dest)
        try? FileManager.default.copyItem(at: url, to: dest)
        guard let meta = IPAInspector.shared.readMetadata(ipaURL: dest) else {
            alert("خطأ", "تعذّر قراءة الـ IPA."); return
        }
        var iconName: String?
        if let data = meta.iconData {
            iconName = "\(UUID().uuidString).png"
            try? data.write(to: StorageManager.shared.iconsURL.appendingPathComponent(iconName!))
        }
        let size = (try? FileManager.default.attributesOfItem(atPath: dest.path)[.size] as? Int64) ?? 0
        let app = AppPackage(displayName: meta.displayName, bundleId: meta.bundleId, version: meta.version,
                             iconFileName: iconName, ipaFileName: dest.lastPathComponent, fileSizeBytes: size ?? 0)
        StorageManager.shared.addApp(app)
        appState.reload()
        alert("تم", "تم استرداد التطبيق \"\(meta.displayName)\" إلى مكتبة التطبيقات.")
    }

    func clearCache() {
        let work = StorageManager.shared.workURL
        try? FileManager.default.removeItem(at: work)
        try? FileManager.default.createDirectory(at: work, withIntermediateDirectories: true)
        alert("تم", "تم مسح الملفات المؤقتة.")
    }

    private func alert(_ title: String, _ message: String) {
        alertTitle = title; alertMessage = message; showAlert = true
    }
}
