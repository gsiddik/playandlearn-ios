import SwiftUI
import AVFoundation
import PlayAndLearnCore

@main
struct PlayAndLearnApp: App {
    var body: some Scene { WindowGroup { RootView() } }
}

/// Suara sintetis (TTS) sebagai placeholder sampai ada rekaman pengisi suara.
final class Speaker {
    private let synth = AVSpeechSynthesizer()
    private var player: AVAudioPlayer?
    /// Putar audio instruksi; kegagalan diam-diam (anak tetap bisa bermain).
    func play(_ url: URL) {
        synth.stopSpeaking(at: .immediate)
        player?.stop()
        player = try? AVAudioPlayer(contentsOf: url)
        player?.play()
    }
    func say(_ text: String) {
        player?.stop()
        let u = AVSpeechUtterance(string: text)
        u.voice = AVSpeechSynthesisVoice(language: "id-ID")
        synth.stopSpeaking(at: .immediate)
        synth.speak(u)
    }
}

enum Screen: Equatable {
    case role, student, studentSettings, gate, auth, children, home
    case level(activityId: String, level: Int)
}

struct RootView: View {
    private let store = Store()
    private let api: Api
    private let speaker = Speaker()
    @State private var screen: Screen
    @State private var child: ChildDef?
    @State private var children: [ChildDef]
    @State private var error: String?
    @State private var busy = false
    @State private var startedAt: Int64 = 0

    init() {
        let s = Store()
        api = Api(store: s)
        _screen = State(initialValue: s.accessToken == nil ? .role : .home)
        _children = State(initialValue: s.children)
        _child = State(initialValue: s.children.first)
    }

    private func nowMs() -> Int64 { Int64(Date().timeIntervalSince1970 * 1000) }

    private func run(_ work: @escaping () async throws -> Void, ok: @escaping () -> Void = {}) {
        busy = true; error = nil
        Task {
            do { try await work(); ok() }
            catch let e as HttpError { self.error = "Gagal (\(e.code))" }
            catch { self.error = "Tidak ada koneksi" }
            busy = false
        }
    }

    var body: some View {
        switch screen {
        case .role:
            RoleChooser(onParent: { screen = .gate }, onStudent: { screen = .student })
        case .student:
            StudentLogin(busy: busy, error: error, onSubmit: { code, pin in
                run({ try await api.studentLogin(code, pin); child = try await api.loadStudent() }, ok: { screen = .home })
            }, onBack: { screen = store.accessToken == nil ? .role : .home })
        case .studentSettings:
            StudentSettings(onLogout: { store.logout(); child = nil; screen = .role }, onBack: { screen = .home })
        case .gate:
            ParentalGate(onPassed: { screen = store.role == "student" ? .studentSettings : (store.accessToken == nil ? .auth : .children) },
                         onCancel: { screen = store.accessToken == nil ? .role : .home })
        case .auth:
            AuthView(busy: busy, error: error) { email, pw, reg in
                run({ if reg { try await api.register(email, pw) } else { try await api.login(email, pw) }; children = try await api.refreshChildren() },
                    ok: { screen = .children })
            }
        case .children:
            ChildPicker(children: children, error: error, onPick: { c in
                child = c
                let age = Calendar.current.component(.year, from: Date()) - c.birthYear
                run({ try await api.refreshPack(age: age); try await api.refreshPolicy(childId: c.id) }, ok: { screen = .home })
            }, onAdd: { a, y in run({ try await api.createChild(a, y); children = try await api.refreshChildren() }) })
        case .home:
            homeView
        case let .level(activityId, level):
            levelView(activityId: activityId, level: level)
        }
    }

    @ViewBuilder private var homeView: some View {
        if let pack = store.pack, let c = child {
            let cal = Calendar.current
            let minutes = cal.component(.hour, from: Date()) * 60 + cal.component(.minute, from: Date())
            let decision = ScreenTimeGuard.decide(policy: store.policy.core, minutesOfDay: minutes,
                                                  playedToday: store.playedTodaySeconds / 60,
                                                  playedThisSession: SessionTracker.sessionMinutes(store.sessionState, nowMs: nowMs()))
            let blocked: String? = {
                switch decision {
                case .allowed: return nil
                case .sessionBreak: return "Istirahat dulu ya"
                case .dailyLimitReached: return "Besok main lagi ya!"
                case .outsideAllowedHours: return "Waktunya istirahat"
                }
            }()
            ChildHome(activities: pack.activities, assigned: store.assigned, blockedReason: blocked, onPlay: { a in
                startedAt = nowMs()
                screen = .level(activityId: a.id, level: min(store.level(c.id, a.id), a.levels.count))
            }, onParent: { screen = .gate })
            .task { if store.accessToken != nil { try? await api.sync() } } // senyap; gagal = tetap offline
        } else {
            Color.clear.onAppear { screen = .role }
        }
    }

    @ViewBuilder private func levelView(activityId: String, level: Int) -> some View {
        if let pack = store.pack, let c = child, let act = pack.activities.first(where: { $0.id == activityId }) {
            let finish = {
                let end = nowMs()
                store.addPlayed(Int((end - startedAt) / 1000))
                store.sessionState = SessionTracker.record(store.sessionState, startMs: startedAt, endMs: end)
                screen = .home
                Task { try? await api.sync() }
            }
            LevelView(childId: c.id, activity: act, level: level, version: pack.version, speak: speaker.say, prompt: store.promptURL(for: act, in: pack), play: speaker.play, save: store.save,
                      onDone: { wrong, revealed in
                          store.setLevel(c.id, act.id, LevelPolicy.nextLevel(current: level, maxLevel: act.levels.count, wrongAttempts: wrong, revealed: revealed))
                          finish()
                      }, onExit: finish)
            // Sinkron berkala selama bermain agar dasbor guru hampir real-time; gagal = tetap offline.
            .task { while !Task.isCancelled { try? await Task.sleep(nanoseconds: 10_000_000_000); try? await api.sync() } }
        } else { Color.clear.onAppear { screen = .home } }
    }
}
