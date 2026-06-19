//
//  InstallService.swift
//  التثبيت المباشر من داخل التطبيق (بدون أي واجهة خارجية)
//
//  يعتمد على مسارين:
//  1) مسار الجيلبريك المباشر: استدعاء أوامر النظام (installer / AppSync) عبر Process.
//     هذا هو المسار الأساسي ويثبّت التطبيق فوراً داخلياً دون فتح Safari.
//  2) مسار itms-services الداخلي عبر سيرفر HTTPS محلي كاحتياطي.
//

import Foundation
import UIKit

final class InstallService {
    static let shared = InstallService()
    private init() {}

    enum InstallError: LocalizedError {
        case extractionFailed
        case installerFailed(String)
        case notJailbroken

        var errorDescription: String? {
            switch self {
            case .extractionFailed: return "فشل استخراج محتوى الـ IPA."
            case .installerFailed(let msg): return "فشل التثبيت: \(msg)"
            case .notJailbroken: return "هذه الميزة تتطلب جهاز جيلبريك."
            }
        }
    }

    /// التثبيت المباشر داخل التطبيق على أجهزة الجيلبريك
    /// يستخدم أداة سطر الأوامر الخاصة بالجيلبريك لتثبيت الـ IPA فوراً.
    func installDirectly(ipaURL: URL,
                         progress: @escaping (Double, String) -> Void) async throws {
        progress(0.2, "جارٍ التحقق من صلاحيات النظام...")

        guard JailbreakHelper.isJailbroken else {
            throw InstallError.notJailbroken
        }

        progress(0.5, "جارٍ التثبيت داخل التطبيق...")

        // على أجهزة الجيلبريك: استدعاء أداة التثبيت مباشرة.
        // appinst / installipa أدوات شائعة تأتي مع AppSync Unified.
        let candidates = ["/usr/bin/appinst", "/usr/bin/installipa", "/usr/local/bin/appinst"]
        guard let tool = candidates.first(where: { FileManager.default.fileExists(atPath: $0) }) else {
            // الرجوع إلى المسار الاحتياطي (سيرفر محلي + itms-services)
            try await LocalInstallServer.shared.install(ipaURL: ipaURL, progress: progress)
            return
        }

        let result = try JailbreakHelper.run(tool: tool, args: [ipaURL.path])
        if result.exitCode != 0 {
            throw InstallError.installerFailed(result.output)
        }
        progress(1.0, "تم التثبيت بنجاح")
    }
}

/// مساعد للتعامل مع بيئة الجيلبريك
enum JailbreakHelper {
    /// كشف الجيلبريك
    static var isJailbroken: Bool {
        #if targetEnvironment(simulator)
        return false
        #else
        let paths = ["/Applications/Cydia.app", "/usr/sbin/sshd",
                     "/bin/bash", "/usr/bin/appinst", "/var/jb"]
        return paths.contains { FileManager.default.fileExists(atPath: $0) }
        #endif
    }

    struct ProcessResult { let exitCode: Int32; let output: String }

    /// تنفيذ أمر نظام (متاح فقط على أجهزة الجيلبريك بصلاحيات كافية)
    static func run(tool: String, args: [String]) throws -> ProcessResult {
        let task = Process()
        task.executableURL = URL(fileURLWithPath: tool)
        task.arguments = args
        let pipe = Pipe()
        task.standardOutput = pipe
        task.standardError = pipe
        try task.run()
        task.waitUntilExit()
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        let output = String(data: data, encoding: .utf8) ?? ""
        return ProcessResult(exitCode: task.terminationStatus, output: output)
    }
}
