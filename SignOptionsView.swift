//
//  SignOptionsView.swift
//  خيارات التوقيع: تعديل الاسم، الأيقونة، البندل، حقن dylib، ثم زر التوقيع والتثبيت الأخضر
//

import SwiftUI
import PhotosUI

struct SignOptionsView: View {
    let app: AppPackage
    @EnvironmentObject var appState: AppState
    @Environment(\.dismiss) private var dismiss

    @State private var displayName: String
    @State private var bundleId: String
    @State private var dylibPath: String = ""
    @State private var pickedIcon: PhotosPickerItem?
    @State private var iconImage: UIImage?
    @State private var iconPath: String?

    @State private var isWorking = false
    @State private var progress: Double = 0
    @State private var statusText = ""
    @State private var resultMessage: String?
    @State private var signedIPA: URL?

    init(app: AppPackage) {
        self.app = app
        _displayName = State(initialValue: app.displayName)
        _bundleId = State(initialValue: app.bundleId)
    }

    var body: some View {
        ZStack {
            Theme.backgroundGradient.ignoresSafeArea()
            ScrollView {
                VStack(spacing: 16) {
                    // الاسم
                    fieldCard(title: "اسم التطبيق", systemImage: "textformat") {
                        TextField("الاسم", text: $displayName)
                            .foregroundColor(Theme.textPrimary)
                    }
                    // الأيقونة من ألبوم الصور
                    PhotosPicker(selection: $pickedIcon, matching: .images) {
                        HStack(spacing: 14) {
                            Image(systemName: "photo.fill").foregroundColor(Theme.accent).frame(width: 28)
                            Text("تغيير الأيقونة من الألبوم").foregroundColor(Theme.textPrimary)
                            Spacer()
                            if let img = iconImage {
                                Image(uiImage: img).resizable().frame(width: 40, height: 40)
                                    .clipShape(RoundedRectangle(cornerRadius: 8))
                            }
                        }
                        .padding().glassCard()
                    }
                    // البندل
                    fieldCard(title: "Bundle ID", systemImage: "number") {
                        TextField("com.example.app", text: $bundleId)
                            .foregroundColor(Theme.textPrimary)
                            .autocorrectionDisabled().textInputAutocapitalization(.never)
                    }
                    // حقن dylib
                    fieldCard(title: "حقن مكتبة (Dylib) — اختياري", systemImage: "syringe.fill") {
                        TextField("مسار ملف .dylib", text: $dylibPath)
                            .foregroundColor(Theme.textPrimary)
                            .autocorrectionDisabled().textInputAutocapitalization(.never)
                    }

                    // حالة الشهادة
                    certificateStatusCard

                    if isWorking {
                        VStack(spacing: 8) {
                            ProgressView(value: progress).tint(Theme.accentGreen)
                            Text(statusText).font(.caption).foregroundColor(Theme.textSecondary)
                        }.padding().glassCard()
                    }

                    // زر التوقيع والتثبيت الأخضر
                    Button(action: signAndInstall) {
                        HStack {
                            Image(systemName: "checkmark.seal.fill")
                            Text("توقيع وتثبيت مباشر")
                        }
                        .font(.headline).foregroundColor(.white)
                        .frame(maxWidth: .infinity).padding()
                        .background(Theme.accentGreen)
                        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                    }
                    .disabled(isWorking || appState.activeCertificate == nil)
                    .opacity((isWorking || appState.activeCertificate == nil) ? 0.5 : 1)
                }
                .padding()
            }
        }
        .navigationTitle("توقيع \(app.displayName)")
        .navigationBarTitleDisplayMode(.inline)
        .onChange(of: pickedIcon) { _, newValue in loadIcon(newValue) }
        .alert("النتيجة", isPresented: Binding(get: { resultMessage != nil }, set: { if !$0 { resultMessage = nil } })) {
            Button("تم") { resultMessage = nil }
            if signedIPA != nil {
                Button("تصدير الـ IPA") { exportIPA() }
            }
        } message: { Text(resultMessage ?? "") }
    }

    @ViewBuilder
    func fieldCard<Content: View>(title: String, systemImage: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Label(title, systemImage: systemImage)
                .font(.caption).foregroundColor(Theme.textSecondary)
            content()
        }
        .padding().frame(maxWidth: .infinity, alignment: .leading).glassCard()
    }

    var certificateStatusCard: some View {
        HStack(spacing: 12) {
            Image(systemName: "checkmark.shield.fill")
                .foregroundColor(appState.activeCertificate?.status == .valid ? Theme.accentGreen : Theme.danger)
            VStack(alignment: .leading) {
                if let cert = appState.activeCertificate {
                    Text("الشهادة: \(cert.name)").foregroundColor(Theme.textPrimary).font(.subheadline)
                    Text("الحالة: \(cert.status.arabicLabel)").font(.caption).foregroundColor(Theme.textSecondary)
                } else {
                    Text("لا توجد شهادة مفعّلة").foregroundColor(Theme.danger).font(.subheadline)
                    Text("أضف شهادة من الإعدادات أولاً").font(.caption).foregroundColor(Theme.textSecondary)
                }
            }
            Spacer()
        }
        .padding().glassCard()
    }

    func loadIcon(_ item: PhotosPickerItem?) {
        guard let item else { return }
        Task {
            if let data = try? await item.loadTransferable(type: Data.self), let img = UIImage(data: data) {
                iconImage = img
                let path = StorageManager.shared.workURL.appendingPathComponent("\(UUID().uuidString).png")
                try? data.write(to: path)
                iconPath = path.path
            }
        }
    }

    func signAndInstall() {
        guard let cert = appState.activeCertificate else { return }
        isWorking = true; progress = 0; statusText = "بدء..."

        var options = SigningOptions()
        options.newDisplayName = displayName != app.displayName ? displayName : nil
        options.newBundleId = bundleId != app.bundleId ? bundleId : nil
        options.newIconPath = iconPath
        if !dylibPath.isEmpty { options.dylibsToInject = [dylibPath] }

        Task {
            do {
                // 1) التوقيع
                let signed = try await SigningService.shared.sign(app: app, certificate: cert, options: options) { p, s in
                    Task { @MainActor in self.progress = p * 0.6; self.statusText = s }
                }
                self.signedIPA = signed

                // 2) التثبيت المباشر داخل التطبيق
                try await InstallService.shared.installDirectly(ipaURL: signed) { p, s in
                    Task { @MainActor in self.progress = 0.6 + p * 0.4; self.statusText = s }
                }

                await MainActor.run {
                    self.isWorking = false
                    self.resultMessage = "تم التوقيع والتثبيت بنجاح داخل التطبيق."
                }
            } catch {
                await MainActor.run {
                    self.isWorking = false
                    self.resultMessage = "فشل: \(error.localizedDescription)"
                }
            }
        }
    }

    func exportIPA() {
        guard let url = signedIPA else { return }
        let av = UIActivityViewController(activityItems: [url], applicationActivities: nil)
        if let scene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let root = scene.windows.first?.rootViewController {
            root.present(av, animated: true)
        }
    }
}
