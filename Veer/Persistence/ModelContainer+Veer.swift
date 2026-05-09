import Foundation
import SwiftData

enum VeerStore {
    static let schema = Schema([ClipItem.self, PayloadBlob.self])

    static func live() throws -> ModelContainer {
        let url = try liveStoreURL()
        let configuration = ModelConfiguration(schema: schema, url: url)
        return try ModelContainer(for: schema, configurations: [configuration])
    }

    static func inMemory() throws -> ModelContainer {
        let configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        return try ModelContainer(for: schema, configurations: [configuration])
    }

    private static func liveStoreURL() throws -> URL {
        let fm = FileManager.default
        let support = try fm.url(
            for: .applicationSupportDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        )
        let bundleId = Bundle.main.bundleIdentifier ?? "com.veer.app"
        let dir = support.appendingPathComponent(bundleId, isDirectory: true)
        if !fm.fileExists(atPath: dir.path) {
            try fm.createDirectory(at: dir, withIntermediateDirectories: true)
        }
        return dir.appendingPathComponent("ClipHistory.store")
    }
}
