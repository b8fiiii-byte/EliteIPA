//
//  TLSManager.swift
//  توفير خيارات TLS لسيرفر التثبيت المحلي
//
//  ملاحظة تقنية: itms-services يتطلب رابط HTTPS صالحاً. الحل العملي المستخدم
//  في تطبيقات التوقيع هو إما شهادة ذاتية موثوقة محلياً أو الاعتماد على
//  مسار AppSync في أجهزة الجيلبريك. هنا نوفّر بنية TLS قابلة للتوسعة.
//

import Foundation
import Network
import Security

enum TLSManager {
    /// خيارات TLS للسيرفر — تُحمّل هوية (identity) من حزمة الموارد إن وُجدت.
    static func serverTLSOptions() -> NWProtocolTLS.Options {
        let options = NWProtocolTLS.Options()
        if let identity = loadIdentity() {
            sec_protocol_options_set_local_identity(
                options.securityProtocolOptions,
                sec_identity_create(identity)!
            )
        }
        return options
    }

    /// تحميل هوية TLS من ملف p12 مرفق بالتطبيق (server.p12)
    private static func loadIdentity() -> SecIdentity? {
        guard let url = Bundle.main.url(forResource: "server", withExtension: "p12"),
              let data = try? Data(contentsOf: url) else { return nil }
        let options: [String: Any] = [kSecImportExportPassphrase as String: "elite"]
        var items: CFArray?
        guard SecPKCS12Import(data as CFData, options as CFDictionary, &items) == errSecSuccess,
              let array = items as? [[String: Any]],
              let identity = array.first?[kSecImportItemIdentity as String] else {
            return nil
        }
        return (identity as! SecIdentity)
    }
}
