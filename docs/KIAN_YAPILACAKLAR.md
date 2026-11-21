# Kian'ın yapacakları (21 Kasım 2026), sırayla

Her maddeyi birlikte adım adım yapacağız. Bitirdiğini [x] yap. "Ben yaparım" = sadece sen yapabilirsin (hesap, banka, kimlik). "Birlikte" = sen tıklarsın, ben yazarım. "Claude" = benim işim, senin onayını bekler.

## A. Şimdi yapılabilecekler (düzeltme oturumlarını beklemeden)

- [ ] **A1. Supabase Dashboard güvenlik ayarları** (5 dk, ben yaparım)
  1. supabase.com/dashboard → Kavis → Authentication.
  2. Sign In / Providers → Email: "Leaked password protection" aç, kaydet.
  3. Rate Limits: e-posta gönderim sınırına bak (saatte kaç e-posta).
  4. URL Configuration: Site URL `https://kavis.study`, Redirect URL'lerde `kavis://login-callback` ve `https://kavis.study/**` olsun.
- [ ] **A2. Canlıda silinen hesapların izi kalıyor mu** (2 dk, birlikte): SQL Editor'de `select count(*) from auth.audit_log_entries;` çalıştır, sonucu bana yaz.
- [ ] **A3. Anthropic Console** (3 dk, ben yaparım): console.anthropic.com → Settings → Limits → aylık harcama limiti koy (öneri 50 $). Anahtarın bitiş tarihi ~22 Ocak 2027: takvime "Anthropic anahtarı yenile" yaz.
- [ ] **A4. Apple: Sign in with Apple anahtarı** (10 dk, ben yaparım, hesap silince token iptali için)
  1. developer.apple.com → Certificates, IDs & Profiles → Keys → "+".
  2. Ad: `Kavis SignIn`, "Sign in with Apple" kutusunu işaretle → Configure → Primary App ID: `study.kavis.app` → Save → Continue → Register.
  3. `.p8` dosyasını indir (bir kez iner), Key ID'yi bana yaz. Team ID `TFTPYS8XHV`.
  4. Ben secret'ları Supabase'e koyarım (onayınla).
- [ ] **A5. Apple Small Business Program başvurusu** (10 dk, ben yaparım): developer.apple.com/app-store/small-business-program → Apply → formu doldur (komisyon %30 yerine %15).
- [ ] **A6. App Store Connect → Business: Paid Applications Agreement, banka ve vergi** (ben yaparım): durum "Active" mi? Değilse eksik formları tamamla (IBAN, ABD vergi formu W-8BEN).
- [ ] **A7. Karar: yasal sayfa bandını gizle** (birlikte): "TASLAK" bandını ve [AVUKAT] notlarını gönderimden önce gizleyelim (öneri: evet). Ben tek satırla yaparım.

## B. Düzeltme oturumları bitince (Claude + senin onayın)

- [ ] **B1. Canlıya alma onayı** (Claude): migration'lar (sırayla), 5-7 Edge Function, Apple secret'ları. Her biri için sana ayrı "evet" soracağım.
- [ ] **B2. Build 4'ü arşivle ve yükle** (birlikte): `git pull`, `xcodegen generate`, Xcode'da Product → Archive → Distribute. Organizer'da sürüm **1.0 (4)** olmalı.
- [ ] **B3. App Store Connect'te Build 4'ü seç** (birlikte): sürüm sayfası → Build → Add Build → 1.0 (4) → Save.
- [ ] **B4. İnceleme notunu güncelle** (birlikte): yeni düzeltmeleri anlatan satırlar (18+ onayı, davet kodu iOS'ta yok, hesap silme).
- [ ] **B5. Demo hesabı hazırla** (birlikte): Ayarlar → Cihazlarım'da eski cihazları çıkar, deneme süresini inceleme sonrasına uzat (şu an 13 Aralık), sandbox izin listesine ihtiyaç olursa hesap ekle.

## C. Gönderimden önce son kontrol (birlikte)

- [ ] **C1. TestFlight'ta gerçek telefonda dene:** Apple girişi, Google girişi, e-posta ile kayıt (18 yaş kutusu), PDF yükleme, asistan, paywall fiyatı, Restore Purchases, hesap silme penceresi. Sandbox satın alma listesi: `docs/TEST2_PURCHASES.md` sonundaki 8 madde.
- [ ] **C2. Avukat ve mali müşavir:** `docs/LEGAL_BRIEF.md` ile randevu al (şahıs şirketi, KVKK, 18 yaş, posta adresi, telif sorusu). Avukat metni onaylayınca ben taslak işaretlerini kaldırırım.
- [ ] **C3. Son kontrol listesi** (Claude + sen): App Store Connect'te her bölüm tamam mı, `docs/APPLE_REVIEW_AUDIT.md` kırmızıları kapalı mı.
- [ ] **C4. Add for Review:** sadece sen "evet" dedikten sonra, birlikte.

## D. Yayın günü (Apple onayından sonra)

- [ ] **D1.** App Store'da "Release this version"a bas (Manually release seçtik).
- [ ] **D2. Claude:** `APNS_ENV=production`, bildirim işini aç, web'de `APP_STORE_URL` bağlantısını koy ve noindex'i kaldır.
- [ ] **D3.** Kendi telefonundan App Store'dan indirip bir gerçek denemeyi yap.

## E. Sonra (acelesi yok)

- [ ] Farsça/Arapça ve iPad bulgularının kalanı, Android planı, Subtitle alanı (App Store Connect'te bulunamadı), gizlilik etiketine "Kullanım verisi" ekleme kararı.
