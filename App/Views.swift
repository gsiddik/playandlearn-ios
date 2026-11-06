import SwiftUI
import PlayAndLearnCore

private let colorOf: [String: Color] = ["red": .red, "blue": .blue, "A": .red, "B": .blue, "C": .green]
private let touch: CGFloat = 88 // target sentuh besar untuk anak

/// Parental gate: soal perkalian acak; anak prasekolah tidak dapat menyelesaikannya.
struct ParentalGate: View {
    let onPassed: () -> Void
    let onCancel: () -> Void
    @State private var a = Int.random(in: 6...9)
    @State private var b = Int.random(in: 6...9)
    @State private var input = ""
    @State private var wrong = false
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Khusus orang tua").font(.title)
            Text("Berapa \(a) × \(b) ?").font(.title3)
            TextField("Jawaban", text: $input).keyboardType(.numberPad).textFieldStyle(.roundedBorder)
            if wrong { Text("Jawaban belum tepat") }
            HStack {
                Button("Lanjut") { if Int(input) == a * b { onPassed() } else { wrong = true } }.buttonStyle(.borderedProminent)
                Button("Kembali", action: onCancel).buttonStyle(.bordered)
            }
        }.padding(24)
    }
}

struct AuthView: View {
    let busy: Bool
    let error: String?
    let onSubmit: (String, String, Bool) -> Void
    @State private var email = ""
    @State private var pw = ""
    @State private var register = true
    @State private var consent = false
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(register ? "Daftar orang tua" : "Masuk orang tua").font(.title)
            TextField("Email", text: $email).textInputAutocapitalization(.never).keyboardType(.emailAddress).textFieldStyle(.roundedBorder)
            SecureField("Password (min. 10 karakter)", text: $pw).textFieldStyle(.roundedBorder)
            if register {
                Toggle("Saya orang tua/wali dan menyetujui pengumpulan data minimum untuk progres belajar anak saya.", isOn: $consent)
            }
            if let error { Text(error).foregroundColor(.red) }
            Button(register ? "Daftar" : "Masuk") { onSubmit(email, pw, register) }
                .buttonStyle(.borderedProminent).disabled(busy || (register && !consent))
            Button(register ? "Sudah punya akun" : "Buat akun baru") { register.toggle() }
        }.padding(24)
    }
}

struct ChildPicker: View {
    let children: [ChildDef]
    let error: String?
    let onPick: (ChildDef) -> Void
    let onAdd: (String, Int) -> Void
    @State private var alias = ""
    @State private var year = "2020"
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Pilih anak").font(.title)
            ForEach(children) { c in Button(c.alias) { onPick(c) }.buttonStyle(.borderedProminent) }
            Text("Tambah anak (panggilan saja, bukan nama lengkap)").padding(.top, 16)
            TextField("Panggilan", text: $alias).textFieldStyle(.roundedBorder)
            TextField("Tahun lahir", text: $year).keyboardType(.numberPad).textFieldStyle(.roundedBorder)
            if let error { Text(error).foregroundColor(.red) }
            Button("Simpan") { onAdd(alias.trimmingCharacters(in: .whitespaces), Int(year) ?? 0) }
                .buttonStyle(.bordered).disabled(alias.isEmpty || year.count != 4)
        }.padding(24)
    }
}

/// Beranda anak: hanya ikon besar, tanpa teks yang harus dibaca.
struct ChildHome: View {
    let activities: [ActivityDef]
    let blockedReason: String?
    let onPlay: (ActivityDef) -> Void
    let onParent: () -> Void
    private let icon = ["sort": "🎨", "pattern": "🔷", "count": "🔢"]
    var body: some View {
        VStack(spacing: 16) {
            if let blockedReason {
                Text("😴").font(.system(size: 96))
                Text(blockedReason).font(.title3)
            } else {
                ForEach(activities) { a in
                    Button { onPlay(a) } label: {
                        Text(icon[a.kind] ?? "⭐").font(.system(size: 64))
                            .frame(width: 240, height: 120).background(Color.yellow.opacity(0.4)).cornerRadius(24)
                    }
                }
            }
            Text("👨‍👩‍👧").font(.system(size: 28)).padding(.top, 24).onTapGesture(perform: onParent)
        }.padding(24)
    }
}

struct ShapeView: View {
    let token: String
    var size: CGFloat = 56
    var highlight = false
    var body: some View {
        let col = colorOf[token] ?? .gray
        Group {
            switch token {
            case "B": RoundedRectangle(cornerRadius: 8).fill(col)
            case "C": Triangle().fill(col)
            default: Circle().fill(col)
            }
        }
        .frame(width: size, height: size).padding(2)
        .overlay(highlight ? Circle().stroke(Color.orange, lineWidth: 4) : nil)
    }
}
struct Triangle: Shape {
    func path(in r: CGRect) -> Path {
        var p = Path(); p.move(to: CGPoint(x: r.midX, y: r.minY)); p.addLine(to: CGPoint(x: r.maxX, y: r.maxY)); p.addLine(to: CGPoint(x: r.minX, y: r.maxY)); p.closeSubpath(); return p
    }
}

struct LevelView: View {
    let childId: String
    let activity: ActivityDef
    let level: Int
    let version: Int
    let speak: (String) -> Void
    let save: (GameEvent) -> Void
    let onDone: (Int, Bool) -> Void
    let onExit: () -> Void

    @State private var session: LevelSession?
    @State private var highlight: String?
    @State private var selected: String?
    @State private var placed = Set<String>()
    @State private var revealedAny = false

    private var task: LevelTask { activity.tasks[level - 1] }

    private func handle(_ a: Answer) {
        guard let session else { return }
        switch session.answer(a) {
        case .correct:
            speak("Bagus!")
            if case let .place(item, _) = a { placed.insert(item) }
            selected = nil
        case .levelCompleted:
            speak("Hebat!"); onDone(session.wrongAttempts, revealedAny)
        case let .tryAgain(hint):
            speak("Coba lagi ya")
            if hint >= 2 {
                switch task {
                case let .pattern(_, ans): highlight = ans
                case let .count(n, _): highlight = String(n)
                default: break
                }
            }
        case let .revealed(correct):
            revealedAny = true; highlight = correct; speak("Ini jawabannya")
            // pattern/count selesai otomatis (event completed memicu levelCompleted di sesi berikutnya); untuk sort anak melanjutkan
            if case .sort = task {} else { onDone(session.wrongAttempts, true) }
        }
    }

    var body: some View {
        VStack(spacing: 16) {
            Text("✖").font(.system(size: 28)).frame(maxWidth: .infinity, alignment: .trailing)
                .onTapGesture { session?.abandon(); onExit() }
            content
            Spacer()
        }
        .padding(16)
        .onAppear {
            if session == nil {
                session = LevelSession(childId: childId, activityId: activity.id, contentVersion: version, level: level, task: task, emit: save)
            }
        }
    }

    @ViewBuilder private var content: some View {
        switch task {
        case let .count(n, options):
            Text(String(repeating: "⭐", count: n)).font(.system(size: 36))
            HStack(spacing: 12) {
                ForEach(options, id: \.self) { o in
                    Button("\(o)") { handle(.choose(String(o))) }
                        .font(.system(size: 28)).frame(width: touch, height: touch).buttonStyle(.borderedProminent)
                        .overlay(highlight == String(o) ? RoundedRectangle(cornerRadius: 12).stroke(Color.orange, lineWidth: 4) : nil)
                }
            }
        case let .pattern(options, _):
            let seq = activity.levels[level - 1].sequence ?? []
            HStack { ForEach(Array(seq.enumerated()), id: \.offset) { ShapeView(token: $0.element) }; Text("❓").font(.system(size: 40)) }
            HStack(spacing: 12) {
                ForEach(options, id: \.self) { o in
                    ShapeView(token: o, size: 64, highlight: highlight == o).frame(width: touch, height: touch)
                        .onTapGesture { handle(.choose(o)) }
                }
            }
        case let .sort(groupsMap):
            let groups = Array(Set(groupsMap.values)).sorted()
            HStack(spacing: 16) {
                ForEach(groupsMap.keys.sorted().filter { !placed.contains($0) }, id: \.self) { id in
                    ShapeView(token: groupsMap[id] ?? "", size: 64, highlight: selected == id).onTapGesture { selected = id }
                }
            }
            HStack(spacing: 16) {
                ForEach(groups, id: \.self) { g in
                    RoundedRectangle(cornerRadius: 24).fill((colorOf[g] ?? .gray).opacity(0.25)).frame(width: 120, height: 120)
                        .overlay(highlight == g ? RoundedRectangle(cornerRadius: 24).stroke(Color.orange, lineWidth: 4) : nil)
                        .onTapGesture { if let s = selected { handle(.place(itemId: s, groupId: g)) } }
                }
            }
        }
    }
}
