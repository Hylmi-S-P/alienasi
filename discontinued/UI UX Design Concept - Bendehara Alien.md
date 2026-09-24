---
type: ui-ux-design-concept
project: Bendehara Alien
status: draft (revisi v2 - minimalis)
created: 2026-08-08
updated: 2026-08-08
tags:
  - ui-ux
  - design
  - planning
---

# UI UX Design Concept - Bendehara Alien (v2: Minimalis Jernih)

## Keputusan Arah
Revisi total dari konsep "playful" (v1, ditolak user: dianggap AI-slop). Arah baru: **minimalis ala fintech modern** (referensi: Stripe, ING, Material 3 clean) — bersih, satu warna aksen, tipografi jelas, ruang kosong cukup — TAPI tetap mudah dipahami anak (target sentuh besar, status visual tegas, teks pendek).

**Prinsip:** *"Kalau bisa dihapus, hapus. Kalau harus tetap, buat jelas."*

## Anti-Pattern (yang DIBUANG dari v1)
- ❌ Emoji di mana-mana (💰👆🎉🤑⏳) — hanya boleh ikon outline Material
- ❌ Warna ungu "playful" + FAB oranye + appbar berwarna
- ❌ Radius super membulat (24) di semua komponen
- ❌ Animasi "bounce/pop" easeOutBack
- ❌ Banner perayaan 🎉 "Hore!"
- ❌ Bahasa manis "yuk!", "Tambahkan siswa dulu, yuk!"
- ❌ Avatar 8 warna-warni pelangi
- ❌ Emoji status di riwayat (✅⏳🔴)

## Riset (sumber)
- Fintech minimalist = kepercayaan: 1-2 jenis font sans-serif, spacing konsisten, base color dominan (biru/hijau) + SATU warna aksi kontras; hijau=sukses, merah=masalah (Stripe, ING, eleken.co fintech examples, ergomania.eu minimalist fintech)
- Tipografi mobile 2026: skala 3-4 ukuran (headline 32-40 / body 16-18 / secondary 12-14), WCAG AA 4.5:1, spacing grid 8pt, padding 16-24 (uiuxdesigning.com, gluestack, zignuts)
- Material 3: token 3 lapis (primitive → semantic → component), motion "memberi makna" (halus, bukan bouncy), Roboto/Noto (m3.material.io)
- Risiko "too plain": beri satu highlight warna pada elemen penting (graphicdesignforum fintech thread)

## Design Tokens (v2)

### Warna
| Token | Nilai | Pakai untuk |
| --- | --- | --- |
| background | `#FFFFFF` / `#F7F8FA` (surface) | layar / kartu |
| text-primary | `#1A1D21` | judul, angka utama |
| text-secondary | `#6B7280` | label, keterangan |
| border | `#E5E7EB` | garis kartu (bukan shadow tebal) |
| primary (aksi) | `#2563EB` (biru) *pilihan user* | tombol utama, tab aktif |
| success | `#16A34A` | status lunas, angka terkumpul |
| danger | `#DC2626` | status belum, sisa |
| success-bg | `#F0FDF4` | latar baris lunas (tipis) |
| danger-bg | `#FEF2F2` | latar baris belum (opsional, tipis) |

### Bentuk & Spasi
- Radius: kartu **12**, tombol **10**, input **10** (bukan 18-24)
- Elevasi: flat — kartu = putih + border `#E5E7EB` 1px (gaya Stripe), tanpa shadow
- Grid: 8pt (4/8/12/16/24/32); padding layar 16; antar-kartu 12
- Target sentuh: minimal 48x48dp; baris siswa tinggi 64-72dp

### Tipografi (font sistem Roboto — tanpa custom font)
| Role | Ukuran | Berat |
| --- | --- | --- |
| Angka utama (ringkasan) | 24 | Bold (tabular) |
| Judul layar | 20 | Semibold |
| Nama siswa / isi | 16 | Regular (nama: Semibold) |
| Label / keterangan | 13 | Regular, warna secondary |
| Status | 14 | Semibold |

## Spesifikasi Layar

### Tab 1 - Kas (Hari Ini)
- AppBar: **putih, teks gelap**, judul "Kas Hari Ini" kiri, 20 semibold (TANPA warna, TANPA emoji)
- Baris tanggal: "Senin, 8 Agustus 2026" 14 secondary + ikon chevron outline, tengah
- Kartu ringkasan: putih + border. Isi:
  - Baris 1: "20/25" besar bold hijau (angka) + "siswa sudah bayar" 14 secondary
  - Progress tipis (tinggi 4-6px, hijau di atas abu)
  - Baris 2: "Terkumpul Rp40.000" (hijau, bold) | "Sisa Rp10.000" (merah) — 14-16
  - Baris 3 (kecil): "Rp2.000/anak" + TextButton "Ubah"
- Panduan: SATU baris kecil abu: "Ketuk siswa yang sudah bayar" (ikon touch outline, TANPA emoji)
- Baris siswa: putih + border radius 12, avatar 36 lingkaran abu (#EEF1F4) + inisial gelap; nama 16 semibold; kanan: status **teks+ikon kecil** — Lunas: hijau + check; Belum: merah + jam/lingkaran. Baris lunas: latar `#F0FDF4` tipis.
- Seluruh baris tappable; transisi status: fade/swap warna 150ms (TANPA bounce)
- Tombol "Semua lunas": TextButton dengan ikon, hanya muncul jika ada yang belum
- Empty state: ikon outline (people), 1 baris "Belum ada siswa", tombol primary "Tambah Siswa"

### Tab 2 - Anak
- List putih + border, avatar abu + inisial, nama 16, panah chevron kanan
- FAB: primary biru, ikon + (bukan oranye)
- Form: input putih border, label kecil; tombol primary "Simpan" (radius 10, tinggi 52)

### Tab 3 - Catatan
- Kartu rekap: sama gaya ringkasan; "Total Rp...", "X dari Y bayaran", "N hari"
- Baris hari: tanggal 14 semibold, "20/25 bayar" 13 secondary, kanan total Rp bold; indikator: titik kecil hijau (lunas semua) / abu (sebagian) — TANPA emoji

### Tab 4 - Atur
- Input label + border; tombol "Simpan" primary; teks kecil abu di bawah

### Profil Siswa
- Avatar abu besar (48), nama 20 semibold, NIS 14 secondary
- 3 statistik kartu: "Sudah bayar: N hari" (hijau), "Tunggakan: N hari" (merah), "Nominal: Rp" (teks primary)
- Riwayat: baris tanggal + status (ikon check/jam outline) + nominal

## Interaksi
- Ketuk baris siswa = toggle (satu-satunya aksi utama layar Kas)
- Perubahan status: warna berubah instan + ikon; TANPA animasi mencolok
- Auto-save; Snackbar hanya untuk error penting (bukan "tersimpan")
- Tanggal masa depan tetap diblokir (ikon kanan nonaktif)

## Aksesibilitas
- Kontras ≥ 4.5:1 (teks), status tidak hanya warna (ada ikon + teks)
- Target sentuh ≥ 48dp
- Tidak ada ketergantungan pada warna saja (ikona ikut)

## Ditunda (bukan sekarang)
- Suara, foto profil, gamifikasi badge/XP, dark mode — ditunda agar tetap minimal & ringan

## Related Notes
- [[Docs/PRD - Bendehara Alien]]
- [[Docs/TRD - Bendehara Alien]]
- [[Docs/App Flow - Bendehara Alien]]
