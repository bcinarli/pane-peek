import AppKit

#if !PANEPEEK_APP_STORE
@MainActor final class GitHubUpdateProvider: UpdateProvider {
    private let installed: ReleaseVersion
    private let transport: UpdateTransport
    private let storage: UpdateStorage
    private var candidate: GitHubUpdate?
    private var prepared: [UUID: (url: URL, digest: String)] = [:]
    private var receipts: [String: PreparedUpdate] = [:]
    private let now: () -> Date
    private var checkedAt: Date?
    private var retryAfter = Date.distantPast

    init(installed: ReleaseVersion, transport: UpdateTransport = UpdateTransport(), storage: UpdateStorage,
         now: @escaping () -> Date = Date.init) {
        self.installed = installed
        self.transport = transport
        self.storage = storage
        self.now = now
    }

    func check() async throws -> UpdateOffer? {
        try Task.checkCancellation()
        guard now() >= retryAfter else { throw UpdateError.rateLimited(retryAfter) }
        if let checkedAt, now().timeIntervalSince(checkedAt) < 60 { return candidate?.offer }
        do {
            let response = try await transport.fetch(.metadata)
            let release: GitHubRelease
            do { release = try JSONDecoder().decode(GitHubRelease.self, from: response.data) }
            catch { throw UpdateError.invalidRelease }
            let found = try release.select(installed: installed)
            try Task.checkCancellation()
            candidate = found
            checkedAt = now()
            return found?.offer
        } catch UpdateError.rateLimited(let date) { retryAfter = date; throw UpdateError.rateLimited(date) }
    }

    func prepare(_ offer: UpdateOffer, progress: @escaping @Sendable (Double?) -> Void) async throws -> PreparedUpdate {
        guard let candidate, candidate.offer == offer else { throw UpdateError.invalidRelease }
        if let existing = receipts[offer.id] { return existing }
        let staging = try storage.staging(size: candidate.size)
        var ownedURL = staging
        var completed = false
        defer { if !completed { try? FileManager.default.removeItem(at: ownedURL) } }
        let response = try await transport.fetch(.download(candidate.url), maximumBytes: UpdateTransport.maximumDownloadBytes,
            to: staging, expectedBytes: candidate.size, progress: progress)
        guard response.digest == candidate.digest else { throw UpdateError.validation }
        try Task.checkCancellation()
        try await UpdateInstaller.validate(staging, digest: candidate.digest)
        try Task.checkCancellation()
        let destination = storage.root.appendingPathComponent("\(UUID()).dmg")
        try FileManager.default.moveItem(at: staging, to: destination)
        ownedURL = destination
        try FileManager.default.setAttributes([.posixPermissions: 0o400], ofItemAtPath: destination.path)
        let receipt = PreparedUpdate(id: UUID(), title: "Installer opened",
            message: "Quit PanePeek, then drag PanePeek to Applications.", reopenTitle: "Open installer again")
        prepared[receipt.id] = (destination, candidate.digest)
        receipts[offer.id] = receipt
        completed = true
        return receipt
    }

    func perform(_ update: PreparedUpdate) async throws {
        guard let installer = prepared[update.id] else { throw UpdateError.validation }
        try await UpdateInstaller.validate(installer.url, digest: installer.digest)
        try Task.checkCancellation()
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, any Error>) in
            NSWorkspace.shared.open([installer.url], withApplicationAt: URL(fileURLWithPath: "/System/Library/CoreServices/DiskImageMounter.app"),
                                    configuration: NSWorkspace.OpenConfiguration()) { running, error in
                if running != nil && error == nil { continuation.resume() }
                else { continuation.resume(throwing: UpdateError.opening) }
            }
        }
    }
}

#endif

@MainActor enum UpdateComposition {
    static func make(in bundle: Bundle = .main, preferences: UserDefaults = .standard) -> AppUpdates {
        #if PANEPEEK_APP_STORE
        return AppUpdates(provider: nil)
        #else
        guard UpdateChannel.isEnabled(bundle.object(forInfoDictionaryKey: "PanePeekUpdateChannel") as? String),
              let version = bundle.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String,
              let build = bundle.object(forInfoDictionaryKey: "CFBundleVersion") as? String, let number = Int(build),
              let installed = ReleaseVersion(version, build: number) else { return AppUpdates(provider: nil) }
        let root = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("PanePeek/updates", isDirectory: true)
        return AppUpdates(provider: GitHubUpdateProvider(installed: installed, storage: UpdateStorage(root: root)), preferences: preferences)
        #endif
    }
}
