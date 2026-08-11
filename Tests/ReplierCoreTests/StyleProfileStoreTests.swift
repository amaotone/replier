import Foundation
import Testing
@testable import ReplierCore

private final class TickCounter: @unchecked Sendable {
    private var value = 0
    private let lock = NSLock()

    func next() -> Int {
        lock.lock()
        defer { lock.unlock() }
        let current = value
        value += 1
        return current
    }
}

@Suite struct StyleProfileStoreTests {
    private func makeTempDirectory() -> URL {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("StyleProfileStoreTests-\(UUID().uuidString)", isDirectory: true)
        return url
    }

    private func cleanup(_ url: URL) {
        try? FileManager.default.removeItem(at: url)
    }

    @Test func freshStoreHasNoSamples() async throws {
        let dir = makeTempDirectory()
        defer { cleanup(dir) }
        let store = StyleProfileStore(directory: dir)

        #expect(try await store.samples().isEmpty)
        #expect(try await store.profile().samples.isEmpty)
    }

    @Test func addPersistsAndRoundTripsThroughNewInstance() async throws {
        let dir = makeTempDirectory()
        defer { cleanup(dir) }
        let store = StyleProfileStore(directory: dir)

        let before = Date()
        let sample = try await store.add("Thanks for reaching out!")
        let after = Date()

        #expect(sample.text == "Thanks for reaching out!")
        #expect(sample.createdAt >= before)
        #expect(sample.createdAt <= after)

        let samples = try await store.samples()
        #expect(samples.count == 1)
        #expect(samples[0] == sample)

        let reloaded = StyleProfileStore(directory: dir)
        let reloadedSamples = try await reloaded.samples()
        #expect(reloadedSamples == [sample])
    }

    @Test func multipleAddsOrderNewestFirst() async throws {
        let dir = makeTempDirectory()
        defer { cleanup(dir) }

        let counter = TickCounter()
        let base = Date(timeIntervalSince1970: 1_700_000_000)
        let store = StyleProfileStore(directory: dir, clock: {
            base.addingTimeInterval(TimeInterval(counter.next()))
        })

        let first = try await store.add("first")
        let second = try await store.add("second")
        let third = try await store.add("third")

        let samples = try await store.samples()
        #expect(samples.map(\.id) == [third.id, second.id, first.id])
        #expect(samples.map(\.text) == ["third", "second", "first"])
    }

    @Test func removeExistingIdDeletesAfterReload() async throws {
        let dir = makeTempDirectory()
        defer { cleanup(dir) }
        let store = StyleProfileStore(directory: dir)

        let sample = try await store.add("to be removed")
        try await store.remove(id: sample.id)

        #expect(try await store.samples().isEmpty)

        let reloaded = StyleProfileStore(directory: dir)
        #expect(try await reloaded.samples().isEmpty)
    }

    @Test func removeUnknownIdIsNoOp() async throws {
        let dir = makeTempDirectory()
        defer { cleanup(dir) }
        let store = StyleProfileStore(directory: dir)

        let sample = try await store.add("keep me")
        try await store.remove(id: UUID())

        let samples = try await store.samples()
        #expect(samples == [sample])
    }

    @Test func corruptedFileIsQuarantinedAndTreatedAsEmpty() async throws {
        let dir = makeTempDirectory()
        defer { cleanup(dir) }
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)

        let samplesURL = dir.appendingPathComponent("samples.json")
        let garbage = Data("not valid json {{{".utf8)
        try garbage.write(to: samplesURL)

        let store = StyleProfileStore(directory: dir)
        let samples = try await store.samples()
        #expect(samples.isEmpty)

        let backupURL = dir.appendingPathComponent("samples.json.bak")
        #expect(FileManager.default.fileExists(atPath: backupURL.path))
        let backupContents = try Data(contentsOf: backupURL)
        #expect(backupContents == garbage)
    }

    @Test func corruptedFileOverwritesOlderBackup() async throws {
        let dir = makeTempDirectory()
        defer { cleanup(dir) }
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)

        let samplesURL = dir.appendingPathComponent("samples.json")
        let backupURL = dir.appendingPathComponent("samples.json.bak")
        try Data("old backup".utf8).write(to: backupURL)

        let garbage = Data("still not json".utf8)
        try garbage.write(to: samplesURL)

        let store = StyleProfileStore(directory: dir)
        _ = try await store.samples()

        let backupContents = try Data(contentsOf: backupURL)
        #expect(backupContents == garbage)
    }

    @Test func profileMapsTextsInSameOrderAsSamples() async throws {
        let dir = makeTempDirectory()
        defer { cleanup(dir) }

        let counter = TickCounter()
        let base = Date(timeIntervalSince1970: 1_700_000_000)
        let store = StyleProfileStore(directory: dir, clock: {
            base.addingTimeInterval(TimeInterval(counter.next()))
        })

        _ = try await store.add("alpha")
        _ = try await store.add("beta")
        _ = try await store.add("gamma")

        let samples = try await store.samples()
        let profile = try await store.profile()

        #expect(profile.samples == samples.map(\.text))
        #expect(profile.samples == ["gamma", "beta", "alpha"])
    }
}
