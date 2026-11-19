# Xcode'da Archive ve yükleme (Kavis Study 1.0)

Bu rehber, uygulamayı App Store Connect'e yüklemek için. Kontrol edildi (19 Kas 2026): Release ayarı **canlı** Supabase'i kullanıyor (yerel sunucu Release'te kapalı), sürüm 1.0 / build 1, ikon tam (1024, alfa kanalı yok), `PrivacyInfo.xcprivacy` pakette, Sign in with Apple + Associated Domains + push yetkileri var, birim testleri (60) geçti, "Release" derlemesi iPhone için başarılı.

## Başlamadan önce
- Mac'te Xcode açık olsun, Xcode > Settings > Accounts'ta **Apple Developer hesabın** (Team `TFTPYS8XHV`) görünsün.
- `ios/Config/Secrets.xcconfig` dosyası olmalı (git'te yoktur; senin ana klasöründe var). Yoksa Archive "Supabase URL missing" ile çöker.
- Proje dosyası git'te yok, önce üretilir. Terminalde (ana klasörde):

```bash
cd ios && xcodegen generate
```
Ne yapar: `project.yml` dosyasından `KavisStudy.xcodeproj` üretir.

## Adımlar
1. Finder'da `ios/KavisStudy.xcodeproj` dosyasına çift tıkla. Xcode açılır. Birkaç dakika "Resolving packages" yazabilir, bekle.
2. Üstte ortada **KavisStudy** şeması seçili olsun; yanındaki cihaz kutusundan **Any iOS Device (arm64)** seç (simülatör seçiliyken Archive gri kalır).
3. Solda en üstteki mavi **KavisStudy** proje simgesine tıkla > ortada **TARGETS > KavisStudy** > **Signing & Capabilities** sekmesi.
4. Şunları kontrol et (hepsi işaretli/dolu olmalı):
   - **Automatically manage signing** işaretli.
   - **Team**: senin geliştirici ekibin (TFTPYS8XHV).
   - **Bundle Identifier**: `study.kavis.app`.
   - Altta şu yetenek kutuları görünmeli: **Sign in with Apple**, **Associated Domains** (`applinks:kavis.study`), **Push Notifications**, **In-App Purchase**. In-App Purchase eksikse sol üstte **+ Capability** > "In-App Purchase" ekle.
   - Kırmızı hata varsa (ör. "No profiles for study.kavis.app"): developer.apple.com > Certificates, Identifiers & Profiles > Identifiers > `study.kavis.app` içinde Sign in with Apple, Push Notifications, Associated Domains, In-App Purchase kutularının işaretli olduğunu kontrol et. Sonra Xcode'da "Try Again".
5. Menüden **Product > Archive**. Birkaç dakika derler. Bitince **Organizer** penceresi açılır (Window > Organizer ile de açılır), listede "KavisStudy 1.0 (1)" görünür.
6. Archive'ı seç, sağda **Distribute App** > **App Store Connect** > **Distribute** (yükleme). Sonraki ekranlarda varsayılanları bırak: "Upload", "Automatically manage signing", "Strip Swift symbols" açık. En sonda **Upload**.
7. "Upload Successful" yazınca bitti. App Store Connect'te 10-30 dakika "Processing" görünür; sonra e-posta gelir.
8. appstoreconnect.apple.com > Uygulamalar > Kavis Study > iOS 1.0 sürüm sayfası > **Build** bölümü > **+** ile yüklediğin build'i seç. (**Add for Review** düğmesine henüz basma; önce TODO.md'deki kalan maddeler.)

## Bilmen gerekenler
- **Build numarası**: Apple aynı sürüm için aynı build numarasını iki kez kabul etmez. İlk yükleme "1" ile olur. Hata alıp yeniden yüklersen Xcode'da TARGETS > KavisStudy > **General** > Build alanını 2 yap (ya da bana söyle, `project.yml`'de değiştiririm).
- **Push (`aps-environment`)**: dosyada `development` yazıyor. Archive ile dağıtırken Xcode bunu kendisi `production` yapar; senin bir şey yapman gerekmez. Uygulamada şu an push bildirimi gönderilmiyor.
- **Şifreleme sorusu**: Info.plist'te `ITSAppUsesNonExemptEncryption = false` var, Apple bu soruyu sormaz.
- **Test için**: Archive'dan önce build'in canlı sunucuya bağlandığından emin olmak istersen: Archive sonrası Organizer > Archive sağ tık > Show in Finder > paketin içinde `Info.plist`'te `SupabaseURL` = `https://lnbfcfxxrqohcnkhlcur.supabase.co` olmalı.
- Önce TestFlight'ta kendi telefonunda dene: App Store Connect > TestFlight > build'i iç test grubuna ekle. Apple/Google girişi ve paywall'daki ilk 3 ay fiyatı orada görülür.
