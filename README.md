# Website Gereja Injil Kristus — sinkronisasi online

Website mempertahankan desain HTML yang dikirim dan memakai Supabase untuk database, autentikasi admin, penyimpanan poster, serta pembaruan Realtime. Netlify meng-host file statisnya.

## Yang disiapkan
- Konten publik (renungan, jadwal, poster, event, kontak, dan tentang gereja) dibaca dari satu baris `site_content`.
- Perubahan konten admin disimpan ke database dan dikirim ke perangkat lain melalui Supabase Realtime.
- Poster diunggah ke Supabase Storage, bukan disimpan sebagai base64 di browser.
- Login admin menggunakan Supabase Auth email/kata sandi. Tidak ada kata sandi admin bawaan di source code.
- Hanya user yang terdaftar di `admin_users` dapat mengubah konten, mengelola poster, dan membaca/mengubah/menghapus pengajuan.
- Pengajuan formulir pengunjung masuk ke database bersama. Pengunjung dapat mengirim, tetapi tidak dapat membaca data pengajuan orang lain.
- Tema terang/gelap dan pilihan aksesibilitas tetap berjalan di browser masing-masing.

## A. Buat proyek Supabase
1. Buka https://supabase.com dan buat proyek baru.
2. Buka **Project Settings → API** (atau **Connect**) lalu salin **Project URL** dan **anon/public key**. Jangan pernah memakai `service_role` key di website.
3. Buka **SQL Editor**, buat query baru, tempel seluruh isi `supabase-setup.sql`, lalu jalankan.
4. Buka **Authentication → Sign In / Providers** dan pastikan Email aktif.
5. Buka **Authentication → Settings** dan matikan public sign-ups / user signups. Admin dibuat manual agar orang umum tidak dapat mendaftar sebagai pengguna.
6. Buka **Authentication → Users → Add user**, buat akun admin dengan email dan kata sandi yang kuat. Jika ada opsi konfirmasi email, tandai email sebagai terkonfirmasi untuk akun admin.
7. Salin UUID user admin yang baru dibuat.
8. Di SQL Editor, jalankan perintah berikut dengan UUID asli:

   ```sql
   insert into public.admin_users (user_id)
   values ('GANTI_DENGAN_UUID_USER_ADMIN');
   ```

   Jangan masukkan email atau kata sandi ke tabel ini; yang dibutuhkan hanya UUID dari Auth Users.

## B. Hubungkan HTML ke Supabase
1. Buka `supabase-config.js`.
2. Ganti `GANTI_DENGAN_SUPABASE_PROJECT_URL` dengan Project URL.
3. Ganti `GANTI_DENGAN_SUPABASE_ANON_KEY` dengan anon/public key.
4. Simpan file. Kedua nilai ini memang boleh berada di frontend; keamanan dilakukan oleh RLS. **Jangan pernah menaruh service_role key di sini.**

## C. Deploy ke Netlify
1. Unggah seluruh folder proyek ini ke repositori GitHub. Untuk Netlify Drop, deploy isi folder `public` saja setelah konfigurasi Supabase diisi.
2. Konfigurasi `netlify.toml` sudah menetapkan `public` sebagai folder publish. `public/index.html` dan `public/supabase-config.js` akan di-deploy; SQL/README berada di luar folder publik.
3. Deploy/redeploy Netlify.
4. Buka website, pilih **Admin**, masuk dengan email dan kata sandi Supabase, lalu ubah renungan atau jadwal dan simpan.
5. Buka website di perangkat/browser lain. Konten harus diperbarui otomatis saat Realtime aktif; bila koneksi Realtime terputus, muat ulang halaman untuk mengambil data terbaru.

## D. Tes setelah deploy
- Ganti renungan lalu simpan; periksa dari perangkat lain.
- Unggah poster kecil terlebih dahulu; pastikan URL gambar muncul di halaman publik.
- Kirim formulir percobaan; pastikan pengajuan masuk ke dashboard admin dan ekspor CSV/Excel/Word/cetak tetap tersedia.
- Coba login menggunakan akun Auth yang tidak ada di `admin_users`; akses admin seharusnya ditolak.
- Periksa **Supabase → Database → Replication** atau status Realtime jika pembaruan langsung belum muncul. SQL setup mencoba menambahkan tabel yang dibutuhkan ke publikasi `supabase_realtime`.

## Catatan penting
- Pengajuan berisi informasi pribadi. Batasi akses admin, gunakan kata sandi unik, dan jangan bagikan sesi admin.
- Formulir publik terbuka untuk pengiriman; sebelum pemakaian produksi skala besar, pertimbangkan CAPTCHA/rate limiting dan kebijakan privasi.
- Poster saat ini dihapus dari jadwal dengan mengosongkan URL di konten; file lama di Storage tidak otomatis dihapus. Hapus file lama dari Storage secara berkala jika perlu.
- Konten yang sebelumnya tersimpan hanya di `localStorage` browser lama tidak otomatis berpindah. Sebelum mengganti situs lama, ekspor/catat konten lokal yang ingin dipertahankan dan masukkan kembali melalui dashboard admin setelah koneksi Supabase siap.
- File ini tidak dapat benar-benar tersambung ke proyek Supabase milik Anda sampai URL/key diisi dan SQL dijalankan. Setelah langkah tersebut, barulah sinkronisasi lintas perangkat aktif.
