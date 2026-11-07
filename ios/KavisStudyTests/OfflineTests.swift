import XCTest
@testable import KavisStudy

/// Settings "Çalıştığım PDF'leri indir": which lessons come ahead, on which network, and the 1 GB limit.
final class OfflineTests: XCTestCase {
    private let id1 = "11111111-1111-1111-1111-111111111111"

    func testEveryKeptFileBelongsToItsLesson() {
        for name in ["pdf-\(id1).pdf", "lesson-\(id1).json", "ink-\(id1).json", "ink-\(id1)-pdf.json", "marks-\(id1).json", "cards-\(id1).json", "summary-\(id1).json"] {
            XCTAssertEqual(OfflineStore.lessonId(name), id1, name)
        }
        XCTAssertNil(OfflineStore.lessonId("lesson-short.json"))
        XCTAssertNil(OfflineStore.lessonId("other.json"))
    }

    func testNewLessonsOnlyWithTheSwitchOnAndUnderTheLimit() {
        let gb: Int64 = 5_000_000_000
        XCTAssertTrue(OfflineStore.mayAddLesson(enabled: true, usedBytes: 0, freeBytes: gb))
        XCTAssertFalse(OfflineStore.mayAddLesson(enabled: false, usedBytes: 0, freeBytes: gb), "switch off: nothing new")
        XCTAssertFalse(OfflineStore.mayAddLesson(enabled: true, usedBytes: OfflineStore.limitBytes, freeBytes: gb), "1 GB reached")
        XCTAssertFalse(OfflineStore.mayAddLesson(enabled: true, usedBytes: 0, freeBytes: 500_000_000), "phone almost full")
        XCTAssertTrue(OfflineStore.mayAddLesson(enabled: true, usedBytes: 0, freeBytes: nil), "free space unknown")
    }

    func testMobileDataAndLowDataModeOnlyWhenAllowed() {
        XCTAssertTrue(OfflineSync.networkAllows(connected: true, expensive: false, constrained: false, cellularAllowed: false), "Wi-Fi")
        XCTAssertFalse(OfflineSync.networkAllows(connected: true, expensive: true, constrained: false, cellularAllowed: false), "mobile data, not allowed")
        XCTAssertTrue(OfflineSync.networkAllows(connected: true, expensive: true, constrained: false, cellularAllowed: true), "mobile data, allowed")
        XCTAssertFalse(OfflineSync.networkAllows(connected: true, expensive: false, constrained: true, cellularAllowed: false), "Low Data Mode, not allowed")
        XCTAssertTrue(OfflineSync.networkAllows(connected: true, expensive: true, constrained: true, cellularAllowed: true), "Low Data Mode, allowed")
        XCTAssertFalse(OfflineSync.networkAllows(connected: false, expensive: false, constrained: false, cellularAllowed: true), "no internet")
    }

    func testOpenedAndRecentLessonsComeNewestFirst() throws {
        let json = #"""
        [{"id": "A", "kind": "pdf", "created_at": "2026-09-01T10:00:00+00:00", "reading_progress": [{"updated_at": "2026-11-04T08:00:00.5+00:00"}]},
         {"id": "B", "kind": "pdf", "created_at": "2026-11-03T10:00:00+00:00", "reading_progress": []},
         {"id": "C", "kind": "pdf", "created_at": "2026-09-01T10:00:00+00:00", "reading_progress": []},
         {"id": "D", "kind": "audio", "created_at": "2026-11-04T10:00:00+00:00", "reading_progress": []},
         {"id": "E", "kind": "photo", "created_at": "2026-11-05T09:00:00+00:00"}]
        """#
        let rows = try JSONDecoder().decode([OfflineSync.Candidate].self, from: Data(json.utf8))
        let now = ISO8601DateFormatter().date(from: "2026-11-05T12:00:00Z")!
        XCTAssertEqual(OfflineSync.pick(rows, now: now), ["e", "a", "b"],
                       "opened (A) and uploaded in the last 14 days (B, E); an old unopened PDF (C) and a recording (D) are left")
    }

    func testCardsDueWithoutInternet() {
        let now = ISO8601DateFormatter().date(from: "2026-11-05T12:00:00Z")!
        XCTAssertTrue(CardsAPI.isDue("2026-11-05T11:59:59.123456+00:00", now: now))
        XCTAssertFalse(CardsAPI.isDue("2026-11-06T08:00:00+00:00", now: now))
        XCTAssertTrue(CardsAPI.isDue(nil, now: now))
    }

    // MARK: Server down (seen 5 Nov 2026: the reader stayed blank while the client retried)

    private struct Down: Error {}

    func testWithACopyAFailedReadIsNotRetriedAndGivesTheCopy() async {
        let start = ContinuousClock.now
        let answer: Int? = await OfflineStore.fromServer(hasCopy: true) { retry in
            XCTAssertFalse(retry, "no retries when the phone has a copy")
            throw Down()
        }
        XCTAssertNil(answer, "nil = show the phone's copy")
        XCTAssertLessThan(ContinuousClock.now - start, .seconds(1), "at once, not after the retries")
    }

    func testWithACopyASlowServerGivesTheCopyAfterTheWait() async {
        let start = ContinuousClock.now
        let answer: Int? = await OfflineStore.fromServer(hasCopy: true, wait: .milliseconds(200)) { _ in
            try await Task.sleep(for: .seconds(30))
            return 1
        }
        XCTAssertNil(answer)
        XCTAssertLessThan(ContinuousClock.now - start, .seconds(2), "does not wait for the server's time-out")
    }

    func testTheServersAnswerWinsWhenItComes() async {
        let withCopy: Int? = await OfflineStore.fromServer(hasCopy: true) { _ in 7 }
        XCTAssertEqual(withCopy, 7)
        let noCopy: Int? = await OfflineStore.fromServer(hasCopy: false) { retry in
            XCTAssertTrue(retry, "without a copy the usual retries stay")
            return 8
        }
        XCTAssertEqual(noCopy, 8)
    }
}
