//
//  FilesView.swift
//  شاشة مدير الملفات: استعراض، فك ضغط، حذف، إعادة تسمية، إضافة، معاينة
//

import SwiftUI
import UniformTypeIdentifiers

struct FilesView: View {
    @StateObject private var vm = FilesViewModel()
    @State private var showImporter = false
    @State private var renameTarget: FileItem?
    @State private var newName = ""
    @State private var previewTarget: FileItem?

    var body: some View {
        NavigationStack {
            ZStack {
                Theme.backgroundGradient.ignoresSafeArea()
                List {
                    if vm.canGoUp {
                        Button { vm.goUp() } label: {
                            Label("..", systemImage: "arrow.up.left.circle.fill")
                                .foregroundColor(Theme.accent)
                        }
                        .listRowBackground(Theme.surface)
                    }

                    ForEach(vm.items) { item in
                        FileRow(item: item)
                            .listRowBackground(Theme.surface)
                            .contentShape(Rectangle())
                            .onTapGesture { vm.open(item) { previewTarget = $0 } }
                            .swipeActions(edge: .leading) {
                                if item.fileExtension == "zip" || item.fileExtension == "ipa" {
                                    Button { vm.unzip(item) } label: {
                                        Label("فك الضغط", systemImage: "archivebox")
                                    }.tint(Theme.accent)
                                }
                                Button {
                                    renameTarget = item; newName = item.name
                                } label: { Label("تسمية", systemImage: "pencil") }.tint(.orange)
                            }
                            .swipeActions(edge: .trailing) {
                                Button(role: .destructive) { vm.delete(item) } label: {
                                    Label("حذف", systemImage: "trash")
                                }
                            }
                    }
                }
                .scrollContentBackground(.hidden)
            }
            .navigationTitle("الملفات")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button { showImporter = true } label: {
                        Image(systemName: "plus.circle.fill").foregroundColor(Theme.accent)
                    }
                }
            }
            .fileImporter(isPresented: $showImporter, allowedContentTypes: [.item], allowsMultipleSelection: true) { result in
                vm.handleImport(result)
            }
            .alert("إعادة تسمية", isPresented: Binding(get: { renameTarget != nil }, set: { if !$0 { renameTarget = nil } })) {
                TextField("الاسم الجديد", text: $newName)
                Button("حفظ") { if let t = renameTarget { vm.rename(t, to: newName) }; renameTarget = nil }
                Button("إلغاء", role: .cancel) { renameTarget = nil }
            }
            .sheet(item: $previewTarget) { item in
                FilePreviewView(item: item)
            }
        }
    }
}

struct FileRow: View {
    let item: FileItem
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundColor(item.isDirectory ? Theme.accent : Theme.textSecondary)
                .frame(width: 28)
            VStack(alignment: .leading, spacing: 2) {
                Text(item.name).foregroundColor(Theme.textPrimary).lineLimit(1)
                Text(item.sizeReadable).font(.caption).foregroundColor(Theme.textSecondary)
            }
            Spacer()
            if item.isDirectory {
                Image(systemName: "chevron.left").foregroundColor(Theme.textSecondary).font(.caption)
            }
        }
        .padding(.vertical, 4)
    }

    var icon: String {
        if item.isDirectory { return "folder.fill" }
        switch item.fileExtension {
        case "ipa": return "app.badge.fill"
        case "zip": return "archivebox.fill"
        case "p12": return "key.fill"
        case "mobileprovision": return "doc.badge.gearshape.fill"
        case "plist": return "list.bullet.rectangle.fill"
        default: return "doc.fill"
        }
    }
}

struct FilePreviewView: View {
    let item: FileItem
    var body: some View {
        NavigationStack {
            ScrollView {
                Text(FileBrowser.shared.previewText(URL(fileURLWithPath: item.path)))
                    .font(.system(.footnote, design: .monospaced))
                    .foregroundColor(Theme.textPrimary)
                    .padding()
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .background(Theme.background)
            .navigationTitle(item.name)
        }
    }
}
