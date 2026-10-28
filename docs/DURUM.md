# Kavis Study: Durum (28 Ekim 2026)

Bu dosya Kian için: ne bitti, ne bekliyor, kim ne yapacak. Ayrıntı için `TODO.md`.

## Bitenler (hepsi GitHub'da, `main`)
- **Web:** tüm sayfalar gerçek veriyle; Bugünün tekrarı, sınav merkezi, yardım sohbeti, kullanım şartları ve gizlilik taslağı, molekül görüntüleyici, soru türleri (çoktan seçmeli, boşluk doldurma, yazılı), Google ile giriş kodu.
- **iPhone:** giriş, onboarding, dersler, PDF / fotoğraf / ses kaydı yükleme, okuyucu (molekül, kalemle not, sesli okuma), asistan (tablolar, soru çözdürme, geçmiş, "Ben anlatayım", sesli mod), kartlar, quiz (yazılı sorular dahil), plan, ilerleme, ders özeti, Genel özet, sınav merkezi, ayarlar, profil, Premium ekranı (Apple satın alma kodu hazır), paylaşım linki açma, "Soru örneklerim", cihazdaki dersler (çevrimdışı kopya), gerçek cihaz adı. **iPad:** sol menü, geniş okuyucu + asistan paneli, PDF üstüne kalemle not, geniş ana sayfa / plan / ilerleme / ayarlar.
- **Sunucu (canlı, 27 Ekim):** `open-share` (v1, iPhone paylaşım linkini açar), `process-material` (v9, bozuk yazı tipli PDF'i otomatik OCR ile okur), `assistant` (v9, cevapta `[E1]` yazmaz). Deneme süresi bitince `build-exam`, `import-timetable`, `group-sections` ve `process-recording` artık sunucuda da kilitli (403). Web: başka cihazdan çıkış yaptırılınca girişe döner, `[E1]` gizli, küçük PDF'ler "0,1 MB" görünür.
- **Web (kodda, yayında değil):** sahip sayfasında "Bu ayın harcaması" tablosu (en çok harcayanlar, bütçe çizgisi, önbellek payı); iPhone fotoğrafları (HEIC) tarayıcıda JPEG'e çevriliyor.
- **Sunucu (canlı):** gece planlayıcısı, cihazdan anında çıkış, sınav sonucu bildirimi, yardım sohbeti, soru türleri (migration `20261027125135` + fonksiyonlar), günlük yapay zekâ puanlama sınırı.

## Senin yapacakların
**Yarın alacağın hesaplar**
1. Apple Developer hesabı (99 $/yıl): Apple ile giriş, App Store Premium ürünleri, TestFlight, bildirim anahtarı (APNs).
2. Google Cloud OAuth anahtarı (Google ile giriş kodu hazır, anahtar yok).
3. E-posta sağlayıcısı (6 haneli kod için).
4. Supabase Pro planı (50 MB üstü PDF).

**Panelde yapılacak**
5. Supabase → Authentication → URL Configuration: Site URL'yi alan adına çevir, Redirect URLs'e yeni ve eski adresi ekle (alan adını aldığında).
6. Alan adı satın al (ör. kavis.study) ve Vercel'e bağla.

**Yayından önce**
7. Avukat kontrolü: kullanım şartları, gizlilik/KVKK, Premium ve deneme metinleri.
8. Farsça, Arapça ve İngilizce metinleri ana dili olan biri okusun.
9. Gerçek iPhone'da ses kaydını yazıya çevirmeyi dene (simülatörde çalışmıyor).
10. Anthropic anahtarı ~22 Ocak 2027'de bitiyor, yenile.

## Son canlıya alınanlar (28 Ekim 2026)
- **Önbellek (prompt caching) + sahip harcama tablosu** — 28 Ekim 2026'da canlıya alındı: migration `20261028133745_usage_cache_tokens`, fonksiyonlar `assistant` v10, `more-questions` v3, `lesson-summary` v3, `generate-quiz` v4, `owner-overview` v2. Ücretli yapay zekâ testi yapılmadı; ilk gerçek sorularda sahip sayfasında önbellek oranı görünür.
- **Davet kodu (30 gün ücretsiz Premium)** — 28 Ekim 2026'da canlıya alındı: migration `20261028133734_promo_codes`, Edge Function `redeem-code` v1 (`verify_jwt = true`), web push ile yayında. Kalan: iPhone için yeni TestFlight sürümü; kod yapmak için `supabase/scripts/make-codes.sql`'i Supabase SQL Editor'e yapıştır. Aylık yapay zekâ bütçesi öğrenci başına 3 $ olarak kalır.
- **Aynı PDF'in ortak işlenmesi** canlıya alındı (28 Ekim): migration `20261028120304_shared_lessons.sql` + `process-material` (v10). Canlıda kontrol edildi: sütun var, kopyalama fonksiyonunu sadece sunucu çağırabiliyor, öğrenci parmak izini değiştiremiyor. Aynı dosyayı yükleyen ikinci öğrenci için yapay zekâ çağrılmaz. Gizlilik metnine bu cümle eklendi (28 Ekim, 4 dilde, madde 4); avukat kontrolüne dahil.
- `build-plan` (sadece kod taşındı): push açılınca birlikte yüklenecek.
- Takılı kalan iki ders: ben başlatamam, ders sahibi öğrencinin kendi girişi gerekir. `8479526d…` sahibi siteyi açınca kendiliğinden devam eder (~0,2–0,3 $), `48aef5e6…` sahibi "OCR ile oku" düğmesine basınca yeniden okunur (~0,3–0,5 $). Sahiplerine haber vermek yeterli: `48aef5e6…` (durum `needs_ocr`, yeni sürümle OCR ile okunabilir) ve `8479526d…` (66 sayfa, 25 Ekim'den beri "işleniyor").

## Benim yapacaklarım
**Hesaplar gelmeden:** hepsi bitti (iPhone arayüz testleri yeniden yazıldı, çevrimdışı kopya yapıldı). Kalan: önceden indirme ("Çalıştığım PDF'leri indir").
**Hesaplar gelince:** Apple ve Google ile giriş, App Store ürünleri ve satın alma denemesi, bildirimleri açmak (anahtar + iki fonksiyon), e-posta kodu, TestFlight.
**Yayın günü:** test anahtarlarını ve örnek veriyi silmek, sitenin Google'da görünmesini açmak, App Store linklerini koymak.
**Sonra:** iPad'in kalan küçük işleri, Android.

## Oturumlar (Claude'da)
Her iş ayrı bir oturumda yapıldı. Biten hepsi "Bitti" grubunda. Yeni iş için yeni oturum aç; eskisine dönmen gerekmez.
