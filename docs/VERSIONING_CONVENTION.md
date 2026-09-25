# Konvensi Penamaan Versi & Rilis (Bendahara Alien)

Dokumen ini mendefinisikan aturan dan alur standar penomoran versi (versioning), penamaan artefak APK, serta pembaruan berkas `app/manifest.json` untuk aplikasi **Bendahara Alien**.

---

## 1. Format Versi Standar

Versi aplikasi diatur dalam file [`pubspec.yaml`](file:///D:/project/bendehara%20alien/pubspec.yaml) dengan format:

```yaml
version: MAJOR.MINOR.PATCH+BUILD
```

Contoh saat ini:
```yaml
version: 1.0.2+3
```

### Penjelasan Komponen

| Komponen | Nama | Dampak Android OS | Dampak In-App Updater | Kapan Dinaikkan? |
| :--- | :--- | :--- | :--- | :--- |
| **`MAJOR`** | Versi Utama | Menjadi bagian dari `versionName` | Terdeteksi pembaruan | Rombak arsitektur besar, perubahan database besar (*breaking schema*). |
| **`MINOR`** | Fitur Baru | Menjadi bagian dari `versionName` | Terdeteksi pembaruan | Penambahan fitur fungsional baru yang kompatibel mundur (mis. export kustom, modul baru). |
| **`PATCH`** | Perbaikan Bug | Menjadi bagian dari `versionName` | **Wajib naik** agar terdeteksi pembaruan | Perbaikan bug, perbaikan UI, penyesuaian teks, optimasi performa. |
| **`+BUILD`** | Build Code | Menjadi `versionCode` (Android) | Diabaikan oleh SemVer in-app | **Wajib naik monoton +1** pada setiap build baru agar Android OS tidak menolak install. |

> [!IMPORTANT]
> **Catatan Kritis SemVer pada In-App Updater**:
> Mesin pembanding versi ([`lib/core/update/update_manifest.dart`](file:///D:/project/bendehara%20alien/lib/core/update/update_manifest.dart)) mengikuti standar SemVer 2.0.0 di mana sufiks `+BUILD` **diabaikan** saat membandingkan presedensi (`1.0.2+3` dianggap sama versinya dengan `1.0.2+4`).
> **Oleh karena itu, setiap kali merilis perbaikan/fitur yang ingin disebarkan via in-app update, angka `PATCH` (atau `MINOR`) WAJIB dinaikkan (contoh: `1.0.2` -> `1.0.3`).**

---

## 2. Konvensi Penamaan Aset & Tagging

1. **Git Tag**:
   - Menggunakan format `vMAJOR.MINOR.PATCH` (huruf kecil `v`).
   - Contoh: `v1.0.2`, `v1.0.3`, `v1.1.0`.

2. **Berkas APK**:
   - Format: `Bendahara-Alien-vMAJOR.MINOR.PATCH.apk`
   - Contoh: `Bendahara-Alien-v1.0.2.apk`, `Bendahara-Alien-v1.0.3.apk`.

3. **Manifest Update (`app/manifest.json`)**:
   - `latest_version`: `MAJOR.MINOR.PATCH` (misalnya `"1.0.3"`).
   - `apk_url`: Tautan langsung aset rilis GitHub:
     `https://github.com/Hylmi-S-P/alienasi/releases/download/v<VERSI>/Bendahara-Alien-v<VERSI>.apk`
   - `min_required_version`: Versi terendah yang masih boleh dipakai sebelum dipaksa update.
   - `release_notes`: Poin ringkas perubahan untuk dibaca pengguna di dialog update.

---

## 3. SOP Alur Kerja Rilis Pembaruan (Release Checklist)

Ketika ada perbaikan atau penambahan fitur baru untuk rilis publik:

1. **Bump Versi di `pubspec.yaml`**:
   - Jika bugfix: `1.0.2+3` -> `1.0.3+4`
   - Jika fitur baru: `1.0.2+3` -> `1.1.0+4`

2. **Kompilasi APK Rilis**:
   ```powershell
   flutter build apk --release
   Copy-Item "build\app\outputs\flutter-apk\app-release.apk" "Bendahara-Alien-v1.0.3.apk"
   ```

3. **Perbarui `app/manifest.json`**:
   Perbarui versi, catatan rilis, dan URL download mengarah ke rilis baru.

4. **Commit & Push ke Git**:
   ```powershell
   git add pubspec.yaml app/manifest.json docs/
   git commit -m "chore(release): bump version to v1.0.3"
   git push origin master
   ```

5. **Buat Rilis di GitHub**:
   ```powershell
   gh release create v1.0.3 "Bendahara-Alien-v1.0.3.apk" --title "v1.0.3" --notes "Catatan rilis singkat..."
   ```
