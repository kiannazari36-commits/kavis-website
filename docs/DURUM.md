# Kavis Study: Durum (27 Ekim 2026, gece)

Bu dosya Kian için: ne bitti, ne bekliyor, kim ne yapacak. Ayrıntı için `TODO.md`.

## Bitenler (hepsi GitHub'da, `main`)
- **Web:** tüm sayfalar gerçek veriyle; Bugünün tekrarı, sınav merkezi, yardım sohbeti, kullanım şartları ve gizlilik taslağı, molekül görüntüleyici, soru türleri (çoktan seçmeli, boşluk doldurma, yazılı), Google ile giriş kodu.
- **iPhone:** giriş, onboarding, dersler, PDF / fotoğraf / ses kaydı yükleme, okuyucu (molekül, kalemle not, sesli okuma), asistan (tablolar, soru çözdürme, geçmiş, "Ben anlatayım", sesli mod), kartlar, quiz (yazılı sorular dahil), plan, ilerleme, ders özeti, Genel özet, sınav merkezi, ayarlar, profil, Premium ekranı (Apple satın alma kodu hazır), paylaşım linki açma, "Soru örneklerim".
- **Sunucu (canlı, 27 Ekim):** `open-share` (v1, iPhone paylaşım linkini açar), `process-material` (v9, bozuk yazı tipli PDF'i otomatik OCR ile okur), `assistant` (v9, cevapta `[E1]` yazmaz). Deneme süresi bitince `build-exam`, `import-timetable`, `group-sections` ve `process-recording` artık sunucuda da kilitli (403). Web: başka cihazdan çıkış yaptırılınca girişe döner, `[E1]` gizli, küçük PDF'ler "0,1 MB" görünür.
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

## Onayını bekleyen (canlıya henüz yüklenmedi)
- `build-plan` (sadece kod taşındı): push açılınca birlikte yüklenecek.
- Takılı kalan iki ders: ben başlatamam, ders sahibi öğrencinin kendi girişi gerekir. `8479526d…` sahibi siteyi açınca kendiliğinden devam eder (~0,2–0,3 $), `48aef5e6…` sahibi "OCR ile oku" düğmesine basınca yeniden okunur (~0,3–0,5 $). Sahiplerine haber vermek yeterli: `48aef5e6…` (durum `needs_ocr`, yeni sürümle OCR ile okunabilir) ve `8479526d…` (66 sayfa, 25 Ekim'den beri "işleniyor").

## Benim yapacaklarım
**Hesaplar gelmeden:** iPhone arayüz testlerini yeniden yazmak (yarım kaldı, `ios/KavisStudyUITests/FlowTests.swift` kaydedilmemiş duruyor), "Cihazdaki dersler" (çevrimdışı kopya).
**Hesaplar gelince:** Apple ve Google ile giriş, App Store ürünleri ve satın alma denemesi, bildirimleri açmak (anahtar + iki fonksiyon), e-posta kodu, TestFlight.
**Yayın günü:** test anahtarlarını ve örnek veriyi silmek, sitenin Google'da görünmesini açmak, App Store linklerini koymak.
**Sonra:** iPad sürümü, Android.

## Oturumlar (Claude'da)
Her iş ayrı bir oturumda yapıldı. Biten hepsi "Bitti" grubunda. Yeni iş için yeni oturum aç; eskisine dönmen gerekmez.
