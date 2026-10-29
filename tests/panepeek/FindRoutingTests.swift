import Foundation
import Testing
@testable import PanePeek

struct FindRoutingTests {
    private static let identity = FindPresentation.Identity(document: UUID(), editing: false)
    private static let presentations: [FindPresentation] = [.unavailable, .waiting(identity), .ready(identity)]
    private static let documentCases: [(FindPresentation, Bool, FindRouting.Destination)] = [
        (.unavailable, false, .folder), (.unavailable, true, .folder),
        (.waiting(identity), false, .unavailable), (.waiting(identity), true, .unavailable),
        (.ready(identity), false, .unavailable), (.ready(identity), true, .document)
    ]

    @Test(arguments: documentCases)
    func documentReadinessDeterminesTheContextualRoute(scenario: (FindPresentation, Bool, FindRouting.Destination)) {
        let decision = FindRouting.decide(blocked: false, focus: .document,
                                          presentation: scenario.0, hasDocumentClient: scenario.1)
        #expect(decision.destination == scenario.2)
        #expect(decision.canSearchFolder)
    }

    @Test(arguments: [(FindRouting.Focus.browser, FindRouting.Destination.folder), (.native, .native)], [false, true])
    func browserAndNativeFocusDoNotDependOnDetails(scenario: (FindRouting.Focus, FindRouting.Destination), client: Bool) {
        for presentation in Self.presentations {
            let decision = FindRouting.decide(blocked: false, focus: scenario.0,
                                              presentation: presentation, hasDocumentClient: client)
            #expect(decision.destination == scenario.1 && decision.canSearchFolder)
        }
    }

    @Test(arguments: [FindRouting.Focus.browser, .document, .native, .textEntry])
    func blockedContextsAndUnrelatedTextEntryCannotRedirectFind(focus: FindRouting.Focus) {
        for presentation in Self.presentations {
            #expect(FindRouting.decide(blocked: true, focus: focus, presentation: presentation, hasDocumentClient: true) == .disabled)
            #expect(FindRouting.decide(blocked: false, focus: .textEntry, presentation: presentation, hasDocumentClient: true) == .disabled)
        }
    }
}
