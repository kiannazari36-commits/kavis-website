# Kavis Study — Avukat ve Muhasebeci Özeti

Hazırlanma tarihi: 20 Kasım 2026. Okuma süresi: yaklaşık 10 dakika.
Bu belge hukuki görüş değildir; yalnızca avukat ve muhasebeciye ürünü ve sorularımızı anlatır.
Taslak metinler: `web/src/i18n/legal.ts` (Kullanım Koşulları + Gizlilik/KVKK; hiçbiri avukat onaylı değil).

## Bölüm 1 — Ürün ve veri akışı

### 1.1 Ürün nedir
- **Yayıncı:** Şahıs, Melisa Ferahani (Kağıthane / İstanbul). Şirket yok. İletişim: kavisstudy@gmail.com.
- **Uygulama:** Kavis Study. Öğrenci, öğretmenin PDF'ini, slayt fotoğrafını veya ders kaydını yükler. Uygulama öğretmenin metnini **değiştirmeden** okuma sayfasına çevirir; ayrıca özet, sesli anlatım, kart, sınav, çalışma planı ve "yapay zekâ asistanı" üretir. Asistan yalnızca öğrencinin yüklediği materyali kullanır.
- **Hedef kitle:** Üniversite öğrencileri (ilk müşteri eczacılık öğrencileri; sağlık/ilaç içerikli dersler çok). Asgari yaş: 18.
- **Platform:** iPhone/iPad uygulaması (App Store, **yalnızca Türkiye**) + web sitesi (kavis-website.vercel.app, şimdilik test; web'de satış yok). Android yok.
- **Para modeli:** Uygulama ücretsiz. Premium = Apple uygulama içi abonelik: aylık 499,99 TL, yıllık 4.399,99 TL (lansman: ilk 3 ay 399,99 TL). Ödemeyi yalnızca Apple alır; biz kart bilgisi görmeyiz. Web'de Premium satılmaz.
- **Ücretsiz deneme:** Kendi denememiz, kart yok: 3 gün, en çok 2 ders, 60 asistan sorusu. Bitince öğrenci eski derslerini okumaya devam eder; yeni yükleme/soru/üretim Premium'dur.
- **Cihaz sınırı:** Hesap başına en çok 2 cihaz (web 1 sayılır). Sunucuda zorunlu tutulur.

### 1.2 Hangi kişisel veri, nerede, kime gidiyor

| Veri | Neden | Nerede / kime gider |
|---|---|---|
| E-posta, ad (isteğe bağlı), giriş yöntemi (e-posta kodu / Apple / Google), dil-tema tercihi | Hesap | Supabase (AB, İrlanda). Giriş kodu e-postası: Resend (e-posta servisi) |
| Cihaz bilgisi: rastgele kurulum kimliği, cihaz adı, tür, uygulama sürümü, oturum zamanı | 2 cihaz sınırı | Supabase |
| Yüklenen PDF, slayt fotoğrafı, ders kaydının **metni** (ses cihazda metne çevrilir, sunucuya yalnız metin gider), notlar, vurgular, ders programı | Hizmetin kendisi | Supabase (özel depolama alanı). İşleme için içerik Anthropic'e (ABD) gider |
| Okuma ilerlemesi, çalışma süresi, sınav/kart sonuçları, asistan soruları ve cevapları, kullanım sayaçları | Hizmet, deneme limiti, aylık maliyet bütçesi | Supabase; asistan soruları Anthropic'e gider |
| "Yardım" sohbeti mesajları | Destek | Anthropic'e gider, **kaydedilmez** |
| Abonelik durumu, Apple işlem kimliği | Premium'u tüm cihazlarda açmak | Supabase; Apple'dan doğrulanır |
| Bildirim cihaz anahtarı (push) | Bildirim | Supabase; Apple (APNs). Henüz kapalı |
| Web: oturum/dil/tema bilgisi tarayıcıda | Web | Vercel (barındırma). Reklam çerezi yok, izleme yok |

- **Apple gizlilik bildirimi** (`PrivacyInfo.xcprivacy`): izleme yok; toplanan veri: e-posta, ad, kullanıcı kimliği, cihaz kimliği, fotoğraf/video, diğer kullanıcı içeriği, satın alma geçmişi — hepsi "uygulama işlevi" amacıyla, kullanıcıya bağlı.
- **Hassas veri:** Sağlık verisi **özellikle istenmiyor**; ama öğrenci tıp/eczacılık ders notlarını, hatta fotoğraf/PDF içinde kendi kişisel bilgisini yükleyebilir. Hasta verisi yüklenmesi yasak olarak yazılmadı (soru 2.7).

### 1.3 Özellikler (hukuki açıdan önemli olanlar)
- **Hesap silme:** Ayarlar'dan talep → e-postadaki tek kullanımlık bağlantıyla onay → **30 gün** bekleme (iptal edilebilir) → gece çalışan işlemle dosyalar ve hesap kalıcı silinir. Aktif abonelik Apple'dan ayrıca iptal edilmeli.
- **Veri dışa aktarma:** Ayarlar'dan talep → e-postayla 7 gün geçerli bağlantı: makine okunur JSON + okunabilir HTML rapor.
- **Paylaşım (yalnız Premium):** Sadece uygulamanın ürettiği özet/kart/sınav paylaşılır; **PDF asla**. Bağlantı web'de "uygulamayı indir" sayfası açar, önizleme yok. Premium'u olmayan alıcı açamaz. Premium alıcıda içerik kendi dersi olarak **kopyalanır**.
- **Aynı PDF'in ortak işlenmesi (28 Ekim'den beri canlı):** Başka bir öğrenci aynı PDF'i (dosya baytlarının SHA-256 özeti aynıysa) yüklediyse ve o ders hazırsa, işlenmiş ders verisi (okuma sayfası, kelime açıklamaları, sorular, kartlar, özet) **yeni öğrenciye kopyalanır**, yapay zekâ tekrar çağrılmaz. **Kopyalanmayanlar:** PDF'in kendisi, notlar, vurgular, ilerleme, cevaplar, sohbetler, çeviriler, paylaşımlar. Kopya, kaynakla bağlı değil (kaynak silinse kopya kalır). Gizlilik metninde 4. maddede kısaca anlatılıyor.
- **Yapay zekâ:** Claude (Anthropic, ABD). PDF işleme: Sonnet; asistan ve yardım: Haiku; "YZ + araştırma" modunda web araması yapabilir. Anthropic API anahtarı bizim hesabımız. Gizlilik taslağı "Anthropic ile veri işleme sözleşmemize göre model eğitimi için kullanılmaz" diyor — **bu sözleşmenin gerçekten imzalanıp imzalanmadığı/geçerli olduğu doğrulanmadı** (soru 2.3).
- **Mesaj/e-posta gönderimi:** Giriş kodu, silme onayı, veri dışa aktarma e-postaları Resend üzerinden; gizlilik taslağında Resend ve Vercel **adı geçmiyor** (soru 2.3).
- **Kullanım limiti/maliyet bütçesi:** Hesap başına aylık yapay zekâ maliyet üst sınırı vardır (kötüye kullanım koruması).
- **Çocuklar:** Taslakta "18 yaşından küçükler için tasarlanmamıştır". Kayıtta yaş sorusu/onayı **yok** (soru 2.5).

## Bölüm 2 — Avukata sorular

### 2.1 KVKK aydınlatma ve açık rıza
1. Gizlilik/KVKK taslağı (`legal.ts`) aydınlatma yükümlülüğünü (KVKK m.10) karşılıyor mu? Eksik başlık var mı?
2. Hangi işlemler sözleşme/meşru menfaat ile yapılabilir, hangileri **açık rıza** ister (ör. yurt dışı aktarım, pazarlama bildirimi, yapay zekâ işleme)?
3. Açık rızayı kayıt sırasında ayrı bir kutu olarak mı almalıyız? Aydınlatma ile açık rıza metni ayrı olmalı mı?
4. Aydınlatma metnini sadece web'de + uygulama içinde göstermek yeterli mi? Kayıt ekranında bağlantı verip "okudum" demek yeterli mi?

### 2.2 VERBİS ve veri sorumlusu
1. Şahıs olarak veri sorumlusuyuz; VERBİS'e kayıt yükümlülüğü var mı (çalışan sayısı/bilanço sınırı, muafiyetler)?
2. Yükümlüyse ne zaman ve hangi bilgilerle kayıt yapılır; "veri sorumlusu irtibat kişisi" kim olur?
3. Kişisel veri saklama ve imha politikası yazmak zorunlu mu? Şablon verir misiniz?
4. Taslakta "AB temsilcisi" yer tutucu var; Türkiye'den yalnızca TR'ye sunduğumuz için gereksiz mi?

### 2.3 Yurt dışına aktarım (Anthropic, Supabase, Apple, Resend, Vercel)
1. Veriler AB'de (Supabase İrlanda) duruyor; ama yapay zekâ işleme için içerik **ABD'ye (Anthropic)** gidiyor. KVKK m.9 (2024 değişikliği) altında hangi mekanizma gerekir: standart sözleşme, taahhütname, açık rıza?
2. Standart sözleşmeyi Kurum'a bildirme yükümlülüğü (5 iş günü) bize de uygulanır mı? Süreç nedir?
3. Anthropic, Supabase, Resend (e-posta), Vercel (web) ile veri işleme sözleşmesi (DPA) gerekir mi? Hepsi için çevrimiçi standart DPA'yı kabul etmek yeterli mi? Taslak metinde Resend ve Vercel'i de anmalı mıyız?
4. Taslakta "Anthropic ile veri işleme sözleşmemize göre içeriğin model eğitimi için kullanılmaz" cümlesi var; bunu yazabilmek için hangi belgeyi elimizde bulundurmalıyız?
5. Apple'a abonelik doğrulama için giden veri (işlem kimliği) ayrıca yurt dışı aktarım sayılır mı?

### 2.4 Kullanım şartları
1. `legal.ts`'deki 10 maddelik taslak (başka bir yapay zekâ çalışma platformunun metninden uyarlandı; dal: `claude/terms-conditions-persian-a7fe4f`) Türk hukukuna uygun mu? Doğrudan kopyalanmış bölüm var mı, telif sorunu doğar mı?
2. "Sorumluluğun sınırı" (madde 9) ve "hesabı askıya alma" (madde 7) tüketici hukuku açısından geçerli mi? Haksız şart olur mu?
3. Şartlar Türkçe + İngilizce + Farsça + Arapça sunuluyor. Çeviriler arasında fark olursa hangisi geçerli olmalı? Farsça/Arapça çeviriler için ayrıca kontrol gerekir mi?
4. Şartlar önceki sürümü değişince kullanıcıdan yeniden onay almalı mıyız?
5. Mesafeli sözleşme ön bilgilendirme formu veya benzeri zorunlu bir metin (Apple dışındaki bölümler için) var mı?

### 2.5 18 yaş
1. Asgari yaş 18. Kayıtta "18 yaşından büyüğüm" onay kutusu gerekli mi, yoksa metinde yazmak yeterli mi?
2. Üniversite öğrencilerinin bir kısmı 18 yaşından küçük olabilir (erken başlayanlar); yanlışlıkla kaydolan reşit olmayan için sorumluluğumuz ne?
3. Apple'ın yaş derecelendirmesi (App Store Connect) ile bizim 18 yaş sınırımız çelişir mi? Hangi derecelendirmeyi seçmeliyiz?

### 2.6 Şahıs yayıncı: adres / iletişim zorunlulukları
1. Gizlilik ve şartlarda tam ev/iş adresimizi (Kağıthane, kapı no dahil) yazıyoruz. Şahıs olarak yasal olarak adres yazmak zorunlu mu, yoksa e-posta yeterli mi? Ev adresini yayınlamamak için seçenek var mı (ör. posta kutusu, ticari adres)?
2. Apple, Türkiye'de "ticaret erbabı" (trader) için adres/telefon/e-posta yayınlamayı zorunlu kılıyor; şahıs olarak "trader" sayılır mıyız?
3. Elektronik ticaret mevzuatı (6563 sayılı kanun) şahıs satıcı için ne gerektirir (ETBİS kaydı, bilgilendirme)? Apple satış yaptığı için bu bizi bağlar mı?

### 2.7 Abonelik, cayma, iade (Apple IAP, Türkiye)
1. Ödemeyi Apple alıyor. Türkiye'de tüketicinin 14 günlük cayma hakkı dijital abonelikte kimin sorumluluğunda: Apple mı, biz mi? Mesafeli Sözleşmeler Yönetmeliği'ndeki dijital içerik istisnası uygulanır mı?
2. İade taleplerini yalnızca Apple'a yönlendirmek yeterli mi ("İade talepleri Apple'ın kurallarına tabidir")? Tüketici hakem heyeti açısından bize düşen bir yükümlülük var mı?
3. Otomatik yenileme, fiyat artışı ve lansman fiyatı (ilk 3 ay 399,99 TL) için Türk mevzuatına göre ek bilgilendirme gerekir mi?
4. Deneme bitince "ücretlendirme yapılmaz" yazıyoruz (kart yok). Bu ifade bağlayıcı bir taahhüt oluşturur mu?
5. Web'de Premium satmıyoruz; ileride Android için web ödemesi eklenirse hangi ek şartlar (ön bilgilendirme, cayma formu) gerekir?

### 2.8 Telif: öğrencinin yüklediği öğretmen PDF'leri
1. Öğrenciler **öğretmenin/okulun ders materyalini** yüklüyor; biz işliyoruz (özet, soru, kart üretiyoruz). FSEK açısından bizim ve öğrencinin sorumluluğu nedir? "Kişisel kullanım" istisnası yeterli mi?
2. Şartlarda "yükleme hakkına sahip olduğunu kabul edersin" cümlesi sorumluluğu öğrenciye geçirmek için yeterli mi? "Notice-and-takedown" (bildirim ve kaldırma) süreci tanımlamalı mıyız?
3. PDF'i hiçbir zaman paylaşmıyoruz; yalnızca ürettiğimiz özet/kart/sınavı paylaşıyoruz. Ancak bu türev içerik de öğretmenin metnini içerebilir (özet, soru örnekleri). Bu paylaşım telif riski doğurur mu?
4. **Aynı PDF'in ortak işlenmesi:** Aynı dosyayı yükleyen ikinci öğrenciye, ilk öğrencinin PDF'inden üretilmiş ders verisi (okuma metni dahil) kopyalanıyor; PDF kendisi kopyalanmıyor. Bu, telif ve "izinsiz çoğaltma" bakımından sorun mu? Kullanıcıya açıkça söylemeli miyiz (şu an gizlilik metninde var)?
5. Öğretmenin kendi materyalini kaldırmak/bildirmek istemesi halinde başvuru yolu ne olmalı (telif başvuru e-postası)?
6. Yapay zekâ ürettiği çalışma materyalinin (özet, soru, kart) sahibi kim? Şartlara hangi lisans/haklar cümlesi eklenmeli?

### 2.9 Yapay zekâ sohbeti ve sağlık/eczacılık içeriği
1. Taslakta "tıbbi tavsiye vermez; hasta bakımı kararlarında kullanılmamalıdır" yazıyor. Bu yeterli mi? Uygulama içinde (asistan ekranında, sınav/özette) ayrıca kalıcı bir uyarı göstermeli miyiz?
2. İlaç dozu, etkileşim gibi sorulara asistan cevap veriyor (yalnızca öğrencinin materyalinden). Yanlış cevap yüzünden zarar iddiası olursa sorumluluğumuz nedir, ne yazmalıyız?
3. Uygulama "tıbbi cihaz/yazılım" veya sağlıkla ilgili reklam kuralları kapsamına girer mi? (Bizce hayır; eğitim aracı.)
4. Öğrenci yüklediği içeriğe hasta verisi koyarsa (ör. staj notu) sorumluluğumuz ne? Şartlara "hasta verisi yüklenmez" maddesi eklemeli miyiz?
5. Yapay zekâ içerik üretimi için "bu içerik yapay zekâ tarafından üretildi" etiketi yasal olarak gerekli mi? Apple veya AB YZ Yasası ile ilgili bir yükümlülük var mı?

### 2.10 Diğer
1. Cihaz sınırı (2 cihaz) ve hesap paylaşımı yasağı tüketici açısından sorun mu?
2. Hesap silmede 30 gün bekleme (iptal edilebilir) KVKK'daki "silme talebine en geç 30 gün" ile uyumlu mu? Yedeklerde kalan veri için süre?
3. Veri ihlali (sızıntı) olursa 72 saat bildirimi için hazırlanmamız gereken bir plan var mı?
4. Marka: "Kavis Study" ismi ve logosu için marka tescili ve benzer marka taraması öneriyor musunuz?
5. Çeviri ve topluluk içeriği şikâyet süreci (kötüye kullanım bildirimi) gerekli mi?

## Bölüm 3 — Muhasebeciye sorular

### 3.1 Vergi mükellefiyeti
1. Apple'dan gelen gelir için şahıs olarak mükellefiyet açmalı mıyım? Hangi tür (basit usul değil, gerçek usul ticari kazanç mı; serbest meslek mi)? Gelir ne zaman "arızi kazanç" sayılmaz?
2. Hangi NACE/faaliyet kodu (mobil uygulama / yazılım yayıncılığı) uygun?
3. Gelir vergisi dilimleri ve geçici vergi dönemleri benim için nasıl işler? Yıllık tahmini gelir küçükse bile bildirim şart mı?
4. Üniversite öğrencisiyim; öğrencilik, SGK/Bağ-Kur veya aile üzerinden sağlık sigortası etkilenir mi? Şahıs şirketi açınca Bağ-Kur zorunlu olur mu?
5. Şahıs şirketi mi, ileride limited şirket mi? Başlangıç için hangisi daha uygun, ne zaman geçmeli?

### 3.2 KDV
1. Apple, Türkiye'de uygulama satışlarında KDV'yi (ve DST'yi) kendisi tahsil edip ödüyor mu? Benim ayrıca KDV beyannamesi vermem gerekir mi?
2. Apple'dan alınan "komisyon sonrası net ödeme" için fatura/belge kesmem gerekir mi? Hangi tutar üzerinden?
3. Yurt dışından alınan hizmetlerde (Anthropic, Supabase, Vercel, Resend) KDV ve "sorumlu sıfatıyla KDV" (KDV 2 beyanı) benim için geçerli mi?
4. Damga vergisi veya stopaj söz konusu mu?

### 3.3 Apple Small Business Program
1. Apple'ın Small Business Program (yıllık 1 milyon USD altı gelirde %15 komisyon) Türkiye'de şahıs olarak başvurusunu kimin yapması gerekir? Vergi kimliği şart mı?
2. Apple'a verilen vergi formları/bilgiler (Türkiye için) ve ödemelerin hangi bankaya (TL/USD) geleceği — banka hesabı şahıs adına mı olmalı?
3. Apple ödemesi döviz olarak geliyorsa, kur farkı ve gelir kaydı nasıl yapılır?

### 3.4 Yurt dışı hizmet giderleri
1. Anthropic (yapay zekâ), Supabase (sunucu), Vercel (web), Resend (e-posta), Apple Developer üyeliği (99 USD/yıl) giderlerini gider olarak yazabilir miyim? Belge olarak ne yeterli (yabancı fatura, kredi kartı ekstresi)?
2. Bu faturalar yabancı para; kayıt kuru hangi kur?
3. Faturalar kişisel kartla ödendiyse, işletme gideri sayılmak için nasıl düzenlemeliyim?

### 3.5 Fatura / e-arşiv
1. Apple tüketiciye fatura keser; ben ayrıca fatura kesmem gerekir mi? Hangi durumda e-arşiv veya e-fatura mükellefi olmak zorunda kalırım?
2. Mali mühür/e-imza ve e-defter yükümlülükleri şahıs için ne zaman başlar?
3. Muhasebe ücreti ve aylık işleyiş (beyanname takvimi, belge paylaşımı) nasıl olur?

## Bölüm 4 — Avukata gitmeden önce hazırla (1 sayfa)

**Belgeler ve çıktılar**
- [ ] `web/src/i18n/legal.ts` içindeki Kullanım Koşulları ve Gizlilik/KVKK metinlerinin Türkçe çıktısı (PDF ya da basılı).
- [ ] Bu belge (`docs/LEGAL_BRIEF.md`).
- [ ] Başka platformdan uyarlanan şartlar taslağı: dal `claude/terms-conditions-persian-a7fe4f`; **uyarlandığı platformun adını ve metnini** avukata söyle (telif sorusu için).
- [ ] Apple gizlilik bildirimi özeti (`PrivacyInfo.xcprivacy` + App Store Connect "App Privacy" cevapları) ve App Store yaş derecelendirmesi.
- [ ] Veri akışı tablosu (Bölüm 1.2) — hangi veri nereye gidiyor.
- [ ] Hesap silme ve veri dışa aktarma ekran görüntüleri; kayıt ve onay ekranı görüntüleri; Premium/paywall ekranı görüntüleri (fiyat, yenileme metni).
- [ ] Apple Developer hesabı bilgileri (kayıtlı ad/adres, "trader" durumu), App Store Connect'te yayınlanan iletişim bilgileri.
- [ ] Anthropic, Supabase, Vercel, Resend, Apple için hesap sahibinin kabul ettiği **DPA / veri işleme şartları** çıktıları (veya bağlantıları) ve Anthropic'in "API verisi model eğitimi için kullanılmaz" ilkesinin resmî sayfası.
- [ ] Destek e-postası (kavisstudy@gmail.com) ve web alan adı/marka bilgisi (kavis.study).
- [ ] Ürün özeti: fiyatlar (aylık 499,99 TL, yıllık 4.399,99 TL, lansman 399,99 TL ilk 3 ay), deneme kuralları, 2 cihaz sınırı.
- [ ] Kimlik, vergi kimlik numarası (varsa), ikametgâh/adres belgesi, Apple Developer ödeme dekontu.
- [ ] Varsa: ticaret odası/esnaf kaydı, banka hesap bilgisi (Apple ödemeleri için).

**Muhasebeciye ek olarak**
- [ ] Apple Developer ve diğer yabancı hizmet (Anthropic, Supabase, Vercel, Resend) faturaları / kart ekstreleri.
- [ ] Tahmini aylık gelir ve maliyet (yapay zekâ bütçesi hesap başına aylık yaklaşık 4 USD üst sınır).
- [ ] Öğrencilik/sigorta durumu belgesi.

**Karar bekleyen konular (önceden düşün)**
- [ ] Ev adresi yayında kalsın mı, yoksa ticari adres/posta kutusu mu?
- [ ] Kayıtta "18 yaşından büyüğüm" kutusu istiyor muyum?
- [ ] Yapay zekâ ve sağlık uyarısını uygulama içinde kalıcı göstermek istiyor muyum?
- [ ] Şahıs mı, şirket mi kuracağım?

**Not:** Lansman öncesi avukattan çıkan değişiklikler `legal.ts` içine işlenecek ve dört dilde (TR/EN/FA/AR) güncellenecek.
