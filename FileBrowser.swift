//
//  FileBrowser.swift
//  منطق مدير الملفات: استعراض، فك ضغط، حذف، إعادة تسمية، إضافة
//

import Foundation
import ZIPFoundation

final class FileBrowser {
    static let shared = FileBrowser()
    private init() {}

    private let fm = FileManager.default

    /// سرد محتويات مجلد
    func list(at url: URL) -> [FileItem] {
        guard let contents = try? fm.contentsOfDirectory(
            at: url,
            includingPropertiesForKeys: [.isDirectoryKey, .fileSizeKey, .contentModificationDateKey],
            options: [.skipsHiddenFiles]
        ) else { return [] }

        return contents.map { item in
            let values = try? item.resourceValues(forKeys: [.isDirectoryKey, .fileSizeKey, .contentModificationDateKey])
            return FileItem(
                name: item.lastPathComponent,
                path: item.path,
                isDirectory: values?.isDirectory ?? false,
                sizeBytes: Int64(values?.fileSize ?? 0),
                modifiedAt: values?.contentModificationDate ?? Date()
            )
        }.sorted { ($0.isDirectory ? 0 : 1, $0.name) < ($1.isDirectory ? 0 : 1, $1.name) }
    }

    /// فك الضغط عن ملف ZIP/IPA
    func unzip(_ fileURL: URL) throws -> URL {
        let dest = fileURL.deletingPathExtension()
        var target = dest
        var i = 1
        while fm.fileExists(atPath: target.path) {
            target = dest.appendingPathExtension("\(i)")
            i += 1
        }
        try fm.createDirectory(at: target, withIntermediateDirectories: true)
        try fm.unzipItem(at: fileURL, to: target)
        return target
    }

    /// حذف ملف أو مجلد
    func delete(_ url: URL) throws {
        try fm.removeItem(at: url)
    }

    /// إعادة تسمية
    func rename(_ url: URL, to newName: String) throws -> URL {
        let dest = url.deletingLastPathComponent().appendingPathComponent(newName)
        try fm.moveItem(at: url, to: dest)
        return dest
    }

    /// نسخ ملف مستورد إلى مجلد العمل
    func importFile(from src: URL, to dir: URL) throws -> URL {
        let dest = dir.appendingPathComponent(src.lastPathComponent)
        if fm.fileExists(atPath: dest.path) { try fm.removeItem(at: dest) }
        try fm.copyItem(at: src, to: dest)
        return dest
    }

    /// قراءة محتوى نصي/سداسي لمعاينة بسيطة
    func previewText(_ url: URL, maxBytes: Int = 8192) -> String {
        guard let handle = try? FileHandle(forReadingFrom: url) else { return "تعذّرت القراءة" }
        let data = handle.readData(ofLength: maxBytes)
        try? handle.close()
        return String(data: data, encoding: .utf8) ?? data.map { String(format: "%02x", $0) }.joined(separator: " ")
    }
}
