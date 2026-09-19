import Testing
@testable import Subjects

@Suite struct AnnouncerTests {
    @Test func announcesAMessage() {
        let announcer = Announcer(prefix: "INFO")
        #expect(announcer.prefix == "INFO")
    }

    @Test func warnsAboutMessage() {
        let announcer = Announcer(prefix: "WARN")
        #expect(announcer.prefix == "WARN")
    }
}
