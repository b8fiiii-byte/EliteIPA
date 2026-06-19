//
//  SettingsView.swift
//  الإعدادات: استرداد الشهادة، استرداد IPA، إدارة الشهادات، وقناة تيليجرام (آخر القائمة)
//

import SwiftUI

struct SettingsView: View {
    @EnvironmentObject var appState: AppState
    @StateObject private var vm = SettingsViewModel()

    private let telegramURL = URL(string: "https://t.me/EliteIPA")!

    var body: some View {
        NavigationStack {
            ZStack {
                Theme.backgroundGradient.ignoresSafeArea()
                ScrollView {
                    VStack(spacing: 16) {
                        // استرداد الشهادة
                        OptionButton(icon: "key.fill", title: "استرداد الشهادة (.p12 + provision)", color: Theme.accent) {
                            vm.showCertImporter = true
                        }
                        // استرداد التطبيقات IPA
                        OptionButton(icon: "square.and.arrow.down.fill", title: "استرداد تطبيق (IPA)", color: .orange) {
                            vm.showIPAImporter = true
                        }

                        // الشهادات المخزّنة
                        if !appState.certificates.isEmpty {
                            VStack(alignment: .leading, spacing: 10) {
                                Text("الشهادات").font(.caption).foregroundColor(Theme.textSecondary)
                                ForEach(appState.certificates) { cert in
                                    CertRow(cert: cert,
                                            onActivate: { vm.activate(cert, appState: appState) },
                                            onCheck: { vm.check(cert, appState: appState) },
                                            onDelete: { vm.delete(cert, appState: appState) })
                                }
                            }.padding().glassCard()
                        }

                        OptionButton(icon: "trash.fill", title: "مسح الملفات المؤقتة", color: Theme.danger) {
                            vm.clearCache()
                        }

                        // قناة تيليجرام — آخر خيار في القائمة
                        Link(destination: telegramURL) {
                            HStack(spacing: 14) {
                                Image(systemName: "paperplane.fill").foregroundColor(Theme.accent).frame(width: 28)
                                VStack(alignment: .leading) {
                                    Text("قناتي تيليجرام").foregroundColor(Theme.textPrimary)
                                    Text("t.me/EliteIPA").font(.caption).foregroundColor(Theme.textSecondary)
                                }
                                Spacer()
                                Image(systemName: "arrow.up.left.square.fill").foregroundColor(Theme.textSecondary)
                            }
                            .padding().glassCard()
                        }

                        Text("Elite IPA • الإصدار 1.0").font(.caption2).foregroundColor(Theme.textSecondary).padding(.top, 8)
                    }
                    .padding()
                }
            }
            .navigationTitle("الإعدادات")
            .fileImporter(isPresented: $vm.showCertImporter, allowedContentTypes: [.item], allowsMultipleSelection: true) { result in
                vm.handleCertImport(result)
            }
            .fileImporter(isPresented: $vm.showIPAImporter, allowedContentTypes: [.item], allowsMultipleSelection: false) { result in
                vm.handleIPAImport(result, appState: appState)
            }
            .alert("كلمة سر الشهادة", isPresented: $vm.askPassword) {
                SecureField("كلمة السر", text: $vm.passwordInput)
                Button("حفظ") { vm.savePassword(appState: appState) }
                Button("إلغاء", role: .cancel) { vm.cancelCertImport() }
            } message: {
                Text("أدخل كلمة سر الشهادة، وسيتم فحص صلاحيتها تلقائياً.")
            }
            .alert(vm.alertTitle, isPresented: $vm.showAlert) {
                Button("حسناً") {}
            } message: { Text(vm.alertMessage) }
        }
    }
}

struct CertRow: View {
    let cert: SigningCertificate
    let onActivate: () -> Void
    let onCheck: () -> Void
    let onDelete: () -> Void

    var statusColor: Color {
        switch cert.status {
        case .valid: return Theme.accentGreen
        case .revoked, .expired: return Theme.danger
        case .unknown: return Theme.textSecondary
        }
    }

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: cert.isActive ? "checkmark.circle.fill" : "circle")
                .foregroundColor(cert.isActive ? Theme.accentGreen : Theme.textSecondary)
                .onTapGesture { onActivate() }
            VStack(alignment: .leading, spacing: 3) {
                Text(cert.name).foregroundColor(Theme.textPrimary).font(.subheadline)
                HStack(spacing: 6) {
                    Circle().fill(statusColor).frame(width: 7, height: 7)
                    Text(cert.status.arabicLabel).font(.caption).foregroundColor(statusColor)
                }
            }
            Spacer()
            Button { onCheck() } label: { Image(systemName: "arrow.clockwise").foregroundColor(Theme.accent) }
            Button { onDelete() } label: { Image(systemName: "trash").foregroundColor(Theme.danger) }
        }
        .padding(.vertical, 6)
    }
}
