import XCTest
@testable import PlayAndLearnCore

final class PromptAudioTests: XCTestCase {
    let a = "11111111-1111-1111-1111-111111111111"
    let b = "22222222-2222-2222-2222-222222222222"

    func testFileNameAndPlayable() {
        XCTAssertEqual(PromptAudio.fileName(id: a, mime: "audio/wav"), "\(a).wav")
        XCTAssertEqual(PromptAudio.fileName(id: a, mime: "audio/mp4"), "\(a).m4a")
        XCTAssertNil(PromptAudio.fileName(id: a, mime: "image/png"))
        XCTAssertFalse(PromptAudio.isPlayable("audio/webm"))
        XCTAssertFalse(PromptAudio.isPlayable("audio/ogg"))
        XCTAssertTrue(PromptAudio.isPlayable("audio/mpeg"))
    }
    func testDownloadsOnlyMissingPlayable() {
        let assets = [a: AudioMeta(mime: "audio/wav", sha256: "x"), b: AudioMeta(mime: "audio/webm", sha256: "y")]
        XCTAssertEqual(PromptAudio.toDownload(assets, existingFiles: []), [a])
        XCTAssertEqual(PromptAudio.toDownload(assets, existingFiles: ["\(a).wav"]), [])
    }
    func testHex() { XCTAssertEqual(PromptAudio.hex([0, 255, 16]), "00ff10") }
}
