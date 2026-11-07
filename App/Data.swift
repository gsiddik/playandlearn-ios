import Foundation
import CryptoKit
import PlayAndLearnCore

struct ChildDef: Codable, Equatable, Identifiable { let id: String; let alias: String; let birthYear: Int }

struct ActivityDef: Decodable, Identifiable {
    let id: String
    let kind: String
    let levels: [LevelDef]
    let promptAudio: String?
    struct LevelDef: Decodable {
        let items: [Item]?
        let sequence: [String]?
        let options: [OptionValue]?
        let answer: String?
        let count: Int?
        struct Item: Decodable { let id: String; let group: String }
    }
    var tasks: [LevelTask] {
        levels.map { l in
            switch kind {
            case "sort": return .sort(itemGroups: Dictionary(uniqueKeysWithValues: (l.items ?? []).map { ($0.id, $0.group) }))
            case "pattern": return .pattern(options: (l.options ?? []).map(\.text), answer: l.answer ?? "")
            default: return .count(count: l.count ?? 0, options: (l.options ?? []).compactMap { Int($0.text) })
            }
        }
    }
}

/// Opsi konten bisa string ("A") atau angka (3).
struct OptionValue: Decodable {
    let text: String
    init(from d: Decoder) throws {
        let c = try d.singleValueContainer()
        if let i = try? c.decode(Int.self) { text = String(i) } else { text = try c.decode(String.self) }
    }
}

struct Pack: Decodable { let version: Int; let activities: [ActivityDef]; let assets: [String: AudioMeta]? }

struct Policy: Codable {
    var dailyMinutes: Int = 30
    var sessionMinutes: Int = 10
    var allowedFrom: String?
    var allowedTo: String?
    var version: Int = 0
    var core: ScreenTimePolicy {
        func m(_ s: String?) -> Int? {
            guard let s, s.count == 5, let h = Int(s.prefix(2)), let mi = Int(s.suffix(2)) else { return nil }
            return h * 60 + mi
        }
        return ScreenTimePolicy(dailyMinutes: dailyMinutes, sessionMinutes: sessionMinutes,
                                allowedFromMinute: m(allowedFrom), allowedToMinute: m(allowedTo), version: version)
    }
}

/// Penyimpanan lokal: UserDefaults + berkas JSON event di Application Support. Token: TODO Keychain.
final class Store {
    private let d = UserDefaults.standard
    private let url: URL = {
        let dir = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir.appendingPathComponent("events.json")
    }()
    struct Stored: Codable { var id, child, activity: String; var version: Int; var type: String; var payload: [String: Int]; var ts: Int64; var sent: Bool }

    var role: String? { get { d.string(forKey: "role") } set { d.set(newValue, forKey: "role") } }
    /// ID aktivitas yang ditugaskan guru (mode murid).
    var assigned: Set<String> {
        get { Set((d.string(forKey: "assigned") ?? "").split(separator: ",").map(String.init)) }
        set { d.set(newValue.sorted().joined(separator: ","), forKey: "assigned") }
    }
    /// Audio instruksi hasil unduhan (Application Support, privat milik aplikasi).
    var audioDir: URL {
        let dir = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0].appendingPathComponent("audio")
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }
    /// Berkas audio instruksi aktivitas bila sudah diunduh dan dapat diputar; selain itu nil (pakai suara sintetis).
    func promptURL(for activity: ActivityDef, in pack: Pack) -> URL? {
        guard let id = activity.promptAudio, let meta = pack.assets?[id], let name = PromptAudio.fileName(id: id, mime: meta.mime) else { return nil }
        let u = audioDir.appendingPathComponent(name)
        return FileManager.default.fileExists(atPath: u.path) ? u : nil
    }
    func logout() {
        try? FileManager.default.removeItem(at: audioDir)
        for k in d.dictionaryRepresentation().keys { d.removeObject(forKey: k) }
        try? FileManager.default.removeItem(at: url)
    }
    var accessToken: String? { get { d.string(forKey: "access") } set { d.set(newValue, forKey: "access") } }
    var packData: Data? { get { d.data(forKey: "pack") } set { d.set(newValue, forKey: "pack") } }
    var childrenData: Data? { get { d.data(forKey: "children") } set { d.set(newValue, forKey: "children") } }
    var policyData: Data? { get { d.data(forKey: "policy") } set { d.set(newValue, forKey: "policy") } }
    var pack: Pack? { packData.flatMap { try? JSONDecoder().decode(Pack.self, from: $0) } }
    var children: [ChildDef] { childrenData.flatMap { try? JSONDecoder().decode([ChildDef].self, from: $0) } ?? [] }
    var policy: Policy { policyData.flatMap { try? JSONDecoder().decode(Policy.self, from: $0) } ?? Policy() }

    func level(_ child: String, _ activity: String) -> Int { max(1, d.integer(forKey: "lvl:\(child):\(activity)")) }
    func setLevel(_ child: String, _ activity: String, _ l: Int) { d.set(l, forKey: "lvl:\(child):\(activity)") }

    private var today: String { ISO8601DateFormatter().string(from: Date()).prefix(10).description }
    var playedTodaySeconds: Int { d.integer(forKey: "played:\(today)") }
    func addPlayed(_ s: Int) { d.set(playedTodaySeconds + s, forKey: "played:\(today)") }
    var sessionState: SessionTracker.State {
        get { SessionTracker.State(sessionSec: d.integer(forKey: "sess_sec"), lastEndMs: Int64(d.integer(forKey: "sess_end"))) }
        set { d.set(newValue.sessionSec, forKey: "sess_sec"); d.set(Int(newValue.lastEndMs), forKey: "sess_end") }
    }

    private func load() -> [Stored] { (try? Data(contentsOf: url)).flatMap { try? JSONDecoder().decode([Stored].self, from: $0) } ?? [] }
    private func write(_ all: [Stored]) { try? JSONEncoder().encode(all).write(to: url, options: .atomic) }
    func save(_ e: GameEvent) {
        var all = load()
        guard !all.contains(where: { $0.id == e.id }) else { return }
        all.append(Stored(id: e.id, child: e.childId, activity: e.activityId, version: e.contentVersion, type: e.type.rawValue, payload: e.payload, ts: e.deviceTsMillis, sent: false))
        write(all)
    }
    func pending() -> [Stored] { Array(load().filter { !$0.sent }.sorted { $0.ts < $1.ts }.prefix(SyncBatcher.maxBatch)) }
    func markSent(_ ids: Set<String>) { write(load().map { var s = $0; if ids.contains(s.id) { s.sent = true }; return s }) }
}

struct HttpError: Error { let code: Int }

/// Klien HTTP minimal. Basis URL dapat diubah lewat Info.plist `API_BASE` (default emulator/localhost).
final class Api {
    let store: Store
    let base = URL(string: Bundle.main.object(forInfoDictionaryKey: "API_BASE") as? String ?? "http://localhost:3000/v1")!
    init(store: Store) { self.store = store }

    @discardableResult
    private func call(_ method: String, _ path: String, _ body: [String: Any]? = nil) async throws -> (Int, Data) {
        var r = URLRequest(url: URL(string: base.absoluteString + path)!)
        r.httpMethod = method
        r.setValue("application/json", forHTTPHeaderField: "Content-Type")
        if let t = store.accessToken { r.setValue("Bearer \(t)", forHTTPHeaderField: "Authorization") }
        if let body { r.httpBody = try JSONSerialization.data(withJSONObject: body) }
        let (data, resp) = try await URLSession.shared.data(for: r)
        return ((resp as? HTTPURLResponse)?.statusCode ?? 0, data)
    }
    private func auth(_ path: String, _ body: [String: Any]) async throws {
        let (code, data) = try await call("POST", path, body)
        guard (200...299).contains(code) else { throw HttpError(code: code) }
        store.accessToken = (try JSONSerialization.jsonObject(with: data) as? [String: Any])?["accessToken"] as? String
    }
    func register(_ email: String, _ pw: String) async throws {
        try await auth("/auth/parents/register", ["email": email, "password": pw, "consentPolicyVersion": "2026-11-draft", "consentGranted": true])
    }
    func login(_ email: String, _ pw: String) async throws { try await auth("/auth/login", ["email": email, "password": pw]) }

    /// Login murid dari kartu: kode QR + 3 indeks gambar PIN (0..8).
    func studentLogin(_ code: String, _ pin: [Int]) async throws {
        let (c, data) = try await call("POST", "/auth/students/login", ["loginCode": code, "pin": pin])
        guard (200...299).contains(c) else { throw HttpError(code: c) }
        store.accessToken = (try JSONSerialization.jsonObject(with: data) as? [String: Any])?["accessToken"] as? String
        store.role = "student"
    }
    /// Muat profil murid, misi tugas, konten, dan kebijakan.
    func loadStudent() async throws -> ChildDef {
        let (c, data) = try await call("GET", "/me/profile")
        guard (200...299).contains(c), let o = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let id = o["id"] as? String, let alias = o["alias"] as? String, let year = o["birthYear"] as? Int else { throw HttpError(code: c) }
        let child = ChildDef(id: id, alias: alias, birthYear: year)
        store.childrenData = try JSONEncoder().encode([child])
        store.assigned = Set(((o["assignments"] as? [[String: Any]]) ?? []).compactMap { $0["activityId"] as? String })
        try await refreshPack(age: Calendar.current.component(.year, from: Date()) - year)
        try await refreshPolicy(childId: id)
        return child
    }

    func refreshChildren() async throws -> [ChildDef] {
        let (code, data) = try await call("GET", "/children")
        guard (200...299).contains(code) else { throw HttpError(code: code) }
        store.childrenData = data
        return try JSONDecoder().decode([ChildDef].self, from: data)
    }
    func createChild(_ alias: String, _ year: Int) async throws {
        let (code, _) = try await call("POST", "/children", ["alias": alias, "birthYear": year])
        guard (200...299).contains(code) else { throw HttpError(code: code) }
    }
    func refreshPack(age: Int) async throws {
        let have = store.pack?.version ?? 0
        let (code, data) = try await call("GET", "/content/packs/latest?age=\(age)&haveVersion=\(have)")
        if code == 200, var o = try JSONSerialization.jsonObject(with: data) as? [String: Any], var m = o["manifest"] as? [String: Any] {
            m["version"] = o["version"]; m["assets"] = o["assets"] ?? [String: Any](); o = m
            store.packData = try JSONSerialization.data(withJSONObject: o)
        } else if code != 304 { throw HttpError(code: code) }
        await downloadAudio()
    }

    /// Unduh audio instruksi yang belum ada. Gagal = aktivitas tetap jalan dengan suara sintetis; dicoba lagi pada pembaruan berikutnya.
    func downloadAudio() async {
        guard let assets = store.pack?.assets else { return }
        let dir = store.audioDir
        let existing = Set((try? FileManager.default.contentsOfDirectory(atPath: dir.path)) ?? [])
        for id in PromptAudio.toDownload(assets, existingFiles: existing) {
            guard let meta = assets[id], let name = PromptAudio.fileName(id: id, mime: meta.mime),
                  let (code, data) = try? await call("GET", "/assets/\(id)/file"), (200...299).contains(code),
                  data.count <= 5 * 1024 * 1024,
                  PromptAudio.hex(Array(SHA256.hash(data: data))) == meta.sha256 else { continue } // rusak/berubah: jangan simpan
            try? data.write(to: dir.appendingPathComponent(name), options: .atomic)
        }
        // Buang audio yang tidak lagi dirujuk pack.
        let keep = Set(assets.compactMap { PromptAudio.fileName(id: $0.key, mime: $0.value.mime) })
        for f in (try? FileManager.default.contentsOfDirectory(atPath: dir.path)) ?? [] where !keep.contains(f) {
            try? FileManager.default.removeItem(at: dir.appendingPathComponent(f))
        }
    }
    func refreshPolicy(childId: String) async throws {
        let (code, data) = try await call("GET", "/children/\(childId)/policy")
        if code == 200 { store.policyData = data }
    }
    /// Kirim event tertunda; idempoten. Server authority atas kebijakan.
    func sync() async throws {
        let pending = store.pending()
        if pending.isEmpty { return }
        let iso = ISO8601DateFormatter(); iso.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        let events: [[String: Any]] = pending.map {
            ["id": $0.id, "childId": $0.child, "activityId": $0.activity, "contentVersion": $0.version, "type": $0.type,
             "payload": $0.payload, "deviceTs": iso.string(from: Date(timeIntervalSince1970: Double($0.ts) / 1000))]
        }
        let (code, data) = try await call("POST", "/sync/events", ["events": events])
        guard (200...299).contains(code) else { throw HttpError(code: code) }
        store.markSent(Set(pending.map(\.id)))
        if let p = (try JSONSerialization.jsonObject(with: data) as? [String: Any])?["policy"], let pd = try? JSONSerialization.data(withJSONObject: p) { store.policyData = pd }
    }
}
