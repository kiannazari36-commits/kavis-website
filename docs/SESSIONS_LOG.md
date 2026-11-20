# Kavis Study: oturum kaydı (20 Kasım 2026)

Biten oturumlar silinmeden önce burada kayıt altına alındı. "main'de" = işin kodu `main` dalında. Ayrıntılar için `TODO.md` ve `git log`.

## Biten ve main'de olanlar

| Oturum | Ne yaptı | Tarih |
|---|---|---|
| Bozuk yazı tipli PDF'ler (garbled-pdf) | Sayfa sayfa bozuk metin tespiti, OCR ile okuma, "okunamadı" mesajı (`process-material` v12 canlı) | 9 Kas |
| E-posta: veri gönderimi ve hesap silme onayı | `export-data` ve `delete-account` e-posta linkli; Resend ile e-posta canlı | 9 Kas |
| Web: Ben anlatayım, soru fotoğrafı, sesli ders | "Sesli anlatım" oynatıcısı, teach-back, soru fotoğrafı | 9 Kas |
| iPad kalem araç kutusu + kart çizgi rengi | iPad kalem düzeltmeleri | 9 Kas |
| Bekleyen dalları main'e al + TODO temizliği | Dal birleştirme, TODO/DURUM temizliği | 9 Kas |
| Apple: giriş, ürünler, bildirimler, TestFlight | Apple girişi/ürünleri/bildirim hazırlığı (iOS Apple+Google girişi kodu) | 9 Kas |
| Web testi: kavis.study'de tüm özellikler | Canlı sitede uçtan uca test | 10 Kas |
| Apple'dan gelen mail | Apple e-postasının incelenmesi | 10 Kas |
| Asistan modeli: Sonnet vs Haiku | Haiku 5.5 asistan modeli oldu (soru başı ~16 kat ucuz) | 11 Kas |
| Plan görevi navigasyon sorunu | Plan görevi düzeltmesi | 11 Kas |
| Veri dışa aktarma: okunabilir sayfa + JSON | HTML rapor + `/export` sayfası (canlı) | 11 Kas |
| Courses folder cleanup | iOS profilden "Derslerim klasörü" satırı kaldırıldı | 11 Kas |
| iOS: soru türü seçimi + Sesli anlatım | iPhone/iPad'e soru türleri ve Sesli anlatım (`f67a8cf`) | 12 Kas |
| Web: foto/ses yükleme, HEIC örnekler | Web'de "yakında" buton yoktu; örnek yüklemede HEIC dönüşümü (`36644e5`) | 12 Kas |
| AI maliyet testi (cost-test) | 30 soru gerçek maliyeti: 0,046 $/PDF (önbellek %90), soru başı ~0,0015 $ | 13 Kas |
| AI maliyet testi (fork, App Store) | Abonelikler (aylık 499,99 TL, yıllık 4.399,99 TL), uygulama fiyatı, Türkiye, inceleme bilgisi, demo hesap, $4 bütçe (canlı) | 13 Kas |
| App Store sürüm sayfası metinleri | `docs/APP_STORE.md` yeniden yazıldı | 19 Kas |
| iOS release build hazırlığı | Sürüm 1.0, Release canlı sunucuya bağlı, `docs/RELEASE_BUILD.md` | 19 Kas |
| Güvenlik incelemesi | Rapor (RLS, fonksiyonlar, sırlar); `.gitignore` .env/.p8 eklendi | 19 Kas |
| Güvenlik düzeltmeleri | Bütçe atomik sayaç, 2 ders sınırı, deneme yarışı, web başlıkları, sandbox izin listesi, `busy` mesajı (migration + 14 fonksiyon canlı) | 20 Kas |

Eski oturumlardan kalan (bu liste dışı, `git log` ile bulunur): ink-shared-format, ios-launch-prep, ios-offline-reader-bug, reader-gaps, ios-placement, ios-small-fixes (hepsi `main`'de).

## Bu sohbette (proje-eksiklikleri-listesi) yaptıklarımız, sırayla
1. Eksik listesi çıkarıldı (Kian'ın işleri / benim işlerim / model).
2. Apple: App ID kontrol edildi; APNs anahtarı `YNM3CYZWC2` oluşturuldu; Supabase secret'ları `APNS_KEY_ID`, `APNS_TEAM_ID`, `APNS_PRIVATE_KEY`, `APNS_ENV=sandbox` canlıya yazıldı; `process-material`, `build-plan`, `send-notifications` yayınlandı; telefona deneme bildirimi geldi; `send-notifications` cron işi **kapalı** (yayın günü: `APNS_ENV=production` + cron aç).
3. Supabase Apple sağlayıcısı açıldı (`study.kavis.app`); iPhone'da Apple ve Google girişi çalıştı.
4. Fiyat için AI maliyeti hesaplandı (aylık ~4,5 $ gerçekçi, ~8,9 $ en kötü kullanıcı); KDV ön hesabı; karar Kian'da.
5. Hukuki metinler dolduruldu: yayıncı Melisa Ferahani, adres Merkez Mah., Çendere Cad., Seba Rezidans A4, Kapı 4, 34406 Kağıthane/İstanbul, İstanbul mahkemeleri, en düşük yaş **18**. "Taslak" uyarısı ve `[AVUKAT KONTROL EDECEK]` işaretleri avukat bakana kadar duruyor.
6. Güvenlik düzeltmeleri canlıya alındı (migration `security_hardening`, 14 fonksiyon, secret `SANDBOX_ALLOWED_USER_IDS` = demo hesap `kiannazari36+inceleme@` + Kian'ın test hesabı).

## Henüz main'de OLMAYAN iş (silme, saklı kalsın)
| Oturum / dal | Ne var | Durum |
|---|---|---|
| iPhone/iPad: uygulama içi Yardım ekranı (`claude/practical-cori-35594e`) | iOS yerel Yardım ve destek ekranı (help chat + SSS) | 11 Kas'tan beri birleşmedi; `i18n-ios.json` ve diğer dosyalarda çakışma |
| Terms and conditions Persian translation (`claude/terms-conditions-persian-a7fe4f`) | Yeni kullanım şartları taslağı (11 bölüm, "başka bir AI platformunun şartlarından uyarlanmış") + `daily-planner` `class_tomorrow` bildirimi (TODO'da "canlı" yazıyor) | `legal.ts`, `TODO.md`, `i18n-ios.json` çakışıyor; şartların başka platformdan uyarlanması avukata sorulmalı |

## Bekleyen (Kian'ın işleri)
Sürüm sayfası metinleri + ekran görüntüleri, Xcode Archive, avukat ve mali müşavir, Small Business Program, Paid Applications Agreement kontrolü, Dashboard "leaked password protection", Anthropic aylık limit, kayıtta captcha, 22 Ocak 2027'den önce Anthropic anahtarı yenileme.
