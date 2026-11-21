# Kavis Study: öğrenci gibi uçtan uca test raporu (21 Kasım 2026)

Kim yaptı: Claude (öğrenci rolünde). Ne zaman: 21 Kasım 2026. Dal: `claude/recursing-chatterjee-fa7e73`. Kod değiştirilmedi, sadece bu rapor ve ekran görüntüleri eklendi.

## Nasıl test edildi
- **Sadece yerel yığın** (`supabase start`, Mailpit, yerel web 5174). Canlı proje, Kian'ın hesabı ve demo hesap kullanılmadı.
- Sahte hesap `student1@kavis.test` (kayıt ekranından açıldı, adı "Deniz Test"), ikinci sahte hesap `student2@kavis.test` (paylaşım alıcısı). Sahte PDF'ler kendi ürettiğim özgün metinlerdir (beta-blokerler 6 sayfa, antibiyotik tablosu 2 sayfa, taranmış 2 sayfa, 101 sayfalık dosya, ".pdf" adlı bozuk metin dosyası, slayt fotoğrafı).
- iPhone: simülatör `iPhone 18 Pro` (iOS 27.1), uygulama `-kavis.server local` ile (değer `kavis.server=local` kalıcı yazıldı). Web: Chrome benzeri panel, 5174.
- Gerçek AI harcaması: **0,314 $** (üst sınır 2 $; 1,8 $'a yaklaşılmadı). Başlangıç toplamı 0,4885 $, bitiş 0,8026 $ (yerel `usage_monthly` toplamı).
- Ekran görüntüleri: `docs/test-report/` (önemli 17 tanesi; hepsi dosya adıyla aşağıda anılıyor).

## Özet sayılar
| Önem | Adet |
|---|---|
| Engelleyici (blocker) | 0 |
| Önemli (important) | 6 |
| Küçük (minor) | 12 |

Genel görüş: temel akışlar (kayıt, yükleme, okuyucu, kartlar, sınav, asistan, plan, bildirimler, cihaz sınırı, deneme sınırı, paylaşım) çalışıyor. Yayını durduracak bir hata görmedim. Ama aşağıdaki 6 önemli hatanın ilk dördü öğrencinin hemen fark edeceği türden.

## Hata tablosu (önemden küçüğe)

| # | Önem | Ne oluyor (adımlar → beklenen / gerçek) | Ekran görüntüsü | Olası neden (dosya) |
|---|---|---|---|---|
| 1 | Önemli | **Asistan Türkçe soruya İngilizce cevap veriyor.** Asistan → Farmakoloji → "Hoca derste neyi vurguladı?" hızlı düğmesi. Beklenen: Türkçe cevap. Gerçek: "I could not find anything about what the teacher emphasized…". API ile de tekrarlandı: "Bu sayfayı özetle" (sayfa seçiliyken) 5 denemenin 2'sinde İngilizce. Normal sorularda Türkçe geldi. | `asistan-ingilizce-cevap.jpg` | `supabase/functions/assistant/index.ts` satır ~104: "soru dilinde yaz, belirsizse `lang`" kuralı. Sayfa/eşleşme yok durumlarındaki İngilizce istem metni modeli İngilizceye çekiyor. `lang`'ı kesin zorunlu yapmak gerek. |
| 2 | Önemli | **Deneme bitince asistanda "gönder" sessiz kalıyor.** Deneme süresi bitmiş hesapta Asistan → ders seç → soru yaz → gönder: hiçbir şey olmuyor, mesaj yok. "Premium'a özel" penceresi ancak geri dönüp ana sayfaya gelince çıkıyor. Ayrıca pencere metni "yeni PDF yüklemek için" diyor (soru için `trialQFull` metni var). | `deneme-bitti-mesaj-ana-sayfada.jpg` | `ios/KavisStudy/App/TrialModel.swift` (`perform` sadece `lockedKey` yazıyor); pencereyi gösteren görünüm ana sayfada, asistan ekranında yok. `AssistantHomeView.ask()` / `AssistantChatView` (satır ~518-553). |
| 3 | Önemli | **Ders seçmeden yüklenen PDF/foto hiçbir yerde görünmüyor.** PDF yükle → ders seçmeden "Dersi hazırla" → hazır oluyor (bildirim geliyor) ama "Derslerim", ders klasörü ve web "Derslerim" sayfasında yok (3 PDF var, 2 görünüyor). Ayarlar'da "Cihazdaki dersler **3 / 2 PDF**" yazıyor. Aynı şey fotoğraf dersinde de oldu. | `derslerim-eksik-pdf.jpg` | Yükleme ekranında ders seçimi isteğe bağlı (`UploadView.swift` satır ~396 "none is allowed"); listeler `course_id` olmayan dersi göstermiyor. Ya ders zorunlu yapılmalı ya da "Dersi olmayanlar" listesi olmalı. |
| 4 | Önemli | **PDF'teki tablo düz metne dönüşüyor.** Antibiyotik tablosu: okuyucuda tablonun satırları tek paragrafta, altındaki normal metinle birleşik ("…Aminoglikozidler Gentamisin 30S ribozom… Nefrotoksisite Amoksisilin gram pozitif…"). Metin eksiksiz ama tablo okunmaz. Metin değişmiyor kuralı korunmuş ama okunabilirlik kötü. | `tablo-duz-metin.jpg` | `supabase/functions/process-material/index.ts` (`SYSTEM` istemi / sayfa metni çıkarma): tablo için bloğu yok. Asistan tabloyu doğru yeniden kurabiliyor (cevap testi 8). |
| 5 | Önemli | **Bozuk ya da PDF olmayan dosya seçilince hiçbir şey olmuyor.** `fake_pdf_but_txt.pdf` seçildi: hata yok, liste boş, başlık eski dosyanınki ("fake big") kalıyor; "Dersi hazırla" sadece "Önce PDF seç" diyor. Beklenen: "Bu dosya okunamadı". (`notpdf.txt` seçicide soluk, sorun yok.) | `bozuk-pdf-sessiz.jpg` | `UploadView.swift` dosya alma kodu (satır ~100 `fileImporter`, `PDFDocument(data:)` nil olunca sessiz dönüyor). |
| 6 | Önemli | **"Yapay zekâ + araştırma" bazen araştırma yapmıyor.** Ders seçiliyken "Metformin nasıl çalışır?" (ders dışı) → "bu derste yok, söyleyemem", web araması yok, kaynak linki yok. Ders seçili olmadan, açıkça araştırma isteyen soruda (beta-bloker + glokom) çalıştı: 3 kaynak linki, "PDF DIŞI BİLGİ" etiketi, ~0,05 $. | (API testi) | `assistant/index.ts` mod `ai` istemi: ders seçiliyken model sadece dersle sınırlı kalıyor. |
| 7 | Küçük | **Sınav merkezi 20 soru + 3 tür seçildi, 5 çoktan seçmeli soruyla açıldı**, eksik için bilgi yok; yeni soru da üretilmedi. | — | `supabase/functions/build-exam/index.ts`: "AI yok, hazır soruları toplar". Uygulama kullanıcıya "5 soru hazır" diyor ama seçimi sessizce küçültüyor. |
| 8 | Küçük | **Sınav sonuç ekranı çok sade**: "%20 · 1/5 · 4 yanlışın var" ve sadece "Ana sayfa". Yanlışları gör / Hatalarım düğmesi yok. "Ana sayfa" aslında Sınav merkezine dönüyor. | `sinav-sonuc-ekrani.jpg` | iOS sınav sonucu görünümü. |
| 9 | Küçük | **Taranmış PDF metni satır sonlarında paragrafa bölünüyor** ("…Beta-2" / "reseptörleri ise…"). Metin doğru, paragraf yanlış. | — | `process-material/ocr.ts`: OCR çıktısını satır satır paragraf yapıyor. |
| 10 | Küçük | **PDF'te seçilen vurgu okuma modunda sadece 2 harf sarı** ("ol"). Cümle vurgulandı bildirimi geldi ama okuma modunda cümle işaretli değil. Vurguyu kaldırmak için okuma modunda dokununca menü çıkmadı (kaldırma yolu bulunamadı). | `vurgu-okuma-modunda-yarim.jpg` | iOS okuyucu vurgu eşleme (`ReaderView.swift` satır ~70 vurgu → paragraf eşlemesi). |
| 11 | Küçük | Çeviri penceresi başlığında **"SAYFA 12"** (1. sayfa, 2. paragraf birleşmiş gibi). | `ceviri-sayfa-12.jpg` | iOS çeviri sayfası başlığı (`ReaderView` çeviri paneli). |
| 12 | Küçük | **Ayarlar'da ad yerine "Hesabım"** yazıyor (ana sayfa "Merhaba, Deniz" diyor; web Ayarlar "Deniz Test" gösteriyor). | `ayarlar-acik.jpg` | `SettingsView.swift` profil kartı. |
| 13 | Küçük | İşleme hata verince ("Ders hazırlanamadı") **"Tam metin" satırında dönen yükleniyor simgesi** kalıyor. | `isleme-hata-tekrar-dene.jpg` | `UploadView.swift` hata durumu satır görünümü. |
| 14 | Küçük | Premium hesapta bile taranmış PDF ekranında **"Bu deneme ücretsiz ders hakkından düşmez"** yazıyor. | `taranmis-pdf-ocr-onerisi.jpg` | `UploadView.swift` OCR önerisi altyazısı (Premium'a göre gizlenmeli). |
| 15 | Küçük | **Bildirim izni, kayıttan hemen sonra ilk onboarding ekranında** soruluyor (neden istediği anlatılmadan). Apple bağlam içinde sormayı tercih eder. | — | `OnboardingView.swift`. |
| 16 | Küçük | Onboarding'de **"2 / 6" iki kez** görünüyor (rozet + metin). | — | `OnboardingView.swift`. |
| 17 | Küçük | **Çalışma süresi sadece okumadan sayılıyor**: 3,6 dk okuma + kart + sınav sonrası ders kartında "0 dk", seri 0 gün (seri için günde en az 5 dk okuma gerekiyor). Kart ve sınav süresi sayılmıyor. | — | `study_sessions` yalnızca `read` yazıyor; `study_streak()` ≥ 5 dk istiyor. Tasarım kararı olabilir, öğrenciyi şaşırtır. |
| 18 | Küçük | "Dosya seç"te seçici **4-5 sn geç açılıyor**; ilk dokunuş boşa gitmiş gibi görünüyor (kullanıcı tekrar basabilir). | — | iOS `fileImporter` (simülatörde olabilir). |

**Test ortamında bulduğum, ürün hatası olmayan ama Kian'ın bilmesi gerekenler**
- Yerel Edge runtime başka bir çalışma klasöründen (`google-login-invalid-client-a00d0e`) başlatılmıştı; orada `supabase/functions/.env` (Anthropic anahtarı) yok, bu yüzden ilk PDF işleme `Cannot read properties of undefined (reading 'trim')` ile düştü. Ben ana klasörden `supabase functions serve` başlatıp fonksiyonları yeniden sundum (hâlâ çalışıyor). Başka bir oturum yığını yeniden başlatırsa aynı şey olabilir.
- iOS `xcodeproj` git'te yok; eski bir çalışma klasöründeki proje yeni dosyaları (`AudioLessonModel`, `RedeemCodeView`, `PromoAPI`) içermiyordu. `xcodegen generate` gerekti.
- Ana klasörde `web/node_modules` içinde `pdfjs-dist` yoktu; `npm --prefix web install` yaptım (git dışı).
- Yerelde kayıt "kod" değil **e-posta + şifre** ile açılıyor (e-posta onayı kapalı), bu yüzden Mailpit'e kayıt maili düşmedi. Canlıda onay bağlantısı olup olmadığını ayrıca bakmak gerek.

## İyi çalışanlar
- Kayıt (ad, e-posta, şifre güç göstergesi, koşullar kutusu), 6 adımlı onboarding, ders ekleme, dil seçimi tr/en/fa/ar; Arapça ve Farsça sağdan sola düzgün (sekme çubuğu, rozetler, noktalar ters). Karanlık mod tüm gördüğüm ekranlarda okunur. (`arapca-rtl.jpg`, `farsca-rtl.jpg`, `karanlik-mod.jpg`)
- Deneme kartı (3 gün, PDF 0/2, soru 0/60, "100 sayfa"), 3. PDF'te "Premium'a özel" penceresi; sunucuda da 3. ders `trial lesson limit reached` ile reddediliyor.
- PDF yükleme: durum adımları (Tam metin → Terim → Çeviri → Sınav soruları → Kartlar), hata ve "Tekrar dene". Eşzamanlı işleme sınırı SQL'de çalışıyor (3. iş `busy`). Taranmış PDF için "Metin tanıma ile dene" önerisi; OCR çıktısı **birebir** doğru. Fotoğraftan ders (OCR) birebir doğru. 100 sayfa üstü PDF'te "bölümlere ayır / sayfa aralığı seç" (iyi çözüm, `100-sayfa-ustu.jpg`).
- Öğretmenin metni korunuyor: 6 sayfalık PDF'te 38 cümlenin 38'i aynen var (1 fark: satır sonu tire boşluğu).
- Okuyucu: zor kelime kartı, "Kartlara ekle" (toast + kart gerçekten eklendi), cümle çevirisi (4 dilde, "doğal anlatım" / "düz çeviri"), orijinal PDF görünümü, PDF'te metin seçip Çevir / Kopyala / Vurgula / Asistana sor menüsü ve sarı vurgu kaydı.
- Kartlar: Bildim (+4 gün), Bilmedim (+1 dk) sunucuya doğru yazılıyor.
- Sınav: çoktan seçmeli akış, "Cevabından ne kadar eminsin" adımı, açıklama + "Sayfa 2'ye bak", emin olunan yanlışta "Dikkat" kutusu ve karta ekleme, sonuç bildirimi.
- Asistan dürüstlüğü (13 soru): PDF içi sorular doğru ve doğru sayfa kaynağıyla (s. 1, 2, 3, 5, 6); PDF dışı "Metformin" → "bu derste yok"; "karvedilol yan etkileri" → "ayrıntılı yazmıyor, sadece s. 6'da geçiyor"; "şiir yaz" talimatı reddedildi; tablo isteği doğru markdown tabloyla; ders dışı slayt fotoğrafı için "bu derste yok" dedi. Uygulamada kaynak çipleri doğru ("BETA-BLOKERLER 1 · SAYFA 1 / 3").
- Sınav özeti ve sınav gecesi özeti (sahte 4 soruyla): PDF'te olmayan "metformin" sorusu "PDF'te tam anlatılmıyor, ilgili kısım s. 5" diye dürüst işaretlendi; açıklamalar sayfa atıflı ve PDF'e sadık. Ders kaydı (sahte transkript): "sınavda soruyorum" vurgusu bulundu, piknik cümlesi eşlenmedi.
- Günlük planlayıcı: plan (5 madde), "Bugünün tekrarı" kartı, bildirim ve "Yarın 1 dersin var" yazıldı; ikinci çalıştırma tekrar yazmadı. Okul ders programı ekleme, çok uzun ders adı düzgün satıra sarılıyor.
- Bildirim satırları DB'de ve uygulama listesinde aynı: `lesson_ready` (3 + foto), `exam_result`, `review_day`, `class_tomorrow` (20:00 İstanbul).
- Cihaz sınırı: 3. cihaz ekranı (iPhone ve web), "Oturumu kapat" çalışıyor; sunucu 3. cihazı reddedip listeyi veriyor. Ayarlar → Cihazlarım.
- Paylaşım: Premium oluşturuyor; Premium olmayan alıcıya sadece "Premium değil" cevabı; Premium değilken oluşturma `premium` ile reddediliyor; web `/s/…` sayfası "Bunu açmak için uygulamayı indir", önizleme yok. Sahibi kendi linkini açınca "kendi dersin" cevabı.
- Deneme bitince sunucu kilidi tutarlı: asistan, sınav oluşturma, özet üretme, çeviri, paylaşım `locked/premium` (403); eski ders özeti ve okuma satırları okunabiliyor. Ana sayfada "Deneme bitti" kartı doğru metinle.
- Çevrimdışı mod: açınca "İnternet yok · çevrimdışı mod" bandı, indirilmiş ders okunuyor.
- Web: açılış, giriş, 3. cihaz, ana sayfa, derslerim, plan, ilerleme, kartlar, bildirimler, ders programı, sınav merkezi, ayarlar, yükle, örnekler, yardım, kullanım koşulları, Premium (buy düğmesi yok, "Fiyat App Store'da", iPhone'dan al yazısı), paylaşım sayfası: hepsi açıldı, konsolda hata yok.
- Ayarlar → hesabı sil: açık metin, onay e-postası uyarısı, 30 gün geri alma; e-posta servisi yokken kullanıcıya düzgün hata ("Şu an olmadı…").

## Test edilemeyenler (neden)
- **Gerçek push (APNs)**: simülatörde yok, yerelde de anahtar yok (`send-notifications` → `no apns key`). Sadece satırların yazıldığı doğrulandı.
- **Satın alma ve Satın alımları geri yükle**: derlenmiş uygulama Xcode StoreKit yapılandırması olmadan açıldı; ücret düğmesi pasif, geri yükle Apple girişi istedi (iptal ettim, giriş yapmadım). Fiyatlar, yerel StoreKit dosyası, lansman fiyatı Xcode'dan çalıştırarak denenmeli.
- **E-posta işleri** (veri dışa aktarma, hesap silme bağlantısı, silme iptali): yerelde `RESEND_API_KEY` yok; uygulama hata gösteriyor, ama e-posta/bağlantı akışı denenemedi.
- **Google/Apple ile giriş, mikrofon (sesli soru, ders kaydı, Sürekli dinle), kamera, Sesli anlatım (TTS), "Ben anlatayım"**: simülatörde/izinde mümkün değil ya da ses gerektiriyor. Ders kaydı yolu sadece sunucuda (sahte transkriptle) denendi.
- **Molekül görüntüleyici, kalem (PencilKit/parmak çizimi), notlar, bölüm kontrol soruları, kelime sesli okuma**: sahte PDF'lerde molekül yoktu; çizim ve not akışları elle denenmedi.
- **Boşluk doldurma / yazılı / doğru-yanlış soru türleri ve gerçek AI notlama**: sınav merkezi sadece 5 çoktan seçmeli soru verdi; ek tür üretmek için ayrı bir paralı akış gerekecekti.
- **"Hatalarım" ekranı, sınav tarihleri, kendi planım, "Soru örneği" ekranı (iOS), davet kodu**, Farsça/Arapça içeride tüm ekranlar: yalnızca bir kısmına bakıldı.
- **Gerçek uçak modu / ağ yok**: yerel yığını kapatmak başka oturumları bozardı; yerine uygulamanın "Çevrimdışı mod" anahtarı denendi (asistanda çevrimdışı uyarısı görmedim, doğrulanmadı).
- **iPad düzeni** ve gerçek cihaz bu turda yoktu.
- **Web'de** okuyucu, asistan, sınav çözme sayfalarının içi (sadece sayfaların açıldığı ve hata vermediği görüldü).
- Yasal metinler: web `/terms` hâlâ "TASLAK – avukat kontrolü gerekir" başlığıyla yayınlanıyor (bilinen iş, yayından önce).
