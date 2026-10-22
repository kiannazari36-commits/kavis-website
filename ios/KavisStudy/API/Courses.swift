import Foundation

enum CoursesAPI {
    /// Mock data copied from the web (`mock-courses.json`).
    private static let all: [Course] = MockData.load("mock-courses")

    static func listCourses() async -> [Course] {
        await fakeRequest(all, ms: 150)
    }

    static func getCourse(id: String) async -> Course? {
        await fakeRequest(all.first { $0.id == id }, ms: 150)
    }

    static func getPdf(courseId: String, pdfId: String) async -> (course: Course, pdf: Pdf)? {
        let course = all.first { $0.id == courseId }
        let pdf = course?.pdfs.first { $0.id == pdfId }
        guard let course, let pdf else { return await fakeRequest(nil, ms: 150) }
        return await fakeRequest((course, pdf), ms: 150)
    }

    /// Totals used on a course card and folder header.
    static func stats(_ c: Course) -> (minutes: Int, pages: Int, percent: Int) {
        let minutes = c.pdfs.reduce(0) { $0 + $1.minutes }
        let pages = c.pdfs.reduce(0) { $0 + $1.pages }
        let readPages = c.pdfs.reduce(0.0) { $0 + Double($1.pages * $1.read) / 100 }
        return (minutes, pages, pages > 0 ? Int((readPages / Double(pages) * 100).rounded()) : 0)
    }

    /// "Today" for the mock data: one week before the first midterm, as in the design.
    static let mockToday = "2026-10-12"

    static func daysUntil(_ iso: String, today: String = mockToday) -> Int {
        let f = DateFormatter()
        f.calendar = Calendar(identifier: .gregorian)
        f.timeZone = TimeZone(identifier: "UTC")
        f.dateFormat = "yyyy-MM-dd"
        guard let a = f.date(from: iso), let b = f.date(from: today) else { return 0 }
        return Int((a.timeIntervalSince(b) / 86_400).rounded())
    }
}
