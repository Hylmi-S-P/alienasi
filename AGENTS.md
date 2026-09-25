# Aturan Pengembangan Proyek — Bendahara Alien

<!-- antislop:start -->
## antislop
For UI, copy, people, mobile layout, or code comments work, read `antislop.md` (core) and then the skill for the task:
- UI / visual: `skills/antislop-ui/SKILL.md`
- Copy & text: `skills/antislop-copywriting/SKILL.md`
- People: `skills/antislop-human/SKILL.md`
- Mobile / responsive: `skills/antislop-layoutmobile/SKILL.md`
- Code comments: `skills/antislop-code/SKILL.md`
<!-- antislop:end -->

## Testing Philosophy & Quality Engineering Rules (MANDATORY)

Setiap pengujian (testing) dan verifikasi kode pada proyek ini **WAJIB** mematuhi 8 prinsip berikut:

1. **Never write unit tests after writing the code**:
   - Dilarang menulis unit test pasca kode selesai ditulis hanya demi mengejar *code coverage*.
   - Jika unit test memang diperlukan, gunakan pendekatan TDD murni (tulis failure test sebelum menulis implementasi).
2. **Prefer end-to-end (E2E) tests as the main way to test**:
   - Prioritaskan pengujian E2E dan *integration flow* sebagai metode utama pembuktian fitur kompleks bekerja end-to-end (meliputi UI, State Management Riverpod, Database Drift, hingga File System).
3. **Make E2E tests produce an artifact that can be checked and reproduced**:
   - Setiap eksekusi test E2E harus menghasilkan artefak yang dapat diinspeksi dan direproduksi (mis. test report summary, log status transisi, file ekspor terverifikasi, atau state dump).
4. **If you need to test a system in isolation, first list all the ways it could fail. Then write the code**:
   - Jika suatu modul harus diisolasi (mis. enkripsi token lisensi atau installer service), daftarkan seluruh potensi moda kegagalan (*failure modes*: error korupsi state, manipulasi jam, offline, permission denied, race condition) sebelum menulis implementasi kodenya.
5. **For complex features, use realistic E2E scenarios with medium or high complexity**:
   - Jangan hanya menguji skenario sukses paling sederhana (*happy path*). Gunakan skenario realistis dengan kompleksitas menengah-tinggi (mis. migrasi data lama, token mendekati kedaluwarsa, gangguan koneksi saat unduh update, mutasi berturut-turut).
6. **Avoid tautological tests that only confirm what the code already says**:
   - Hindari tes tautologis yang hanya mengulang apa yang ditulis di kode (mis. mock yang meng-assert return value tiruannya sendiri atau tes trivial yang hanya membaca getter statis).
7. **Avoid tests that only detect whether code changed (change-detector tests)**:
   - Hindari tes rapuh (*brittle tests*) yang gagal hanya karena perubahan implementasi internal/refactoring padahal perilakunya (*observable behavior*) tidak berubah.
8. **For bug fixes, add a regression test only when existing behavior tests leave a real gap**:
   - Untuk perbaikan bug, hanya tambahkan regression test jika tes perilaku yang ada saat ini memang memiliki celah nyata (*real gap*) yang belum terlindungi. Jangan menambah tes redundan untuk perbaikan sepele yang sudah ter-cover.
