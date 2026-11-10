import Foundation
import Testing
import PanePeekCore
@testable import PanePeek

@Suite(.serialized) @MainActor
struct PreviewCatalogueTests {
    @Test func eachBuiltInHasOneStableRegistration() {
        let registrations = BuiltInPreviewCatalogue.registrations
        #expect(Set(registrations.map(\.id)) == Set(BuiltInPreviewCatalogue.ID.allCases))
        #expect(Set(registrations.map(\.id.rawValue)).count == registrations.count)
        #expect(registrations.last?.id == .text)
        #expect(BuiltInPreviewCatalogue.registration(for: nil) == nil)
    }

    @Test(arguments: ["code.ts", "notes.md", "art.svg", "page.html", "image.png", "movie.mov", "document.pdf"])
    func activationConstructsOnlyTheSelectedPresentationOnce(name: String) throws {
        var constructed = [BuiltInPreviewCatalogue.ID]()
        let state = BuiltInPreviewState { registration in
            constructed.append(registration.id)
            return registration.makePresentation()
        }
        let item = DirectoryEntry(url: URL(fileURLWithPath: "/nonexistent-preview/\(name)"), isDirectory: false)
        let registration = try #require(BuiltInPreviewCatalogue.registration(for: item))
        #expect(PreviewRoute(item) == registration.route && constructed.isEmpty)
        state.activate(registration)
        state.activate(registration)
        #expect(constructed == [registration.id])
        state.stop()
        #expect(state.id == nil && state.image == nil && state.video == nil && state.pdf == nil && state.markdown == nil)
    }

    @Test func changingFormatsReleasesThePreviousConcreteOwner() {
        let state = BuiltInPreviewState()
        let image = DirectoryEntry(url: URL(fileURLWithPath: "/nonexistent-preview/image.png"), isDirectory: false)
        state.activate(BuiltInPreviewCatalogue.registration(for: image))
        let previousImage = { [weak image = state.image] in image }
        #expect(previousImage() != nil)
        let text = DirectoryEntry(url: URL(fileURLWithPath: "/nonexistent-preview/notes.txt"), isDirectory: false)
        state.activate(BuiltInPreviewCatalogue.registration(for: text))
        #expect(previousImage() == nil && state.id == .text)
    }
}

@MainActor extension BuiltInPreviewState {
    convenience init(image: ImagePreviewState? = nil, video: VideoPreviewState? = nil,
                     pdf: PDFPreviewState? = nil, markdown: MarkdownPreviewState? = nil) {
        self.init { registration in
            switch registration.id {
            case .image: if let image { return .image(image) }
            case .video: if let video { return .video(video) }
            case .pdf: if let pdf { return .pdf(pdf) }
            case .markdown: if let markdown { return .markdown(markdown) }
            default: break
            }
            return registration.makePresentation()
        }
    }
}
