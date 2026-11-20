# App Store ekran görüntüleri (Kavis Study 1.0)

Hepsi **sahte** bir yerel hesapla (Deniz Yıldız, sahte farmakoloji dersi) alındı; gerçek öğrenci verisi yok, canlı sunucuya dokunulmadı. Dil Türkçe, açık mod. Dosya adındaki sıra = App Store Connect'e yükleme sırası (ilk 3 görsel arama sonuçlarında görünür).

Nereye: App Store Connect > Kavis Study > iOS 1.0 sürüm sayfası > Türkçe > **Ekran Görüntüleri**. Dosyaları sürükle, sırayı koru.

## iPhone — "6,9 inç ekran" yuvası (1320 x 2868)
Klasör: `iphone-6.9/` (Apple küçük iPhone boyutlarını bundan kendisi türetir.)

| Sıra | Dosya | Ekran |
|---|---|---|
| 1 | `01-ana-sayfa.png` | Ana sayfa: bugünün tekrarı, dersler |
| 2 | `02-okuma.png` | Okuma sayfası: vurgular, zor kelimeler |
| 3 | `03-asistan.png` | Asistan: PDF'ten cevap, kaynak sayfalar |
| 4 | `04-ders-ozeti.png` | Ders özeti |
| 5 | `05-test.png` | Hocanın tarzında test sorusu |
| 6 | `06-kartlar.png` | Bilgi kartı (cevap açık) |
| 7 | `07-haftalik-plan.png` | Haftalık plan |
| 8 | `08-ilerleme.png` | İlerleme |

## iPad — "13 inç iPad" yuvası (2064 x 2752)
Klasör: `ipad-13/` (aynı 8 ekran, aynı sıra, dikey.)

| Sıra | Dosya | Ekran |
|---|---|---|
| 1 | `01-ana-sayfa.png` | Ana sayfa + "Bugünün planı" paneli |
| 2 | `02-okuma.png` | Okuma sayfası |
| 3 | `03-asistan.png` | Asistan |
| 4 | `04-ders-ozeti.png` | Ders özeti |
| 5 | `05-test.png` | Test sorusu |
| 6 | `06-kartlar.png` | Bilgi kartı |
| 7 | `07-haftalik-plan.png` | Ders planım |
| 8 | `08-ilerleme.png` | İlerleme |

## Notlar
- Apple en fazla 10 görsel kabul eder; 8 yeterli. Boş görünen bir ekranı çıkarabilirsin (iPad'de alt yarı biraz boş: 04, 05, 06).
- Paywall görseli bilerek yok (`docs/APP_STORE.md`: listede fiyat ve paywall olmayacak).
- Fiyat, "Android", web, gerçek isim yok. Üstteki saat 09:41; iPad'in durum çubuğunda "Fri Nov 20 Kavis Study" yazısı var (iPad simülatörü bunu gizlemiyor).
- Yeniden almak istersen: `supabase start`, sahte hesap `demo1@kavis.test` (şifre `supabase/local-test-users.local.md` içinde, git'te yok), simülatörde `defaults write study.kavis.app kavis.server local`.
