# Bendahara v2: Aplikasi Kas Kelas & Supervisi Orang Tua

Aplikasi mobile (offline-first) berbasis Flutter yang dirancang khusus untuk membantu siswa SMP (dimulai dari kelas 7) mengelola pembukuan kas kelas secara akurat, tahan lama hingga lulus SMA, serta dilengkapi fitur supervisi bagi orang tua melalui ekspor laporan multi-rentang (1 bulan, 3 bulan, 1 tahun, dan semua rentang).

---

## Indeks Dokumen Pra-Proyek (Pre-Project Documentation)

Seluruh dokumen spesifikasi sebelum memulai proyek telah disusun secara lengkap di direktori `docs/`:

1. [**Product Requirements Document (PRD)**](docs/PRD.md)
   - Latar belakang, profil pengguna (Adik sebagai bendahara kelas 7 dan Ibu sebagai supervisor).
   - Kebutuhan fungsional lengkap (manajemen siswa, kas masuk/keluar, dan pelaporan).
   - Kebutuhan non-fungsional untuk ketahanan pencatatan 3 sampai 6 tahun.

2. [**System Architecture & Technical Specification**](docs/ARCHITECTURE.md)
   - Pemilihan teknologi (Flutter 3.47+, Dart 3.13+, Drift / SQLite WAL mode, PDF Generator).
   - Pola arsitektur bersih (*Clean Architecture*) dan diagram aliran data.
   - Strategi ketahanan penyimpanan lokal tanpa ketergantungan server luar.

3. [**Database Schema Specification & Durability Plan**](docs/DATABASE_SCHEMA.md)
   - Diagram Relasi Entitas (ERD) lengkap.
   - DDL SQL tabel-tabel utama (`academic_years`, `students`, `categories`, `transactions`, `dues_periods`, `dues_payments`).
   - Skema indeks untuk pencarian cepat, integritas kunci asing (*Foreign Key ON*), dan strategi migrasi versi.

4. [**UI/UX Design System & Anti-Slop Specification**](docs/DESIGN.md)
   - Arah desain untuk siswa SMP: Tenang, Rapi, Terstruktur, dan Bebas Elemen Palsu.
   - Definisi parameter Anti-Slop: `Dial: ENERGY 1 / RHYTHM 1 / MOTION 1`.
   - Palet warna berstandar kontras WCAG AA, skala tipografi, dan aturan *copywriting* ramah anak tanpa tanda *em dash*.

5. [**Parental Supervision & Multi-Range Export Specification**](docs/SUPERVISION_AND_EXPORT.md)
   - Rincian logika filter rentang waktu: 1 Bulan, 3 Bulan, 1 Tahun, Semua Rentang, dan Rentang Kustom.
   - Anatomi dokumen PDF resmi siap cetak lengkap dengan ringkasan eksekutif, tabel arus kas, bukti foto nota, dan kolom tanda tangan.
   - Opsi ekspor tabel Excel/CSV dan integrasi berbagi ke WhatsApp Ibu.

6. [**Project Roadmap & Implementation Milestones**](docs/ROADMAP.md)
   - 6 fase pengembangan terstruktur dari inisialisasi basis data hingga uji coba pengguna.

---

<!-- antislop:start -->
## antislop
For UI, copy, people, mobile layout, or code comments work, read `antislop.md` (core) and then the skill for the task:
- UI / visual: `skills/antislop-ui/SKILL.md`
- Copy & text: `skills/antislop-copywriting/SKILL.md`
- People: `skills/antislop-human/SKILL.md`
- Mobile / responsive: `skills/antislop-layoutmobile/SKILL.md`
- Code comments: `skills/antislop-code/SKILL.md`
Before starting, ask the user when antislop applies: during the work, or after it is done.
<!-- antislop:end -->
