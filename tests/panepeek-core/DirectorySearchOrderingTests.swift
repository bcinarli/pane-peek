import Foundation
import Synchronization
import Testing
@testable import PanePeekCore

@Suite(.timeLimit(.minutes(1))) @MainActor
struct DirectorySearchOrderingTests {
    @Test(arguments: [false, true])
    func navigationKeepsInterimSearchResultsInTheirSelectedOrder(relevance: Bool) async throws {
        try await withTestRequestGate(of: String.self, returning: DirectorySearch.Result.self) { gate in
            let first = URL(fileURLWithPath: "/search-order-a", isDirectory: true)
            let second = URL(fileURLWithPath: "/search-order-b", isDirectory: true)
            let entries: @Sendable (URL) -> [DirectoryEntry] = { directory in
                [("report-a", UInt64(20)), ("report-z", 1), ("report", 10)].map {
                    DirectoryEntry(url: directory.appendingPathComponent($0.0), isDirectory: false, size: $0.1)
                }
            }
            let pane = DirectoryPane(directory: first, resolveBeforeLoading: false,
                load: { .init(directory: $0, entries: entries($0)) },
                search: { root, query, _ in
                    if root == second { return try await gate.request(query) }
                    return .init(entries: entries(root))
                })
            await pane.refresh()
            pane.setSearchQuery("report")
            await pane.waitForSearch()
            await pane.sort(by: .size, direction: .ascending)
            await pane.setSearchRelevance(relevance)
            let expected = relevance ? ["report", "report-z", "report-a"] : ["report-z", "report", "report-a"]
            try #require(pane.entries.map(\.name) == expected)
            await pane.navigate(to: second)
            try #require(pane.isSearching)
            #expect(pane.entries.map(\.name) == expected)
            #expect(pane.displayedSortField == (relevance ? nil : .size))
            _ = try await gate.waitForRequest(0)
            try gate.finish(0, with: .success(.init(entries: entries(second))))
            await pane.waitForSearch()
            #expect(pane.entries.map(\.name) == expected)
            pane.setSearchQuery("")
            #expect(pane.entries.map(\.name) == ["report", "report-a", "report-z"])
        }
    }

    @Test func searchOrderingDoesNotCancelAnOrdinarySortAlreadyInFlight() async throws {
        try await withTestRequestGate(of: [DirectoryEntry].self, returning: [DirectoryEntry].self) { gate in
            let entries = [entry("report-a", size: 20), entry("report-z", size: 1)]
            let holdFirst = Mutex(true)
            let pane = DirectoryPane(directory: root, load: { .init(directory: $0, entries: entries) },
                sortEntries: { entries, field, direction in
                    let sorted = entries.sorted { $0.precedes($1, field: field, direction: direction) }
                    let hold = field == .size && holdFirst.withLock { value in
                        let previous = value
                        value = false
                        return previous
                    }
                    guard hold else { return sorted }
                    return (try? await gate.request(sorted)) ?? sorted
                }, resolveBeforeLoading: false, search: { _, _, _ in .init(entries: entries) })
            await pane.refresh()
            let ordinary = Task { await pane.sort(by: .size, direction: .ascending) }
            gate.track(ordinary)
            let held = try await gate.waitForRequest(0)
            pane.setSearchQuery("report")
            await pane.waitForSearch()
            await pane.sort(by: .name, direction: .descending)
            try gate.finish(0, with: .success(held))
            await ordinary.value
            pane.setSearchQuery("")
            #expect(pane.entries.map(\.name) == ["report-z", "report-a"])
            #expect(pane.sortField == .size && pane.sortDirection == .ascending)
        }
    }

    @Test(arguments: [false, true])
    func interimSearchSortCannotReplaceAClearedQueryOrNewerOrder(clear: Bool) async throws {
        try await withTestRequestGate(of: [DirectoryEntry].self, returning: [DirectoryEntry].self) { gate in
            let first = URL(fileURLWithPath: "/search-order-a", isDirectory: true)
            let second = URL(fileURLWithPath: "/search-order-b", isDirectory: true)
            let entries: @Sendable (URL) -> [DirectoryEntry] = { directory in
                ["report-a", "report-z", "unmatched"].map {
                    DirectoryEntry(url: directory.appendingPathComponent($0), isDirectory: false, size: 1)
                }
            }
            let pane = DirectoryPane(directory: first, load: { .init(directory: $0, entries: entries($0)) },
                sortEntries: { entries, field, direction in
                    let sorted = entries.sorted { $0.precedes($1, field: field, direction: direction) }
                    guard field == .size, entries.first?.url.deletingLastPathComponent() == second else { return sorted }
                    return (try? await gate.request(sorted)) ?? sorted
                }, resolveBeforeLoading: false,
                search: { root, _, _ in .init(entries: entries(root).filter { $0.name.hasPrefix("report") }) })
            await pane.refresh()
            pane.setSearchQuery("report")
            await pane.waitForSearch()
            await pane.sort(by: .size)
            let navigation = Task { await pane.navigate(to: second) }
            gate.track(navigation)
            let held = try await gate.waitForRequest(0)
            if clear { pane.setSearchQuery("") }
            else { await pane.sort(by: .name, direction: .descending) }
            try gate.finish(0, with: .success(held))
            await navigation.value
            #expect(pane.directory == second)
            #expect(pane.entries.map(\.name) == (clear ? ["report-a", "report-z", "unmatched"] : ["report-z", "report-a"]))
            await pane.waitForSearch()
        }
    }

    private let root = URL(fileURLWithPath: "/search-order", isDirectory: true)

    private func entry(_ path: String, folder: Bool = false, size: UInt64? = nil) -> DirectoryEntry {
        DirectoryEntry(url: root.appendingPathComponent(path), isDirectory: folder, size: size)
    }

    private func pane(_ entries: [DirectoryEntry], partial: Bool = false) async -> DirectoryPane {
        let pane = DirectoryPane(directory: root, resolveBeforeLoading: false,
            load: { .init(directory: $0, entries: entries) },
            search: { _, query, _ in
                .init(entries: entries.filter { $0.name.range(of: query, options: .caseInsensitive) != nil },
                      skippedDirectories: partial ? 1 : 0, reachedLimit: partial)
            })
        await pane.refresh()
        return pane
    }

    @Test(arguments: [false, true])
    func matchStrengthPrecedesKindAndColumnOrderWithStablePathTies(reversed: Bool) async {
        let entries = [entry("z/report.txt"), entry("a/my-report.txt", folder: true),
                       entry("b/report.txt"), entry("report.txt notes", folder: true), entry("a/report.txt")]
        let pane = await pane(reversed ? Array(entries.reversed()) : entries, partial: true)
        await pane.sort(by: .name, direction: .descending)
        pane.setSearchQuery("REPORT.TXT")
        await pane.waitForSearch()
        #expect(pane.entries.map { pane.relativeSearchPath(for: $0) } ==
            ["a/report.txt", "b/report.txt", "z/report.txt", "report.txt notes", "a/my-report.txt"])
        #expect(pane.searchMessage?.contains("100,000") == true)
        #expect(pane.searchMessage?.contains("(1)") == true)
    }

    @Test func searchColumnChangesDoNotReplaceOrdinarySortAndNewSearchResets() async {
        let entries = [entry("report.txt", size: 1), entry("report.txt notes", size: 20), entry("my-report.txt", size: 10)]
        let pane = await pane(entries)
        await pane.sort(by: .name, direction: .descending)
        let ordinary = pane.entries
        pane.setSearchQuery("report.txt")
        await pane.waitForSearch()
        await pane.sort(by: .size)
        #expect(pane.entries.map(\.size) == [20, 10, 1])
        pane.setSearchQuery("report")
        await pane.waitForSearch()
        #expect(pane.entries.map(\.size) == [20, 10, 1])
        pane.setSearchQuery("")
        #expect(pane.entries == ordinary)
        #expect(pane.sortField == .name && pane.sortDirection == .descending)
        pane.setSearchQuery("report.txt")
        await pane.waitForSearch()
        #expect(pane.entries.first?.name == "report.txt")
    }

    @Test func unicodeAndLiteralSpacesUseTheExistingMatchingSemantics() async {
        let pane = await pane([entry("z/CAFÉ notes"), entry("a/ café notes"), entry("cafe\u{301} notes extra"),
                               entry("cafe notes"), entry("CAFÉ notes")])
        pane.setSearchQuery("café notes")
        await pane.waitForSearch()
        #expect(pane.entries.map { pane.relativeSearchPath(for: $0) } ==
            ["CAFÉ notes", "z/CAFÉ notes", "cafe\u{301} notes extra", "a/ café notes"])
        pane.setSearchQuery(" café notes")
        await pane.waitForSearch()
        #expect(pane.entries.map(\.name) == [" café notes"])
    }

    @Test func toggleResumesColumnOrderAndKeepsSelectionAndUnavailableSizes() async {
        let pane = await pane([entry("report", size: 5), entry("report-a", size: 20),
                               entry("report-z", size: 10), entry("my-report", folder: true)])
        await pane.sort(by: .size, direction: .ascending)
        pane.setSearchQuery("report")
        await pane.waitForSearch()
        let selection = root.appendingPathComponent("report-z")
        pane.setSelection([selection], focusedItem: selection)
        #expect(pane.displayedSortField == nil)
        await pane.setSearchRelevance(false)
        #expect(pane.displayedSortField == .size && pane.displayedSortDirection == .ascending)
        #expect(pane.entries.map(\.name) == ["report", "report-z", "report-a", "my-report"])
        await pane.setSearchRelevance(true)
        await pane.sort(by: .size)
        #expect(pane.displayedSortDirection == .descending)
        #expect(pane.entries.map(\.name) == ["report-a", "report-z", "report", "my-report"])
        await pane.setSearchRelevance(true)
        #expect(pane.entries.map(\.name) == ["report", "report-a", "report-z", "my-report"])
        #expect(pane.selectedItems == [selection] && pane.primaryItemURL == selection)
        #expect(pane.sortField == .size && pane.sortDirection == .ascending)
        pane.setSearchQuery("")
        #expect(pane.displayedSortField == .size && pane.displayedSortDirection == .ascending)
    }

    @Test(arguments: [false, true])
    func lateSearchSortCannotReplaceANewerOrderOrClearedQuery(clear: Bool) async throws {
        try await withTestRequestGate(of: [DirectoryEntry].self, returning: [DirectoryEntry].self) { gate in
            let entries = [entry("report", size: 1), entry("report-z", size: 20)]
            let pane = DirectoryPane(directory: root, load: { .init(directory: $0, entries: entries) },
                sortEntries: { entries, field, direction in
                    let sorted = entries.sorted { $0.precedes($1, field: field, direction: direction) }
                    guard field == .size else { return sorted }
                    return (try? await gate.request(sorted)) ?? sorted
                }, resolveBeforeLoading: false, search: { _, _, _ in .init(entries: entries) })
            await pane.refresh()
            pane.setSearchQuery("report")
            await pane.waitForSearch()
            let older = Task { await pane.sort(by: .size) }
            gate.track(older)
            let held = try await gate.waitForRequest(0)
            if clear { pane.setSearchQuery("") }
            else { await pane.sort(by: .name) }
            try gate.finish(0, with: .success(held))
            await older.value
            #expect(pane.entries.map(\.name) == ["report", "report-z"])
            #expect(pane.searchQuery == (clear ? "" : "report"))
            #expect(pane.displayedSortField == .name && pane.displayedSortDirection == .ascending)
        }
    }

    @Test func delayedSearchUsesTheCurrentOrder() async throws {
        try await withTestRequestGate(of: String.self, returning: DirectorySearch.Result.self) { gate in
            let entries = [entry("report", size: 1), entry("report-z", size: 20)]
            let pane = DirectoryPane(directory: root, resolveBeforeLoading: false,
                load: { .init(directory: $0, entries: entries) }, search: { _, query, _ in try await gate.request(query) })
            await pane.refresh()
            pane.setSearchQuery("report")
            #expect(try await gate.waitForRequest(0) == "report")
            await pane.sort(by: .size)
            try gate.finish(0, with: .success(.init(entries: entries)))
            await pane.waitForSearch()
            #expect(pane.entries.map(\.name) == ["report-z", "report"])
            #expect(pane.searchSortField == .size && !pane.searchUsesRelevance)
        }
    }

    @Test func deferredSearchPublicationUsesTheLatestColumnChoice() async throws {
        let entries = [entry("report-old", size: 1)]
        let results = [entry("report", size: 1), entry("report-z", size: 20)]
        let pane = DirectoryPane(directory: root, resolveBeforeLoading: false,
            load: { .init(directory: $0, entries: entries) }, search: { _, _, _ in .init(entries: results) })
        await pane.refresh()
        pane.setSelection([entries[0].url])
        var retry: (@MainActor () -> Void)?
        var blocked = true
        pane.approveChange = { primary, _, completion in
            if primary == nil && blocked { retry = completion; return false }
            return true
        }
        pane.setSearchQuery("report")
        await pane.waitForSearch()
        let resume = try #require(retry)
        await pane.sort(by: .size)
        blocked = false
        resume()
        try await waitForState { pane.entries.count == 2 }
        #expect(pane.entries.map(\.name) == ["report-z", "report"])
        #expect(pane.displayedSortField == .size)
    }
}
