enum FindRouting {
    enum Focus: Equatable, Sendable { case browser, document, native, textEntry }
    enum Destination: Equatable, Sendable { case unavailable, folder, document, native }

    struct Decision: Equatable, Sendable {
        let destination: Destination
        let canSearchFolder: Bool
        static let disabled = Decision(destination: .unavailable, canSearchFolder: false)
    }

    static func decide(blocked: Bool, focus: Focus, presentation: FindPresentation, hasDocumentClient: Bool) -> Decision {
        guard !blocked else { return .disabled }
        let destination: Destination
        switch focus {
        case .browser: destination = .folder
        case .native: destination = .native
        case .textEntry: return .disabled
        case .document:
            switch presentation.readiness {
            case .unavailable: destination = .folder
            case .waiting: destination = .unavailable
            case .ready: destination = hasDocumentClient ? .document : .unavailable
            }
        }
        return Decision(destination: destination, canSearchFolder: true)
    }
}
