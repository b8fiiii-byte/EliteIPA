//
//  FilesViewModel.swift
//

import Foundation
import SwiftUI

@MainActor
final class FilesViewModel: ObservableObject {
    @Published var items: [FileItem] = []
    @Published var currentURL: URL
    @Published var errorMessage: String?

    private let rootURL: URL

    init() {
        rootURL = StorageManager.shared.documentsURL
        currentURL = rootURL
        refresh()
    }

    var canGoUp: Bool { currentURL.path != rootURL.path }

    func refresh() {
        items = FileBrowser.shared.list(at: currentURL)
    }

    func open(_ item: FileItem, preview: (FileItem) -> Void) {
        if item.isDirectory {
            currentURL = URL(fileURLWithPath: item.path)
            refresh()
        } else {
            preview(item)
        }
    }

    func goUp() {
        currentURL = currentURL.deletingLastPathComponent()
        refresh()
    }

    func unzip(_ item: FileItem) {
        do {
            _ = try FileBrowser.shared.unzip(URL(fileURLWithPath: item.path))
            refresh()
        } catch { errorMessage = error.localizedDescription }
    }

    func delete(_ item: FileItem) {
        do { try FileBrowser.shared.delete(URL(fileURLWithPath: item.path)); refresh() }
        catch { errorMessage = error.localizedDescription }
    }

    func rename(_ item: FileItem, to name: String) {
        do { _ = try FileBrowser.shared.rename(URL(fileURLWithPath: item.path), to: name); refresh() }
        catch { errorMessage = error.localizedDescription }
    }

    func handleImport(_ result: Result<[URL], Error>) {
        guard case let .success(urls) = result else { return }
        for url in urls {
            guard url.startAccessingSecurityScopedResource() else { continue }
            defer { url.stopAccessingSecurityScopedResource() }
            _ = try? FileBrowser.shared.importFile(from: url, to: currentURL)
        }
        refresh()
    }
}
