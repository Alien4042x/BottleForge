//
//  BrewDetection.swift
//  BottleForge
//
//  Created by Radim Veselý on 17.06.2025.
//

func isBrewInstalled() -> Bool {
    let process = Process()
    process.executableURL = URL(fileURLWithPath: "/usr/bin/which")
    process.arguments = ["brew"]

    let pipe = Pipe()
    process.standardOutput = pipe

    do {
        try process.run()
        process.waitUntilExit()

        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        if let output = String(data: data, encoding: .utf8) {
            return !output.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        }
    } catch {
        return false
    }

    return false
}
