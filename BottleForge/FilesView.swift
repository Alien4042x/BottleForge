//
//  FilesView.swift
//  BottleForge
//
//  Created by Radim Veselý on 28.03.2025.
//
//  Copyright (c) 2025 Radim Veselý
//
//  This Source Code Form is subject to the terms of the Mozilla Public License, v. 2.0.
//  If a copy of the MPL was not distributed with this file, You can obtain one at https://mozilla.org/MPL/2.0/.
//

import SwiftUI

struct FilesView: View {
    var appState: AppState

    @State private var currentPath: URL? = nil
    @State private var folderContents: [URL] = []
    @State private var pathHistory: [URL] = []
    @State private var selectedItem: URL? = nil


    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("🔍 Bottle File Explorer")
                .font(.title)

            Text("Browse and manage files inside your Wine bottle – similar to Finder.")
                .font(.system(size: 14))
            
            Divider()
            
            HStack {
                Text("📂 Path: \(currentPath?.path ?? "None")")
                    .font(.system(size: 14))
                Spacer()
                Button("🔙 Back") {
                    if !pathHistory.isEmpty {
                        currentPath = pathHistory.removeLast()
                        loadContents()
                    }
                }.disabled(pathHistory.isEmpty)
            }
            .padding([.top, .horizontal])

            List {
                ForEach(folderContents, id: \.self) { item in
                    ClickableRow(
                        onClick: {
                            selectedItem = item
                        },
                        onDoubleClick: {
                            if item.hasDirectoryPath {
                                pathHistory.append(currentPath!)
                                currentPath = item
                                loadContents()
                            } else {
                                NSWorkspace.shared.open(item)
                            }
                        },
                        content: {
                            HStack {
                                FileIconView(url: item)
                                Text(item.lastPathComponent)
                                    .foregroundColor(item == selectedItem ? .accentColor : .primary)
                            }
                            .padding(6)
                            .background(
                                RoundedRectangle(cornerRadius: 6)
                                    .fill(item == selectedItem ? Color.accentColor.opacity(0.15) : Color.clear)
                            )
                        }
                    )
                    .contextMenu {
                        Button("📋 Copy Path") {
                            copyToClipboard(item.path)
                        }
                        Button("🗑️ Delete") {
                            deleteItem(item)
                        }
                        Button("🔍 Reveal in Finder") {
                            NSWorkspace.shared.activateFileViewerSelecting([item])
                        }
                    }
                }
            }
        }
        .onAppear {
            if let bottle = appState.selectedBottle {
                currentPath = bottle.path
                loadContents()
            }
        }
        .onChange(of: appState.selectedBottle) { newValue in
            if let path = newValue?.path {
                #if DEBUG
                print("🔁 Reloading for new bottle path: \(path)")
                #endif
                pathHistory.removeAll()
                currentPath = path
                loadContents()
            }
        }
    }

    private func loadContents() {
        guard let path = currentPath else {
            folderContents = []
            return
        }

        do {
            let contents = try FileManager.default.contentsOfDirectory(at: path, includingPropertiesForKeys: nil)
            folderContents = contents.sorted { $0.lastPathComponent.lowercased() < $1.lastPathComponent.lowercased() }
        } catch {
            #if DEBUG
            print("❌ Error loading contents: \(error)")
            #endif
            folderContents = []
        }
    }

    private func copyToClipboard(_ string: String) {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(string, forType: .string)
    }

    private func deleteItem(_ url: URL) {
        do {
            try FileManager.default.trashItem(at: url, resultingItemURL: nil)
            loadContents()
        } catch {
            #if DEBUG
            print("❌ Couldn't delete item: \(error)")
            #endif
        }
    }
}

// NSImage Resizing Extension
extension NSImage {
    func toImage(size: NSSize) -> NSImage {
        let resized = NSImage(size: size)
        resized.lockFocus()
        self.draw(in: NSRect(origin: .zero, size: size), from: .zero, operation: .copy, fraction: 1.0)
        resized.unlockFocus()
        return resized
    }
}

// Component for icon by file type
struct FileIconView: View {
    let url: URL

    var body: some View {
        let icon = NSWorkspace.shared.icon(forFile: url.path).toImage(size: NSSize(width: 24, height: 24))
        Image(nsImage: icon)
            .resizable()
            .frame(width: 24, height: 24)
    }
}

struct ClickableRow<Content: View>: NSViewRepresentable {
    let onClick: () -> Void
    let onDoubleClick: () -> Void
    let content: () -> Content

    func makeNSView(context: Context) -> NSHostingView<Content> {
        let hostingView = NSHostingView(rootView: content())
        let clickGesture = NSClickGestureRecognizer(target: context.coordinator, action: #selector(Coordinator.handleClick(_:)))
        clickGesture.numberOfClicksRequired = 1
        hostingView.addGestureRecognizer(clickGesture)

        let doubleClickGesture = NSClickGestureRecognizer(target: context.coordinator, action: #selector(Coordinator.handleDoubleClick(_:)))
        doubleClickGesture.numberOfClicksRequired = 2
        hostingView.addGestureRecognizer(doubleClickGesture)

        return hostingView
    }

    func updateNSView(_ nsView: NSHostingView<Content>, context: Context) {
        nsView.rootView = content()
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(onClick: onClick, onDoubleClick: onDoubleClick)
    }

    class Coordinator: NSObject {
        let onClick: () -> Void
        let onDoubleClick: () -> Void

        init(onClick: @escaping () -> Void, onDoubleClick: @escaping () -> Void) {
            self.onClick = onClick
            self.onDoubleClick = onDoubleClick
        }

        @objc func handleClick(_ sender: NSClickGestureRecognizer) {
            if sender.numberOfClicksRequired == 1 {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                    if sender.state == .ended {
                        self.onClick()
                    }
                }
            }
        }

        @objc func handleDoubleClick(_ sender: NSClickGestureRecognizer) {
            if sender.numberOfClicksRequired == 2 {
                self.onDoubleClick()
            }
        }
    }
}
