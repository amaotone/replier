import Foundation

public struct StyleSample: Sendable, Codable, Equatable, Identifiable {
    public let id: UUID
    public var text: String
    public let createdAt: Date

    public init(id: UUID = UUID(), text: String, createdAt: Date = Date()) {
        self.id = id
        self.text = text
        self.createdAt = createdAt
    }
}

/// Stores the user's past-reply writing samples in a local JSON file (`samples.json`).
public actor StyleProfileStore {
    private let directory: URL
    private let samplesFileURL: URL
    private let backupFileURL: URL
    private let clock: @Sendable () -> Date
    private var cachedSamples: [StyleSample]?

    public init(directory: URL) {
        self.init(directory: directory, clock: { Date() })
    }

    /// Internal hook so tests can inject a deterministic clock for `add`.
    init(directory: URL, clock: @escaping @Sendable () -> Date) {
        self.directory = directory
        self.samplesFileURL = directory.appendingPathComponent("samples.json")
        self.backupFileURL = directory.appendingPathComponent("samples.json.bak")
        self.clock = clock
    }

    public static func defaultDirectory() -> URL {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Library/Application Support")
        return base.appendingPathComponent("replier", isDirectory: true)
    }

    public func samples() throws -> [StyleSample] {
        try loadIfNeeded()
        return (cachedSamples ?? []).sorted { $0.createdAt > $1.createdAt }
    }

    @discardableResult
    public func add(_ text: String) throws -> StyleSample {
        try loadIfNeeded()
        let sample = StyleSample(text: text, createdAt: clock())
        var current = cachedSamples ?? []
        current.append(sample)
        try persist(current)
        return sample
    }

    public func remove(id: UUID) throws {
        try loadIfNeeded()
        var current = cachedSamples ?? []
        current.removeAll { $0.id == id }
        try persist(current)
    }

    public func profile() throws -> StyleProfile {
        StyleProfile(samples: try samples().map(\.text))
    }

    private func loadIfNeeded() throws {
        guard cachedSamples == nil else { return }
        guard FileManager.default.fileExists(atPath: samplesFileURL.path) else {
            cachedSamples = []
            return
        }
        let data = try Data(contentsOf: samplesFileURL)
        do {
            cachedSamples = try JSONDecoder().decode([StyleSample].self, from: data)
        } catch {
            try quarantineCorruptedFile()
            cachedSamples = []
        }
    }

    private func quarantineCorruptedFile() throws {
        let fm = FileManager.default
        if fm.fileExists(atPath: backupFileURL.path) {
            try fm.removeItem(at: backupFileURL)
        }
        try fm.moveItem(at: samplesFileURL, to: backupFileURL)
    }

    private func persist(_ samples: [StyleSample]) throws {
        let fm = FileManager.default
        try fm.createDirectory(at: directory, withIntermediateDirectories: true)
        let data = try JSONEncoder().encode(samples)
        let tmpURL = directory.appendingPathComponent(UUID().uuidString + ".tmp")
        try data.write(to: tmpURL)
        if fm.fileExists(atPath: samplesFileURL.path) {
            _ = try fm.replaceItemAt(samplesFileURL, withItemAt: tmpURL)
        } else {
            try fm.moveItem(at: tmpURL, to: samplesFileURL)
        }
        cachedSamples = samples
    }
}
