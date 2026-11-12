import Foundation

enum IncomingRequest: Sendable {
    case native(URL)
    case launcher(LauncherRequest)

    var url: URL {
        switch self {
        case .native(let url): url
        case .launcher(let request): URL(fileURLWithPath: request.path, isDirectory: false)
        }
    }

    var intent: LauncherRequest.Intent {
        if case .launcher(let request) = self { return request.intent }
        return .open
    }

    var requiresDirectory: Bool {
        if case .launcher(let request) = self { return request.requiresDirectory }
        return false
    }

    var carriesNativeAccess: Bool {
        if case .native = self { return true }
        return false
    }
}
