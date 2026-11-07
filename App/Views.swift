import SwiftUI
import PlayAndLearnCore
import VisionKit

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

/// Urutan gambar PIN baku (sama di semua klien): anjing, kucing, ikan, pohon, mobil, apel, bintang, bulan, balon.
let pinIcons = ["🐶", "🐱", "🐟", "🌳", "🚗", "🍎", "⭐", "🌙", "🎈"]

/// Pilihan peran tanpa teks: murid atau orang tua (di balik gerbang).
struct RoleChooser: View {
    let onParent: () -> Void
    let onStudent: () -> Void
    var body: some View {
        VStack(spacing: 24) {
            Text("🎒").font(.system(size: 72)).frame(width: 240, height: 140).background(Color.blue.opacity(0.2)).cornerRadius(24).onTapGesture(perform: onStudent)
            Text("👨‍👩‍👧").font(.system(size: 72)).frame(width: 240, height: 140).background(Color.green.opacity(0.2)).cornerRadius(24).onTapGesture(perform: onParent)
        }
    }
}

/// Pemindai QR memakai VisionKit (butuh izin kamera, perangkat dengan kamera).
struct QRScanner: UIViewControllerRepresentable {
    let onCode: (String) -> Void
    func makeUIViewController(context: Context) -> DataScannerViewController {
        let vc = DataScannerViewController(recognizedDataTypes: [.barcode(symbologies: [.qr])], isHighlightingEnabled: true)
        vc.delegate = context.coordinator
        try? vc.startScanning()
        return vc
    }
    func updateUIViewController(_ vc: DataScannerViewController, context: Context) {}
    func makeCoordinator() -> Coordinator { Coordinator(onCode: onCode) }
    final class Coordinator: NSObject, DataScannerViewControllerDelegate {
        let onCode: (String) -> Void
        init(onCode: @escaping (String) -> Void) { self.onCode = onCode }
        func dataScanner(_ s: DataScannerViewController, didAdd items: [RecognizedItem], allItems: [RecognizedItem]) {
            for case let .barcode(b) in items { if let v = b.payloadStringValue { onCode(v); return } }
        }
    }
}

/// Login murid: pindai QR kartu lalu ketuk 3 gambar PIN.
struct StudentLogin: View {
    let busy: Bool
    let error: String?
    let onSubmit: (String, [Int]) -> Void
    let onBack: () -> Void
    @State private var code = ""
    @State private var pin: [Int] = []
    @State private var scanning = false
    var body: some View {
        VStack(spacing: 12) {
            Text("✖").font(.system(size: 28)).frame(maxWidth: .infinity, alignment: .trailing).onTapGesture(perform: onBack)
            if scanning && DataScannerViewController.isSupported {
                QRScanner { code = $0; scanning = false }.frame(height: 260).cornerRadius(16)
            } else {
                Text(code.isEmpty ? "📷" : "✅").font(.system(size: 56)).frame(width: 200, height: 100)
                    .background(code.isEmpty ? Color.yellow.opacity(0.4) : Color.green.opacity(0.4)).cornerRadius(24)
                    .onTapGesture { scanning = true }
            }
            HStack { ForEach(0..<3, id: \.self) { i in Text(i < pin.count ? pinIcons[pin[i]] : "⚪").font(.system(size: 44)) } }
            ForEach(0..<3, id: \.self) { r in
                HStack { ForEach(0..<3, id: \.self) { c in
                    Text(pinIcons[r * 3 + c]).font(.system(size: 40)).frame(width: 72, height: 72)
                        .background(Color.gray.opacity(0.15)).cornerRadius(16)
                        .onTapGesture { if pin.count < 3 { pin.append(r * 3 + c) } }
                } }
            }
            HStack {
                Button("⌫") { _ = pin.popLast() }.buttonStyle(.bordered)
                Button("▶") { onSubmit(code, pin) }.buttonStyle(.borderedProminent).disabled(busy || code.isEmpty || pin.count != 3)
            }
            if let error { Text("⚠ \(error)") }
        }.padding(24)
    }
}

struct StudentSettings: View {
    let onLogout: () -> Void
    let onBack: () -> Void
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Akun murid").font(.title)
            Button("Keluar dari akun murid", action: onLogout).buttonStyle(.borderedProminent)
            Button("Kembali", action: onBack).buttonStyle(.bordered)
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
    let assigned: Set<String>
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
                ForEach(activities.sorted { assigned.contains($0.id) && !assigned.contains($1.id) }) { a in
                    Button { onPlay(a) } label: {
                        Text((assigned.contains(a.id) ? "📌" : "") + (icon[a.kind] ?? "⭐")).font(.system(size: 64))
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
    let prompt: URL?
    let play: (URL) -> Void
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
            // petunjuk 1 = ulang instruksi suara (rekaman bila ada)
            if hint == 1, let prompt { play(prompt) } else { speak("Coba lagi ya") }
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
                if let prompt { play(prompt) } // instruksi suara saat level mulai
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
