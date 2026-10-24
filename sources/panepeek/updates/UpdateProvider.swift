import Foundation

/// App-facing update data. Provider URLs and installer formats remain in the adapter.
struct UpdateOffer: Equatable, Sendable {
    let id: String
    let version: String
    let installedVersion: String
    let actionTitle: String
    let actionHelp: String
    let progressTitle: String
}

struct PreparedUpdate: Equatable, Sendable {
    let id: UUID
    let title: String
    let message: String
    let reopenTitle: String
}

@MainActor protocol UpdateProvider: AnyObject {
    func check() async throws -> UpdateOffer?
    func prepare(_ offer: UpdateOffer, progress: @escaping @Sendable (Double?) -> Void) async throws -> PreparedUpdate
    func perform(_ update: PreparedUpdate) async throws
}

enum UpdateChannel {
    static func isEnabled(_ marker: String?) -> Bool { marker == "github" }
}

enum UpdateError: LocalizedError {
    case invalidRelease, transport, tooLarge, incomplete, storage, validation, opening
    case rateLimited(Date)

    var errorDescription: String? {
        switch self {
        case .invalidRelease: "A compatible update could not be verified. Try again later."
        case .transport: "Couldn’t reach the update service. Check your connection and try again."
        case .tooLarge: "The update exceeds the download limit."
        case .incomplete: "The download was incomplete. Try again."
        case .storage: "There isn’t enough space for the update in PanePeek’s download storage."
        case .validation: "The installer could not be verified. It has not been opened."
        case .opening: "The installer couldn’t be opened. Try opening it again."
        case .rateLimited(let date): "Update checks are temporarily limited. Try again after \(date.formatted(date: .omitted, time: .shortened))."
        }
    }
}
