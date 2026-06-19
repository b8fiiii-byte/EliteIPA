//
//  Models.swift
//  نماذج البيانات الأساسية للتطبيق
//

import Foundation

/// حزمة تطبيق مستوردة (IPA)
struct AppPackage: Identifiable, Codable, Hashable {
    var id: UUID = UUID()
    var displayName: String          // اسم التطبيق
    var bundleId: String             // المعرف
    var version: String              // الإصدار
    var iconFileName: String?        // مسار الأيقونة المستخرجة
    var ipaFileName: String          // اسم ملف الـ IPA المخزن
    var fileSizeBytes: Int64         // حجم الملف
    var isSigned: Bool = false       // هل تم توقيعه
    var importedAt: Date = Date()

    var fileSizeReadable: String {
        ByteCountFormatter.string(fromByteCount: fileSizeBytes, countStyle: .file)
    }
}

/// شهادة توقيع (p12 + mobileprovision)
struct SigningCertificate: Identifiable, Codable, Hashable {
    var id: UUID = UUID()
    var name: String                 // اسم الشهادة المعروض
    var p12FileName: String          // ملف p12 المخزن
    var provisionFileName: String    // ملف mobileprovision المخزن
    var teamId: String?              // معرّف الفريق
    var expiryDate: Date?            // تاريخ الانتهاء
    var status: CertificateStatus = .unknown
    var isActive: Bool = false       // هل هي الشهادة المفعّلة
    var importedAt: Date = Date()

    /// كلمة السر تُخزّن في الـ Keychain وليست هنا
    var keychainKey: String { "cert_pwd_\(id.uuidString)" }
}

/// حالة الشهادة بعد الفحص
enum CertificateStatus: String, Codable {
    case valid       // صالحة
    case revoked     // مقفلة من Apple
    case expired     // منتهية
    case unknown     // لم تُفحص بعد

    var arabicLabel: String {
        switch self {
        case .valid: return "صالحة"
        case .revoked: return "مقفلة"
        case .expired: return "منتهية"
        case .unknown: return "غير معروفة"
        }
    }
}

/// خيارات التوقيع التي يحددها المستخدم
struct SigningOptions {
    var newDisplayName: String?
    var newBundleId: String?
    var newIconPath: String?         // أيقونة جديدة من ألبوم الصور
    var dylibsToInject: [String] = []
    var enableFileSharing: Bool = true
    var removeExtensions: Bool = false
}

/// عنصر ملف داخل مدير الملفات
struct FileItem: Identifiable, Hashable {
    var id: String { path }
    var name: String
    var path: String
    var isDirectory: Bool
    var sizeBytes: Int64
    var modifiedAt: Date

    var sizeReadable: String {
        isDirectory ? "—" : ByteCountFormatter.string(fromByteCount: sizeBytes, countStyle: .file)
    }

    var fileExtension: String {
        (name as NSString).pathExtension.lowercased()
    }
}
