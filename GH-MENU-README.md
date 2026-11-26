# GitHub Interactive Menu (gh-menu.sh)

Script interaktif berbasis Bash untuk mengelola operasi GitHub menggunakan GitHub CLI (`gh`).

## Fitur Utama
1. **Autentikasi & Info Akun**
   - Cek status autentikasi `gh auth status`
   - Menampilkan profil pengguna dan statistik repo.
2. **Kelola Repositori**
   - Daftar semua repositori publik/private Anda.
   - Clone repo dengan mudah.
   - Buat repo baru (public/private, opsi README/license).
   - Hapus repo dengan konfirmasi nama asli.
3. **Branch & Git Workflow**
   - Lihat branch di repo aktif/lain.
   - Buat branch baru dan langsung switch.
   - Switch branch dengan cepat.
   - Hapus branch lokal.
   - Status perubahan, commit, dan push otomatis.
4. **Pull Requests (PR)**
   - Daftar PR Anda di semua repo.
   - Buat PR dari branch fitur ke target branch (default `main`).
   - Cek status CI/checks dan merge PR (merge/squash/rebase).
5. **Issues**
   - Daftar issues dengan pilihan state (all, open, closed).
   - Buat issue baru.
   - Tutup issue dengan menampilkan judulnya.
6. **Pencarian & Aksi**
   - Cari kode di repository.
   - Daftar workflow Actions dan jalankan workflow secara manual.
   - Lihat run history terbaru.
   - Buat release baru dengan tag version.

## Cara Penggunaan
```bash
bash ~/Github/gh-menu.sh
```
Atau jadikan perintah global dengan symlink ke `/usr/local/bin`:
```bash
sudo ln -s ~/Github/gh-menu.sh /usr/local/bin/gh-menu
gh-menu
```
