# Kavis Study: hâlâ açık sorunlar (24 Kasım 2026)

Nasıl hazırlandı: sadece okundu (`docs/` raporları, `TODO.md`, `git log`, kod). Hiçbir şey değiştirilmedi, canlıya dokunulmadı. App Store Connect'in içine bakamadım; oradaki maddeler "doğrulanamadı" diye işaretli.
Kod tarafında kontrol edilip **düzelmiş** çıkanlar listeye alınmadı (Apple denetimi 1, 3, 4, 7, 9, 10, 17; öğrenci testi 1, 2, 3, 5, 6, 8, 11–16; Test 2'nin çoğu; Yardım ekranı main'de; `auth.audit_log_entries` canlıda boş).
Not: Her şey `origin/main`'de. Model önerisi: Sonnet 5.5 yeter demedikçe Opus gerekmiyor.

Önem etiketleri: **Apple riski** · **Hukuki** · **Kullanıcı hatası** · **Küçük**

---

## A. GÖNDERİMİ ENGELLEYENLER (Add for Review'dan önce)

| # | Sorun | Önem | Kimin işi | Model / zorluk |
|---|---|---|---|---|
| 1 | **Yasal sayfalarda "TASLAK" bandı ve `[AVUKAT KONTROL EDECEK]` notları canlıda görünüyor** (`LEGAL_DRAFT_VISIBLE = true`, `web/src/config.ts`). Gizlilik/Koşullar adresleri App Store'a ve ödeme ekranına bağlı; inceleyici "yarım ürün" görür. Karar: avukat onayını beklemeden gizlemek mi? Gizlenirse metin "onaylı" gibi durur, bunu bilerek seç. | Apple riski + Hukuki | Kian karar verir, Claude tek satır değiştirir | Sonnet · çok kolay |
| 2 | **Build 4 App Store Connect'te seçilmemiş ve inceleme notu eski** (B3, B4 listede açık). Notta olması gerekenler: 18+, davet kodu iOS'ta yok, hesap silme e-postayla onaylanıyor (inceleyici demo e-postasını okuyamaz, bu yüzden açıkla), AI açıklaması, telif cümlesi, arka plan sesi. Hazır İngilizce metin `docs/APPLE_REVIEW_AUDIT.md` sonunda. **Doğrulanamadı:** arka planda build 1.0 (4) TestFlight incelemesinde olduğunu söylediler. | Apple riski | Kian + Claude (metni Claude günceller) | Sonnet · kolay |
| 3 | **Demo hesap hazır değil:** Ayarlar > Cihazlarım'da eski cihazlar duruyor olabilir (inceleyici "2 cihazda açık" ekranına takılır); deneme süresi 13 Aralık'ta bitiyor (inceleme uzarsa Premium kilitli görünür); sandbox izin listesine (`SANDBOX_ALLOWED_USER_IDS`) yeni test hesabı eklenirse 403 olmaz. Yeni hesap açan inceleyici satın alamaz, notta "demo hesabı kullanın" yazmalı. | Apple riski | Kian (cihazları temizler); deneme tarihini uzatmak canlı veritabanına yazar, senin "evet"ini ister | Sonnet · kolay |
| 4 | **Gerçek telefonda son deneme (C1) yapılmadı:** Apple girişi + hesap silerken token iptali (`apple-link`, sadece build 4 ve sonrası), Google girişi, 18+ kutusu, tek seferlik onay ekranı, Restore Purchases, ilk-3-ay fiyatı Apple sayfasında "3 ay" yazıyor mu (Xcode "1 ay" gösterdi), ayrıca arşivdeki `aps-environment = production`. Sandbox listesi `docs/TEST2_PURCHASES.md` sonunda (8 madde). | Apple riski | Kian (telefon), Claude yardım eder | Sonnet · orta |
| 5 | **Anthropic bakiyesi düşük:** 21 Kasım'da 1,33 $ kalmıştı, aylık limit 15 $. Bakiye biterse AI durur; inceleyici asistanda hata görür. Ayrıca anahtar ~22 Ocak 2027'de bitiyor. | Apple riski + Kullanıcı hatası | Kian (console.anthropic.com, bakiye yükle, takvime anahtar notu) | — · 2 dk |
| 6 | **Şifre sıfırlama e-posta şablonu Supabase'e yapıştırılmadı.** Web düzeltmesi yayında, ama iPhone'dan istenen sıfırlama linkleri şablon değişmeden çalışmıyor. Şablon hazır: `docs/EMAIL_RESET_TEMPLATE.md`. | Kullanıcı hatası | Kian (Supabase > Emails > Templates, 5 dk), Claude yönlendirir | — · çok kolay |
| 7 | **E-posta kotası:** Resend ücretsiz plan günde 100 e-posta; kayıt kodu, silme ve dışa aktarma hepsi buradan. Lansmanda 100'ü geçince yeni kullanıcı kod alamaz. | Kullanıcı hatası | Kian (Resend planı) | — · kolay |
| 8 | **Apple gizlilik etiketi kararı:** "Kullanım verisi" (çalışma süresi, sınav sonuçları), destek talebi (cihaz modeli, sürüm) ve push jetonu etikette yok. Etiket gerçekle uyuşmazsa Apple sonradan sorar. Eklemek bedava, eklememek risk. | Apple riski (orta) | Kian karar, Claude etiket cevaplarını yazar | Sonnet · kolay |
| 9 | **Avukat ve mali müşavir randevusu (C2) yok.** `docs/LEGAL_BRIEF.md` hazır. Sorular: KVKK aydınlatma, VERBİS, Anthropic'e (ABD) aktarım, 18 yaş kanıtı, şahıs olarak vergi/KDV, Apple kesintisi, telif (öğrenci hoca PDF'i yüklüyor). Bunlar olmadan canlıya çıkmak hukuken senin sorumluluğunda. | Hukuki | Kian | — · randevu |
| 10 | **`terms-conditions-persian` dalı birleşmedi** (yeni 11 maddelik Koşullar, "başka bir AI platformunun şartlarından uyarlanmış"). Öneri: birleştirme; başka şirketin metninden uyarlama telif riski taşır, avukat kendi metnini yazsın. Dalı silmeden bırak. | Hukuki | Kian karar (öneri: avukata bırak) | — |
| 11 | **Connect sürüm sayfası son kontrol (doğrulanamadı):** ekran görüntüleri, açıklama, anahtar kelimeler, yaş 18+ cevapları (AI sohbeti = evet), App Privacy, destek URL'si. `docs/APP_STORE.md` hâlâ "4+" yazıyor (belge eski). Subtitle alanı Connect'te bulunamamıştı. | Apple riski | Kian (Claude belgeyi düzeltir) | Sonnet · kolay |

---

## B. SONRA YAPILABİLİR (gönderimi engellemez)

### Yayın günü işleri
| # | Sorun | Önem | Kimin işi | Model / zorluk |
|---|---|---|---|---|
| 12 | Yayında: `APNS_ENV=production` + bildirim cron'unu aç, web'e `APP_STORE_URL` bağlantısı, noindex'i kaldır (`robots.txt`, meta, `vercel.json`). Siteyi herkese açmadan önce. | Kullanıcı hatası | Claude (senin "evet"inle canlı) | Sonnet · kolay |
| 13 | Kayıtta captcha yok. Çok hesapla bedava deneme açılabilir (hesap başı ~2,4 $ AI maliyeti, depolama). Sızmış-şifre koruması Pro planda. Aylık $15 limit şimdilik tavan. | Küçük (para) | Kian (Supabase captcha), Claude (iOS/web kodu) | Sonnet · orta |

### Ürün hataları
| # | Sorun | Önem | Kimin işi | Model / zorluk |
|---|---|---|---|---|
| 14 | **Farsça/Arapça PDF'te ters metin:** düzeltme kodlandı (bu PDF'ler OCR'a gidiyor) ama uçtan uca **denenmedi** (paralı test ~0,03 $, senin yesin lazım). Test 2'de "engelleyici" diye işaretlenmişti. | Kullanıcı hatası (fa/ar kullanıcıları) | Claude | Sonnet · orta |
| 15 | PDF'teki **tablo** (metin katmanlı PDF) hâlâ düz paragraf oluyor; sadece OCR tabloları ayrı blok. Gerçek örnek PDF gerek. | Kullanıcı hatası | Claude | Opus önerilir (pdf.js konumları) · zor |
| 16 | **Web sınav merkezi** "20 soru istedin, 5 hazır" uyarısını göstermiyor; iPhone'da var. | Küçük | Claude | Sonnet · kolay |
| 17 | PDF'te vurgu okuma modunda sadece 2 harf sarı, vurguyu kaldırma yolu yok (öğrenci #10). | Küçük | Claude | Sonnet · orta |
| 18 | Çeviri penceresi başlığı "SAYFA 12" (iki sayfa numarası birleşmiş); Test 2'de tekrar görüldü, düzeltme kaydı yok. | Küçük | Claude | Sonnet · kolay |
| 19 | Türkçe karar PDF'inde başlık ("T.C. YARGITAY HUKUK GENEL KURULU") metne girmiyor. | Küçük | Claude | Sonnet · orta |
| 20 | Çalışma süresi sadece okumadan sayılıyor (kart/sınav 0 dk, seri 0). Tasarım kararı gerekir. | Küçük | Kian karar, Claude | Sonnet · kolay |
| 21 | iPad: hover (işaretçi) efekti yok; Güven sayfası dikeyde çok geniş; `PadRail.swift:271` sabit 620 genişlik Split View'da taşabilir. | Küçük | Claude | Sonnet · orta |
| 22 | PDF yüklemeden hemen sonra web "Orijinal PDF" bazen "açılamadı" diyor, yenileyince açılıyor: kendiliğinden tekrar denesin / "Tekrar dene" düğmesi. | Küçük | Claude | Sonnet · kolay |

### Güvenlik / gizlilik (küçük)
| # | Sorun | Önem | Kimin işi | Model / zorluk |
|---|---|---|---|---|
| 23 | Dışa aktarma bağlantısı 7 gün geçerli ve girişsiz açılıyor (24 saate indir). | Küçük | Claude | Sonnet · kolay |
| 24 | Dosya içeriği doğrulanmıyor (sahte ".pdf" kabul ediliyor, boşuna AI/zaman); yol kontrolleri (`..`) eski satırlarda "NOT VALID" kaldı. | Küçük | Claude | Sonnet · orta |
| 25 | Bütçe ve limit yarışları: paralel istekle bütçe birkaç çağrı taşıyor, help-chat limiti 30 yerine 38, davet kodu limiti çoklu hesapla aşılır. | Küçük | Claude | Opus önerilir · orta |
| 26 | Metin: abonelik/ödeme kayıtları hesap silinince hemen siliniyor; gizlilik metni "yasal saklama" diyor. Mali müşavire sor, metni gerçeğe uydur. | Hukuki (küçük) | Kian + Claude | Sonnet · kolay |

### Çeviri ve içerik kontrolü
| # | Sorun | Önem | Kimin işi | Model / zorluk |
|---|---|---|---|---|
| 27 | Farsça/Arapça metinlerin anadili konuşan biriyle kontrolü (hata mesajları, "Erkek sesi", e-posta metinleri, Farsça Koşullar). Hâlâ yapılmadı. | Küçük | Kian (kişi bulur) | — |
| 28 | Test edilmemiş: Arapça arayüz içi, uçak modu, kalem çizimi, VoiceOver, ses kaydı gerçek telefonda, Apple/Google girişi yeni build'de. | Küçük | Kian (telefon) | — |

### Eski, düşük öncelik
| # | Sorun | Önem | Kimin işi | Model / zorluk |
|---|---|---|---|---|
| 29 | 50 MB üstü PDF için Supabase Pro planı gerekir; 5 aylık ürün (`premium.term`) Connect'te yok; Android uygulaması ve ödeme yolu; "Sıralama #3" verisi yok; eski test dosyaları ve takılı iki ders (9 Kas notu). | Küçük | Kian karar | — |

---

## Önerilen sıra (en hızlı yol)
1. Kian'ın 10 dakikalık işleri: 5 (Anthropic bakiye), 6 (e-posta şablonu), 7 (Resend), 3 (cihaz temizliği).
2. Karar: 1 (taslak bandı), 8 (gizlilik etiketi), 10 (Persian Koşullar dalı).
3. Claude: 2 (inceleme notu), 11 (belge), 1 (banner) → sonra Kian 4'ü TestFlight'ta dener.
4. Paralel: 9 (avukat randevusu), 14 (Farsça PDF testi, senin yesinle).
