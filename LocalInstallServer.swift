//
//  LocalInstallServer.swift
//  التثبيت المباشر داخل التطبيق بدون جيلبريك (نفس آلية ESign)
//
//  الفكرة: يشغّل سيرفر HTTPS محلي داخل التطبيق على 127.0.0.1، يقدّم:
//   - ملف الـ IPA الموقّع
//   - ملف manifest.plist
//  ثم يستدعي رابط itms-services داخلياً ليبدأ النظام التثبيت دون فتح Safari.
//

import Foundation
import UIKit

final class LocalInstallServer {
    static let shared = LocalInstallServer()
    private init() {}

    private var server: HTTPServer?

    enum InstallError: LocalizedError {
        case plistMissing
        case serverFailed
        var errorDescription: String? {
            switch self {
            case .plistMissing: return "تعذّر قراءة بيانات التطبيق (Info.plist)."
            case .serverFailed: return "تعذّر تشغيل خادم التثبيت المحلي."
            }
        }
    }

    /// التثبيت الداخلي للـ IPA الموقّع
    func install(ipaURL: URL,
                 progress: @escaping (Double, String) -> Void) async throws {
        progress(0.3, "جارٍ تجهيز خادم التثبيت الداخلي...")

        // 1) استخراج بيانات التطبيق لبناء الـ manifest
        guard let meta = IPAInspector.shared.readMetadata(ipaURL: ipaURL) else {
            throw InstallError.plistMissing
        }

        // 2) تشغيل سيرفر محلي يخدم الـ IPA والـ manifest
        let server = HTTPServer()
        let port = try server.start()
        self.server = server

        let base = "https://127.0.0.1:\(port)"
        let ipaLink = "\(base)/app.ipa"
        let manifestLink = "\(base)/manifest.plist"

        let manifest = Self.buildManifest(ipaURL: ipaLink,
                                          bundleId: meta.bundleId,
                                          version: meta.version,
                                          title: meta.displayName)
        server.route("/app.ipa", fileURL: ipaURL, contentType: "application/octet-stream")
        server.route("/manifest.plist", data: manifest, contentType: "text/xml")

        progress(0.6, "جارٍ بدء التثبيت داخل التطبيق...")

        // 3) استدعاء itms-services داخلياً — يبدأ النظام التثبيت مباشرة فوق التطبيق
        let itms = "itms-services://?action=download-manifest&url=\(manifestLink.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? manifestLink)"
        guard let url = URL(string: itms) else { throw InstallError.serverFailed }

        await MainActor.run {
            // يفتح حوار تثبيت النظام فوق التطبيق نفسه دون مغادرته
            UIApplication.shared.open(url, options: [:], completionHandler: nil)
        }
        progress(1.0, "بدأ التثبيت — وافق على نافذة النظام")
    }

    /// بناء ملف manifest.plist المطلوب لـ itms-services
    static func buildManifest(ipaURL: String, bundleId: String, version: String, title: String) -> Data {
        let xml = """
        <?xml version="1.0" encoding="UTF-8"?>
        <!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
        <plist version="1.0">
        <dict>
          <key>items</key>
          <array>
            <dict>
              <key>assets</key>
              <array>
                <dict>
                  <key>kind</key><string>software-package</string>
                  <key>url</key><string>\(ipaURL)</string>
                </dict>
              </array>
              <key>metadata</key>
              <dict>
                <key>bundle-identifier</key><string>\(bundleId)</string>
                <key>bundle-version</key><string>\(version)</string>
                <key>kind</key><string>software</string>
                <key>title</key><string>\(title)</string>
              </dict>
            </dict>
          </array>
        </dict>
        </plist>
        """
        return Data(xml.utf8)
    }

    func stop() {
        server?.stop()
        server = nil
    }
}
