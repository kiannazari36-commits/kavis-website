# Oturum kaydı (27–29 Ekim 2026)

Bu dosya, kapatılan Claude oturumlarının kısa kaydı: ne yaptılar, ne kaldı. Güncel durum için `docs/DURUM.md`, ayrıntı için `TODO.md` ve `git log`.

## Biten işler (oturum oturum)

**iPhone / iPad**
- **Ayarlar ekranı:** çalışma planı, uygulama ve içerik dili, çeviri tarzı, ses, bildirim saati, açık/koyu/sistem tema, çevrimdışı, "Cihazlarım" (çıkış), verilerimi indir, hesabı sil, çıkış yap. Hesabın dili ve teması girişten sonra uygulanıyor; günlük çalışma hatırlatması; silme isteğini geri alma; 3. cihaz ekranı.
- **Profil ve Genel özet:** profil gerçek veriyle; ders özeti ekranına "Genel özet" sekmesi.
- **Yükleme:** slayt fotoğrafı (kamera / galeri) ve ders kaydı. Kayıt cihazda yazıya çevriliyor, sunucuya sadece metin gidiyor.
- **Kalan çalışma ekranları:** ders kaydı sayfası, "Bugünün tekrarı" akışı, asistanda "Soruyu çözdür", soru fotoğrafı ve sohbet geçmişi, yazılı sorular, "Soru örneklerim", gerçek şifre sıfırlama e-postası.
- **Okuyucu ve asistan ekstraları:** molekül görüntüleyici (3 boyutlu), Apple Pencil ile not, sesli okuma, "Ben anlatayım", mikrofonla yazdırma, ilerleme ekranının eksik parçaları, paylaşım linkini uygulamada açma, bildirim adresi kaydı.
- **Küçük işler:** ders klasörü menüsü (ad değiştir, sınav günü, sil), cihazdaki dersler (çevrimdışı kopya), yükleme ekranındaki deneme sınırı ve adil kullanım pencereleri, iPad dikey modda asistan paneli, 14 arayüz testi (yerel sunucuyla), cihazın gerçek adı.
- **iPad:** sol menü şeridi, geniş okuyucu ve asistan paneli, PDF görünümü ve kalemle not, geniş ana sayfa / plan / ilerleme / ayarlar.
- **Ana ekranlar** (önceki günlerden): giriş, onboarding, dersler, okuyucu, asistan, kartlar, quiz, plan, ilerleme, ders özeti, sınav merkezi, Premium (Apple satın alma kodu hazır).

**Web**
- Bugünün tekrarı ve sınav merkezi, yardım sohbeti (ucuz model Haiku, günde 30 soru), kullanım şartları ve gizlilik taslağı (4 dil), molekül görüntüleyici, soru türleri (çoktan seçmeli, boşluk doldurma, yazılı), Google ile giriş kodu, iPhone HEIC fotoğraflarını JPEG'e çevirme, sahip sayfasında harcama panosu, davet kodu alanı.

**Sunucu (canlıda)**
- Gece planlayıcısı, cihazdan anında çıkış, sınav sonucu bildirimi, yardım sohbeti, soru türleri, günlük yapay zekâ puanlama sınırı, `open-share`, bozuk yazı tipli PDF'i otomatik OCR ile okuma.
- **Aynı PDF'in ortak işlenmesi** (migration `20261028120304`, `process-material` v10): aynı dosyayı yükleyen ikinci öğrenci için yapay zekâ çağrılmıyor.
- **Önbellek (prompt caching)** ve ölçümü (migration `20261028133745`): `assistant` v10, `more-questions` v3, `lesson-summary` v3, `generate-quiz` v4, `owner-overview` v2.
- **Davet kodu, 30 gün ücretsiz Premium** (migration `20261028133734`, `redeem-code` v1). Canlıda 10 tek kullanımlık kod hazır; yeni kod için `supabase/scripts/make-codes.sql`.
- Gizlilik metnine "aynı dosyayı yükleyen öğrenciler arasında işlenmiş ders verisi yeniden kullanılabilir" cümlesi eklendi.

## Kalan işler

**Senin yapacakların**
1. Apple Developer hesabı (ayrı yeni Apple ID ile): Apple ile giriş, App Store Premium ürünleri, TestFlight, bildirim anahtarı (APNs).
2. E-posta sağlayıcısı (6 haneli kod gerçek kullanıcılara gitsin). Web'den 100 kişiyi almak için şart.
3. Google Cloud giriş anahtarı (Google ile giriş).
4. Alan adı (ör. kavis.study), Supabase'de Site URL ve yönlendirme adresleri, Vercel'e bağlama.
5. Supabase Pro planı (50 MB üstü PDF).
6. Avukat kontrolü (şartlar, gizlilik/KVKK, Premium ve deneme metinleri); Farsça, Arapça, İngilizce metinleri ana dili olan biri okusun.
7. Gerçek iPhone'da ses kaydını yazıya çevirmeyi dene (simülatörde çalışmıyor).
8. Anthropic anahtarı ~22 Ocak 2027'de bitiyor, yenile.
9. Takılı iki dersin sahiplerine haber ver (`48aef5e6…`, `8479526d…`).

**Benim yapacaklarım**
- *Opus ile (limit sıfırlanınca):* karşılıklı konuşma modu (dinle, cevapla, tekrar dinle), yüklemeden sonra seviye testi.
- *Hesaplar gelince:* Apple ve Google ile giriş, App Store ürünleri ve satın alma denemesi, `StoreTests` hatası (satın alma testi), bildirimleri açmak (anahtar + `process-material` ve `build-plan` yüklemesi), e-posta kodu, TestFlight.
- *Karar bekleyen:* yazı boyutu (Dynamic Type): her ekranı etkiler, büyük iş.
- *Sunucu:* "tebrikler", seri, "yarın dersin var", "deneme bitiyor" bildirimleri henüz sunucuda yazılmıyor; bölüm kataloğu (`course_catalog`) diğer bölümler için boş.
- *Yayın günü:* test anahtarlarını ve örnek veriyi silmek, test hesabının deneme süresini sıfırlamak, sitenin Google'da görünmesini açmak, App Store linklerini koymak, iPhone'da test amaçlı geçici anahtarları kaldırmak.
- *Sonra:* Android uygulaması, Android'de Premium (Google Play veya web ödemesi), iPad'in kalan küçük işleri.

## Önemli kurallar (unutma)
- Canlı veritabanına ve canlı fonksiyonlara yükleme, senin onayın ister: onayı o işi yapan sohbete doğrudan yaz.
- Gizli anahtarlar koda ve git'e girmez; Supabase secrets'te durur.
- Öğrenci başına aylık yapay zekâ bütçesi 3 $.
