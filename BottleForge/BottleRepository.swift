//
//  BottleRepository.swift
//  BottleForge
//
//  Created by Codex on 09.06.2026.
//

import Foundation

struct BottleRepository {
    static func defaultBottleRoots() -> [(label: String, url: URL)] {
        let home = FileManager.default.homeDirectoryForCurrentUser
        return [
            (
                "CrossOver",
                home.appendingPathComponent("Library/Application Support/CrossOver/Bottles")
            ),
            (
                "CXPatcher",
                home.appendingPathComponent("CXPBottles")
            )
        ]
    }

    static func loadBottles() -> [Bottle] {
        let fileManager = FileManager.default
        var bottles: [Bottle] = []

        for (label, basePath) in defaultBottleRoots() {
            #if DEBUG
            print("🔍 Checking \(label) at: \(basePath.path)")
            #endif

            guard fileManager.fileExists(atPath: basePath.path) else {
                #if DEBUG
                print("🚫 \(label) folder not found")
                #endif
                continue
            }

            do {
                let contents = try fileManager.contentsOfDirectory(
                    at: basePath,
                    includingPropertiesForKeys: [.isDirectoryKey],
                    options: [.skipsHiddenFiles]
                )

                let folders = contents.filter { url in
                    (try? url.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) == true
                }

                #if DEBUG
                print("✅ Found \(folders.count) folders in \(label)")
                #endif

                bottles.append(contentsOf: folders.map { folder in
                    Bottle(name: folder.lastPathComponent, path: folder)
                })
            } catch {
                #if DEBUG
                print("❌ Error reading \(label): \(error)")
                #endif
            }
        }

        return bottles.sorted {
            $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending
        }
    }
}
