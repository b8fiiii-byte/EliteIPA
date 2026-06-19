//
//  SigningService.swift
//  محرك التوقيع — يستدعي zsign المدمج لتوقيع الـ IPA
//

import Foundation

/// واجهة C الخاصة بـ zsign (تُعرّف في zsign_bridge.h)
/// int zsign_sign(const char* ipa, const char* p12, const char* prov,
///                const char* pwd, const char* output,
///                const char* bundleId, const char* bundleName,
///                const char* iconPath, const char** dylibs, int dylibCount);

final class SigningService {
    static let shared = SigningService()
    private init() {}

    enum SignError: LocalizedError {
        case missingCertificate
        case missingPassword
        case engineFailed(Int)
        case fileNotFound

        var errorDescription: String? {
            switch self {
            case .missingCertificate: return "لا توجد شهادة مفعّلة. الرجاء استيراد شهادة أولاً."
            case .missingPassword: return "كلمة سر الشهادة غير موجودة في Keychain."
            case .engineFailed(let code): return "فشل محرك التوقيع (رمز \(code))."
            case .fileNotFound: return "الملف المطلوب غير موجود."
            }
        }
    }

    /// توقيع تطبيق باستخدام الشهادة المفعّلة والخيارات المحددة
    /// يعيد مسار الـ IPA الموقّع
    func sign(app: AppPackage,
              certificate: SigningCertificate,
              options: SigningOptions,
              progress: @escaping (Double, String) -> Void) async throws -> URL {

        let storage = StorageManager.shared
        let ipaPath = storage.ipaURL.appendingPathComponent(app.ipaFileName)
        let p12Path = storage.certsURL.appendingPathComponent(certificate.p12FileName)
        let provPath = storage.certsURL.appendingPathComponent(certificate.provisionFileName)

        guard FileManager.default.fileExists(atPath: ipaPath.path) else { throw SignError.fileNotFound }
        guard let password = KeychainManager.read(certificate.keychainKey) else { throw SignError.missingPassword }

        let outputName = "\(app.displayName)_signed_\(Int(Date().timeIntervalSince1970)).ipa"
        let outputPath = storage.signedURL.appendingPathComponent(outputName)

        progress(0.1, "جارٍ التحضير...")

        return try await withCheckedThrowingContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                progress(0.3, "جارٍ التوقيع باستخدام المحرك...")

                // تجهيز قائمة المكتبات للحقن
                let dylibs = options.dylibsToInject
                var cDylibs = dylibs.map { strdup($0) }
                cDylibs.append(nil)

                let result = ipaPath.path.withCString { ipaC in
                p12Path.path.withCString { p12C in
                provPath.path.withCString { provC in
                password.withCString { pwdC in
                outputPath.path.withCString { outC in
                    let bundleId = options.newBundleId ?? ""
                    let bundleName = options.newDisplayName ?? ""
                    let iconPath = options.newIconPath ?? ""
                    return bundleId.withCString { bidC in
                    bundleName.withCString { bnC in
                    iconPath.withCString { iconC in
                        zsign_sign(ipaC, p12C, provC, pwdC, outC,
                                   bidC, bnC, iconC,
                                   &cDylibs, Int32(dylibs.count))
                    }}}
                }}}}}

                // تحرير الذاكرة
                for ptr in cDylibs where ptr != nil { free(ptr) }

                progress(0.9, "جارٍ إنهاء العملية...")

                if result == 0 {
                    progress(1.0, "اكتمل التوقيع بنجاح")
                    continuation.resume(returning: outputPath)
                } else {
                    continuation.resume(throwing: SignError.engineFailed(Int(result)))
                }
            }
        }
    }
}
