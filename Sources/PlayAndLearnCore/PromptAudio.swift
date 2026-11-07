import Foundation

/// Metadata aset audio dari server (disalin dari `assets` pada content pack).
public struct AudioMeta: Decodable, Equatable {
    public let mime: String
    public let sha256: String
    public let sizeBytes: Int?
    public init(mime: String, sha256: String, sizeBytes: Int? = nil) { self.mime = mime; self.sha256 = sha256; self.sizeBytes = sizeBytes }
}

/// Aturan unduh dan pemutaran audio instruksi. Murni agar dapat diuji tanpa perangkat.
/// AVAudioPlayer tidak memutar webm/ogg, jadi hanya wav/mp3/m4a yang dianggap dapat diputar (selain itu: suara sintetis).
public enum PromptAudio {
    private static let ext = ["audio/wav": "wav", "audio/x-wav": "wav", "audio/mpeg": "mp3", "audio/mp4": "m4a"]

    public static func isPlayable(_ mime: String) -> Bool { ext[mime] != nil }
    public static func fileName(id: String, mime: String) -> String? { ext[mime].map { "\(id).\($0)" } }

    /// Id aset yang perlu diunduh: dapat diputar dan belum ada di perangkat.
    public static func toDownload(_ assets: [String: AudioMeta], existingFiles: Set<String>) -> [String] {
        assets.filter { isPlayable($0.value.mime) && !existingFiles.contains(fileName(id: $0.key, mime: $0.value.mime) ?? "") }.keys.sorted()
    }

    public static func hex(_ bytes: [UInt8]) -> String { bytes.map { String(format: "%02x", $0) }.joined() }
}
