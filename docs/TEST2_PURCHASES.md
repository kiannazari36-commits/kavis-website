# Test 2: Satın alma yolu (YARIM KALDI, kullanım sınırı doldu)

Tarih: 21 Kasım 2026. Dal: `claude/eloquent-lamport-d1bd67` (main: a7e30ec, dal tabanı 152fa0b). Sadece yerel yığın, sahte hesaplar `pay1..3@kavis.test`. Kod değişmedi, canlıya dokunulmadı.

## Nasıl test edildi (önemli ipucu)
- `simctl launch` ile açılan uygulama Xcode StoreKit dosyasını ALMIYOR (paywall "App Store'a ulaşılamıyor" der). Çözüm: uygulamayı bir XCUITest içinden (`XCUIApplication().launch()`) açmak ve aynı testte `SKTestSession` (ios/KavisStudy.storekit) canlı tutmak; komutlar (bitir, iade, onayla, hata aç...) bir dosyadan okunuyor. Araç repoya eklenmedi (geçici kopyada).
- Sunucu tarafı: yerelde sahte imzalı (Xcode ortamı) JWS ve bildirim yükleriyle `apple-purchase` çağrıldı.
- Not: canlıdaki "sandbox izin listesi" 403 yolu yerelde denenemedi (Sandbox ortamı için Apple zinciriyle imzalı veri gerekir). Koddan: sunucu 403 `sandbox` verir, uygulama bunu "Satın alma tamamlanamadı, tekrar dene" olarak gösterir (bkz. bulgu 6).

## Yeni bulgular
| # | Önem | Ne oluyor | Ekran/kanıt | Olası neden |
|---|---|---|---|---|
| 1 | Önemli | **Ödeme güçlüğünde (grace period) Premium hemen kapanıyor.** DID_FAIL_TO_RENEW/GRACE_PERIOD: durum `grace` yazılıyor ama `expires_at` eski tarihte kaldığı için `is_premium()` false. Apple bu sürede erişim vermeyi bekler. | sahte bildirimle: `grace | 2026-11-20 | premium=f` | `apple-purchase/index.ts` (renewalInfo'daki gracePeriodExpiresDate kullanılmıyor), `is_premium` |
| 2 | Önemli | **Sırasız gelen eski bildirim yeni yenilemeyi ezer.** DID_RENEW sonrası geç gelen eski EXPIRED: durum `expired`, Premium gidiyor. Tarih/sıra kontrolü yok. | aynı betik | `save()` signedDate/expiresDate karşılaştırmıyor |
| 3 **(düzeltildi, iOS build 4: sunucu `no_subscription` kodunu verince açık mesaj, o zamana kadar "bulunamadı")** | Önemli | **Satın alım başka hesaba taşınamaz (iyi) ama hesap silinip yeniden açılırsa / farklı giriş yöntemiyle (Apple vs e-posta) açılan ikinci hesapta abonelik geri yüklenemez**; Apple ücret almaya devam eder. Geri yükle bu durumda "Bu hesapta önceki satın alım bulunamadı" der (yanlış mesaj). | 403 `account` testi doğrulandı | appAccountToken = kullanıcı id; `Store.restore()` false'u ayırt etmiyor |
| 4 **(düzeltildi, iOS build 4)** | Küçük | **İade sonrası açık uygulama eski durumda kalıyor.** İade sunucuya gidiyor (`revoked`), ama `listen()` sadece Premium true dönerse ekranı yeniliyor; Ana sayfa yeniden açılana kadar Premium görünür. | t07, DB `revoked` | `Store.swift listen`: onChange koşullu |
| 5 **(düzeltildi, iOS build 4)** | Küçük | **Aylık kartında "Lansmana özel" rozeti, ilk alımdan (veya iadeden) sonra da duruyor** ama fiyat normal ₺499,99 ve ilk-3-ay yazısı yok. | t09-paywall-after-refund.png | `PaywallView.badge` introOffer'a bakmıyor |
| 6 **(düzeltildi, iOS build 4)** | Küçük | **Sunucu reddederse (403 account/sandbox) kullanıcıya hep "tekrar dene" deniyor**; işlem bitirilmeden kalıyor ve her açılışta yeniden denenir. Demo-dışı yeni hesap sandbox'ta satın alırsa nedeni anlaşılmaz. | kod okuma | `StoreAPI.buy` → `.failed` |
| 7 **(düzeltildi, iOS build 4)** | Küçük | **`listen()` sunucuya gönderim başarısız olsa da işlemi `finish()` ediyor** (çevrimdışı/sunucu hatası). Premium, kullanıcı elle "geri yükle" demedikçe gelmeyebilir. | kod okuma | `Store.swift listen` |
| 8 **(düzeltildi, iOS build 4)** | Küçük | **Çevrimdışı soğuk açılışta Premium kullanıcı "yeni deneme (3 gün)" gibi görünür**: `TrialAPI.last` sadece bellekte. Sunucu yine yetkili. (çalıştırılmadı, koddan) | kod okuma | `Trial.swift` |
| 9 **(düzeltildi, iOS build 4)** | Küçük | Satın alma sırasında paywall "Ücretsiz planla devam et" ile kapatılabiliyor; Apple sayfası ana sayfanın üstünde çıkıyor. | t13-asktobuy.png | `busy` sadece satın al düğmesini kilitliyor |
| 10 | Bilgi | Xcode ödeme sayfası ilk-3-ay teklifini "₺399,99 for 1 month" gösteriyor (dosyada 3 dönem). Gerçek TestFlight'ta doğrulanmalı. Yıllık kartta "ayda ≈ / tasarruf" satırı yerelde çıkmıyor (kodda bilinen Xcode fiyat okuma sorunu). | t04 | StoreKit dosyası/Xcode |

## Çalışanlar
- Fiyatlar StoreKit'ten (₺4.399,99 / ₺499,99), kodda sabit yok; ilk-3-ay "İlk 3 ay ₺399,99, sonra ayda ₺499,99" sadece uygun hesapta, iade sonrası yok (t03, t09). Geri yükle/Koşullar/Gizlilik görünür; 4 dilde yenileme/iptal metinleri tam (i18n-ios.json okundu).
- Satın alma: Premium hemen açıldı, `access_status()` = premium, `premium_source: apple`, ortam sandbox (Xcode).
- İptal: sessiz, durum değişmez. Başarısız satın alma: "Satın alma tamamlanamadı, tekrar dene" toast'u. Ask to Buy: bekliyor, sonra onaylanınca `Transaction.updates` ile sunucu Premium oldu, uygulama kendiliğinden yenilendi.
- İade (Xcode): sunucu `revoked`. Sunucu: başka hesabın işlemi, token'sız işlem, girişsiz, bozuk imza reddediliyor (403/401/400). Yenileme, ödeme tekrar denemesi, süre bitimi, iade, geri çağırma bildirimleri durumu doğru yazıyor.

## Test EDİLEMEYENLER (kullanım sınırı yüzünden)
Yarıda kesilen satın alma (araç hazır, işlem 2 `state=2` oluştu; uygulamayı kapatıp açma denenmedi), ikinci hesapta arayüzden geri yükle, aylık↔yıllık geçiş, hızlı çift satın alma, çevrimdışı satın alma, hesap silme sırasında abonelik metni (kodda abonelikten söz eden metin bulunamadı: kontrol edilmeli), farklı mağaza ülkesi/RTL fiyat, ekran görüntüleri fa/ar, süre bitiminde kilitli durum ekranı, aile paylaşımı (dosyada kapalı; açılırsa üye hesabı 403 alır).

## Kian'ın TestFlight'ta gerçek sandbox ile deneyeceği liste
1. Sandbox test hesabıyla yeni (deneme bitmiş) hesapta Aylık al: ilk-3-ay fiyatı Apple sayfasında "3 ay" yazıyor mu? Premium hemen açılıyor mu, webde de?
2. Satın alma sayfasını iptal et: hiçbir şey olmamalı.
3. Aynı Apple hesabıyla ikinci hesapta "Satın alımları geri yükle": hesap bulunamadı mesajı çıkar (bulgu 3).
4. Ayarlar > Apple hesabı > Abonelikler'den iptal et, süre bitince uygulamada kilit mesajı ve eski derslerin okunabildiği.
5. Demo olmayan yeni hesapla sandbox'ta satın al: ne mesaj çıkıyor (bulgu 6)?
6. Aylıktan yıllığa geç.
7. Hesabı sil: abonelik hakkında bilgi veriliyor mu?
8. Uçak modunda uygulamayı aç (Premium hesap).

Ekran görüntüleri: `docs/test-report2/` (t01-t14).
