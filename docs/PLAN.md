# Play & Learn — Rencana Pengembangan (Draft v0.1, menunggu persetujuan)

> Status: **PERENCANAAN SAJA. Belum ada kode dikembangkan.** Dokumen yang sama ada di tiga repositori
> (`playandlearn` Android, `playandlearn-portal` Web Portal + Backend, `playandlearn-ios` iOS).
> Sumber utama: dokumen "Analisis Komprehensif Ekosistem EdTech Anak Berbasis Gamifikasi" (selanjutnya **Dokumen Analisis**).
> Penanda: **[DOK]** = berasal dari Dokumen Analisis · **[BP]** = best practice umum (perlu diverifikasi) · **[ASUMSI]** = asumsi saya, butuh konfirmasi · **[KEPUTUSAN]** = menunggu persetujuan Gunady.

---

## 1. Ringkasan produk (dari Dokumen Analisis)

- Platform edukasi gamifikasi untuk anak usia dini, **usia 3–8 tahun** [DOK].
- Empat kerangka kurikulum: Montessori, Cambridge, IB PYP, Kurikulum Merdeka; sekolah dapat mengaktifkan kombinasi tertentu [DOK].
- Komponen [DOK]:
  1. Web Portal Tim Operasional (multi-tenant, CMS/level builder, ekonomi game, analitik, RBAC, kepatuhan privasi).
  2. Web Portal Sekolah & Guru (roster, kartu login QR + PIN gambar, quest dispatcher, live dashboard, gradebook diagnostik/HOTS, laporan).
  3. Web Portal Orang Tua (dashboard radar 5 area, kontrol screen time, rekomendasi aktivitas offline, pesan guru, pembayaran).
  4. Aplikasi Mobile native: mode anak (zero-text, voice-guided, drag-and-drop, adaptif, **offline-first**) + mode pendamping orang tua (parental gate, push notification).
  5. Integrasi: API Gateway, event-driven, offline-first sync (delta payload), konflik "Timestamp Priority with Server Authority", WebSocket untuk live dashboard, `Tenant_ID` di setiap request, FCM/APNs/WhatsApp Business Gateway.
- Dokumen Analisis menyebut SQLite/WatermelonDB, RabbitMQ, microservices sebagai contoh/arah. WatermelonDB adalah pustaka React Native, sedangkan Anda meminta Android & iOS native → untuk native dipakai padanan (Room/SQLite di Android, SQLite/SwiftData/GRDB di iOS) **[ASUMSI]**.

## 2. Prinsip desain (best practice PAUD & keselamatan anak)

Semua **[BP]**, perlu direview oleh praktisi PAUD/ahli hukum sebelum rilis publik:

**Pedagogi & desain bermain**
- Pembelajaran lewat bermain; aktivitas pendek (sesi anak ±5–10 menit, jeda otomatis) **[ASUMSI angka]**.
- Zero-text, instruksi suara, target sentuh besar, gesture sederhana (tap/drag), tanpa kegagalan yang menghukum — salah dijawab dengan petunjuk bertahap, bukan skor negatif [DOK: adaptive scaffolding, self-correcting].
- Beban kognitif rendah: satu konsep per layar, umpan balik instan visual+audio [DOK].
- Pemetaan tiap aktivitas ke indikator kurikulum (metadata konten), bukan hardcode di aplikasi.
- Reward intrinsik, tanpa mekanik adiktif: tanpa streak yang menghukum, tanpa timer tekanan, tanpa loot box, tanpa mata uang berbayar [DOK menyebut "tanpa memicu adiksi"].
- Aksesibilitas: kontras, ukuran, subtitle opsional untuk orang tua/guru, dukungan TalkBack/VoiceOver di mode orang tua.
- Bahasa: Indonesia dulu; Inggris menyusul (konten Cambridge) — audio multi-bahasa sudah disebut [DOK].

**Keamanan & privasi anak**
- Privacy by Design; minimisasi data: tidak ada nama lengkap/foto/lokasi anak di telemetri; ID anak berupa token pseudonim [DOK: tokenisasi].
- Kepatuhan: COPPA & GDPR-K [DOK]; **UU PDP Indonesia (UU No. 27/2022)** — data anak memerlukan persetujuan orang tua/wali **[BP; verifikasi hukum]**.
- Persetujuan orang tua terverifikasi (verifiable parental consent) sebelum akun anak aktif; untuk jalur sekolah, dasar persetujuan oleh sekolah + pemberitahuan ke orang tua **[ASUMSI, perlu konsultasi hukum]**.
- **Tanpa iklan, tanpa SDK pelacak pihak ketiga/iklan, tanpa tautan keluar, tanpa chat/UGC antar anak, tanpa pembelian dalam aplikasi di mode anak.** Pembayaran hanya di portal/mode orang tua di balik parental gate.
- Parental gate (teka-teki dewasa/biometrik) [DOK] untuk semua area orang tua.
- Enkripsi in transit (TLS) dan at rest; data lokal di perangkat dienkripsi; kebijakan retensi & anonimisasi otomatis [DOK].
- Kebijakan toko: Google Play *Families Policy* dan Apple *Kids Category* **[BP; verifikasi syarat terbaru saat pengajuan]**.
- Hak subjek data: ekspor & hapus data anak atas permintaan orang tua.
- Isolasi tenant: `Tenant_ID` diverifikasi di gateway dan DB (row-level security) [DOK].

## 3. Arsitektur target

```
 Android (Kotlin)      iOS (Swift)         Portal Web (3 peran)
   Child + Parent       Child + Parent     Ops / Sekolah-Guru / Orang tua
        \                   |                  /
         +------- API Gateway (HTTPS, OAuth 2.0 / OIDC, Tenant_ID) -------+
                              |
                    Backend (modular)  ── Event bus ──> worker (telemetri, gradebook, notifikasi)
                     |        |                 
                PostgreSQL  Object storage (aset, worksheet)     WebSocket (live dashboard, tahap lanjut)
```

**Kontrak API bersama**: satu spesifikasi **OpenAPI** sebagai sumber kebenaran; klien Android/iOS/Portal digenerate/divalidasi dari kontrak itu. Kontrak versi 1 hidup di repo portal (`contracts/openapi.yaml`) dan disalin/di-pin oleh repo mobile **[KEPUTUSAN #2]**.

**Rekomendasi stack (semua [ASUMSI], dapat diubah — lihat Keputusan):**

| Lapisan | Rekomendasi | Alasan |
|---|---|---|
| Android | Kotlin, Jetpack Compose, Room (SQLite), WorkManager untuk sync, Hilt | native, offline-first, standar Google |
| iOS | Swift, SwiftUI, SwiftData atau GRDB (SQLite), BackgroundTasks | native, padanan Android |
| Backend | **Modular monolith** dulu, dapat dipecah menjadi microservices bila beban menuntut | Dokumen menyarankan event-driven microservices [DOK]; untuk MVP tim kecil, monolit modular + outbox event lebih murah & aman; antarmuka modul sudah dipisah supaya bisa dipecah |
| Bahasa backend | TypeScript (NestJS) *atau* Kotlin (Ktor/Spring) | [KEPUTUSAN #3] |
| DB | PostgreSQL + row-level security per tenant | isolasi tenant [DOK] |
| Event bus | Tahap awal: outbox + antrian di Postgres; RabbitMQ saat dibutuhkan [DOK menyebut RabbitMQ] | kurangi kompleksitas ops di MVP |
| Portal | React + TypeScript (Next.js/Vite), satu aplikasi dengan 3 area peran | berbagi komponen; RBAC [DOK] |
| Push | FCM (Android), APNs (iOS); WhatsApp Business Gateway belakangan [DOK] | |
| CI | GitHub Actions per repo | |

**Sinkronisasi offline-first [DOK]**
- Mobile menulis event gameplay ke DB lokal (append-only, ber-ID unik/idempoten + timestamp perangkat).
- Sync: push batch delta event → server; pull "paket tugas/konten" bersertifikat versi.
- Konflik: progres anak tidak pernah dihapus (event append-only digabung); kebijakan/konfigurasi (screen time, penugasan) memakai **server authority** [DOK].
- Konten diunduh sebagai *content pack* berversi sehingga rilis konten tidak butuh update toko aplikasi [DOK].

## 4. Roadmap bertahap & incremental

Setiap increment: dapat didemokan, ada **checkpoint** (tag git + catatan di repo) dan commit berkala di tiap repo. Perkiraan durasi sengaja tidak dicantumkan karena ukuran tim belum diketahui **[KEPUTUSAN #8]**.

### Increment 0 — Fondasi (tanpa fitur pengguna)
- Finalisasi keputusan (bagian 6), struktur repo, konvensi kode, CI (lint+test), lisensi/kepemilikan.
- Kontrak API v0 (auth, tenant, kelas, anak, content pack, event sync) dalam OpenAPI.
- **Dokumen privasi/data-flow** (data apa yang dikumpulkan, mengapa, retensi) + DPIA singkat.
- Skema DB awal + RLS tenant; model event gameplay.
- Prototipe desain (UX anak zero-text) untuk di-review ahli PAUD.
- **Checkpoint 0:** keputusan disetujui, CI hijau di 3 repo, kontrak v0 disetujui.

### Increment 1 — MVP "Satu anak bermain offline, guru melihat hasil"
Tujuan: membuktikan loop inti [DOK: closed-loop] dengan cakupan minimum.
- **Backend:** tenant, user & RBAC dasar, kelas/roster, anak, kartu login QR + PIN gambar, penerbitan content pack, penerimaan batch event.
- **Android (platform pertama; lihat Keputusan #4):** login anak via QR/PIN gambar, beranda zero-text, **2–3 aktivitas** (mis. mencocokkan/memilah drag-and-drop bergaya Montessori; pola visual; hitung 1–10 — judul final dengan ahli PAUD), umpan balik suara+visual, petunjuk bertahap sederhana (aturan tetap, belum adaptif), penyimpanan lokal, sync event, jeda otomatis.
- **Portal:** area Sekolah/Guru minimum — login guru, buat kelas, tambah anak, cetak kartu QR, tampilan hasil per anak (ringkas). Konten MVP di-seed lewat berkas/CLI (belum ada CMS).
- **Privasi MVP:** tanpa SDK pihak ketiga, persetujuan sekolah/orang tua tercatat, retensi dasar, hapus data.
- **Checkpoint 1:** demo end-to-end (guru buat kelas → anak main offline → sync → guru lihat hasil); uji pada perangkat Android nyata; review keselamatan anak (daftar periksa bagian 2).

### Increment 2 — Orang tua & kontrol
- Backend: akun orang tua, persetujuan, aturan screen time (server authority), push.
- Mobile: **mode pendamping orang tua** dengan parental gate, batas durasi/jam, penguncian otomatis; push FCM.
- Portal Orang Tua v1: dashboard perkembangan (radar 5 area [DOK]) dengan narasi sederhana, kontrol screen time.
- **Checkpoint 2:** orang tua mengatur batas waktu dan perubahan tiba di perangkat anak (online & setelah kembali online).

### Increment 3 — iOS paritas
- iOS: fitur Increment 1+2 (child app, parent mode, sync, APNs) memakai kontrak yang sama.
- Uji lintas platform pada kontrak (contract tests).
- **Checkpoint 3:** satu kelas campuran Android+iOS tersinkron benar.

### Increment 4 — Guru: penugasan & penilaian
- Quest Dispatcher (pilih modul → tugaskan kelas), konfigurasi kerangka kurikulum per sekolah [DOK].
- Adaptive scaffolding v1 (tingkat kesulitan berdasar performa), telemetri lebih kaya.
- Diagnostic Gradebook v1 (konversi telemetri → capaian per kerangka), generator laporan perkembangan.
- **Checkpoint 4:** laporan kelas diverifikasi oleh guru/ahli PAUD (validitas pemetaan indikator).

### Increment 5 — Portal Operasional & Konten
- Tenant provisioning, lisensi/langganan, RBAC internal, DAM, **CMS + level builder no-code**, pipeline staging→publish berversi [DOK].
- Alat balancing ekonomi/gamifikasi + katalog avatar kosmetik [DOK], dengan pagar anti-adiksi.
- Audit kepatuhan & anonimisasi otomatis [DOK].
- **Checkpoint 5:** tim konten merilis modul baru tanpa update toko aplikasi.

### Increment 6 — Real-time & komunikasi
- Classroom Live Dashboard (WebSocket), peer-tutoring suggestion, pesan terenkripsi guru–orang tua, rekomendasi aktivitas offline & worksheet, dokumentasi proyek (PBL).
- Pembayaran/SPP & tanda terima, WhatsApp gateway [DOK] (butuh keputusan penyedia & regulasi).
- Hardening: uji beban, observabilitas/SLA dashboard [DOK], pentest, persiapan rilis toko (Families/Kids).
- **Checkpoint 6:** kandidat rilis.

> Urutan di atas adalah usulan. Fitur Dokumen Analisis yang belum masuk increment mana pun (mis. dokumentasi proyek fisik, analitik makro) berada di Increment 5–6 dan dapat dipindah.

## 5. Strategi checkpoint & git

- Branch kerja per increment; commit kecil dan sering; tag `checkpoint-N` di tiap repo saat checkpoint tercapai.
- Perubahan kontrak API harus berurutan: kontrak → backend → klien; tiap repo mencatat versi kontrak yang dipakai.
- PR kecil, CI wajib hijau, tanpa melewati/menonaktifkan tes.
- Repo mobile & portal saat ini kosong; isi awal commit adalah dokumen ini.

## 6. Keputusan yang dibutuhkan dari Gunady

| # | Keputusan | Rekomendasi saya |
|---|---|---|
| 1 | **Usia & fokus MVP**: dokumen menyebut 3–8 th; MVP sebaiknya dipersempit | MVP usia **5–6 tahun** (TK B/PAUD), usia lain menyusul |
| 2 | **Lokasi backend & kontrak API**: tidak ada repo backend; | Backend di repo `playandlearn-portal` (`apps/api`), kontrak OpenAPI di `contracts/`; alternatif: repo baru `playandlearn-api` |
| 3 | **Bahasa/framework backend** | TypeScript/NestJS (selaras Portal); alternatif Kotlin |
| 4 | **Platform mobile pertama** | Android dulu (Increment 1), iOS menyusul (Increment 3). Perlu dicatat: build iOS membutuhkan macOS/Xcode, yang tidak ada di lingkungan cloud ini sehingga iOS tidak dapat dikompilasi/diuji di sini |
| 5 | **Kurikulum MVP**: mulai dari satu kerangka atau semua? | Mulai **Montessori + Kurikulum Merdeka** (selaras konteks Indonesia); Cambridge/IB PYP kemudian. Perlu ahli PAUD untuk validasi pemetaan |
| 6 | **Model bisnis & jalur akun**: B2B sekolah (tenant) dulu, atau orang tua langsung? | B2B sekolah dulu sesuai Dokumen Analisis; jalur orang tua mandiri menyusul |
| 7 | **Hosting/cloud & region data** (UU PDP, residensi data) | Perlu keputusan Anda (mis. region Indonesia/Asia Tenggara); belum saya pilih |
| 8 | **Tim/jadwal**: ukuran tim, target tanggal | Menentukan apakah monolit modular cukup & durasi per increment |
| 9 | **Aset kreatif**: ilustrasi, animasi, rekaman suara anak berbahasa Indonesia | Siapa yang menyediakan? Untuk MVP saya pakai placeholder berlisensi jelas |
| 10 | **Nama/branding & identitas bundle** (mis. `id.playandlearn...`) | Perlu konfirmasi sebelum scaffold |
| 11 | **Nasihat hukum & ahli PAUD** untuk persetujuan orang tua dan validasi kurikulum | Sangat disarankan sebelum rilis publik |

## 7. Risiko utama

- Cakupan Dokumen Analisis sangat luas (4 aplikasi + ekosistem) → disiplin MVP.
- Kepatuhan data anak & kebijakan toko (Families/Kids) → desain dari awal, bukan belakangan.
- Validitas pedagogis gradebook/HOTS dari telemetri → perlu validasi ahli; jangan dijual sebagai diagnosis klinis.
- iOS tidak bisa dibangun/diuji di lingkungan Linux ini → butuh macOS/CI macOS (mis. GitHub Actions macOS runner) untuk build iOS.
- Sebagian referensi di Dokumen Analisis adalah situs vendor/blog; klaim teknis dijadikan arah, bukan fakta mutlak.
