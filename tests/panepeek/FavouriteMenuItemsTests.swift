import Foundation
import Testing
@testable import PanePeek

struct FavouriteMenuItemsTests {
    @Test func uniqueNamesAndRootStayCompactWithoutCheckingAvailability() {
        let paths = ["/missing/Downloads", "/Archive/Café Notes 📚", "/"]
        #expect(titles(paths) == ["Downloads", "Café Notes 📚", "/"])
    }

    @Test func duplicateNamesUseOnlyTheParentContextTheyNeed() {
        let paths = ["/Work/Projects", "/Personal/Projects", "/missing/Downloads"]
        #expect(titles(paths) == ["Projects (Work)", "Projects (Personal)", "Downloads"])
    }

    @Test func matchingParentsExpandUntilTheirPathsDiffer() {
        let paths = ["/Company/Work/Projects", "/Personal/Work/Projects", "/Archive/Projects"]
        #expect(titles(paths) == ["Projects (Company/Work)", "Projects (Personal/Work)", "Projects (Archive)"])
    }

    @Test func rootLevelAndNestedSuffixesRemainDistinct() {
        let paths = ["/Projects", "/Work/Projects", "/Archive/Work/Projects", "/"]
        #expect(titles(paths) == ["Projects (/)", "Projects (/Work)", "Projects (Archive/Work)", "/"])
    }

    @Test func removingADuplicateRestoresTheFolderName() {
        let paths = ["/Work/Projects", "/Personal/Projects"]
        #expect(titles(paths) == ["Projects (Work)", "Projects (Personal)"])
        #expect(titles(Array(paths.prefix(1))) == ["Projects"])
    }

    private func titles(_ paths: [String]) -> [String] {
        let directories = paths.map { URL(fileURLWithPath: $0, isDirectory: true) }
        return directories.map { FavouriteMenuItems.title(for: $0, among: directories) }
    }
}
