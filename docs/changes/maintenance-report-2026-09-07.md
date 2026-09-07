# Bakım Turu #7 — 2026-09-07

Kalıcı oturuma bağlı Routine, cron ile zamanında ateşlendi; `docs/MAINTENANCE.md`
prosedürü uygulandı.

Tur sayısı: 7 (4'e ve 12'ye bölünmüyor → periyodik görev yok).

## Taranan kaynaklar (§1)

AGP, Compose/Navigation/CameraX, Kotlin/KSP (google/ksp#2964 takibi), Play
Console politikası, Xcode/Swift, on-device AI (Gemini Nano) — 6 WebSearch
sorgusu.

## Bulgular ve değişiklik

| Bulgu | Kaynak | Aksiyon |
|---|---|---|
| **AGP 9.4.0** yayınlandı (Eylül 2026) — temel app ile dynamic feature modülleri arasında flavor dimension 1:1 eşleşme kontrolü (varsayılan uyarı, AGP 10.0'da hataya dönüşecek) | AGP resmi sürüm notları | `android-gradle-build/SKILL.md`: `agp = "9.3.0"` → `"9.4.0"`; "Build Variant ve Flavor" bölümüne dynamic feature parity kontrolü için kısa not eklendi |
| CameraX/Navigation'da yeni davranış değişikliği yok — son güncelleme 26 Ağustos, hâlâ stabil | AndroidX sürüm sayfası | Aksiyon gerekmedi |
| `google/ksp#2964` (Kotlin 2.4.0 kod üretim hatası) hâlâ **çözülmemiş** görünüyor — kapatıldığına dair kanıt yok | github.com/google/ksp/issues/2964 | Kotlin/KSP çifti **4. ardışık tur ertelendi**, aynı gerekçeyle |
| Play Console: Eylül'e özgü yeni duyuru yok; Temmuz duyurusunun (anonim sohbet, SMS/Call Log, unrated app) kapsamı zaten önceki turlarda değerlendirildi | Play Console duyuruları | Aksiyon gerekmedi |
| Swift 6.3 ile Android için resmi Swift SDK yayınlandı (Swift-on-Android, KMP değil) | Apple/Swift.org duyuruları | Hiçbir skill bu konuyu kapsamıyor; niş ve henüz mainstream değil — yeni skill önerisi olarak not edildi, bu turda aksiyon alınmadı (§0: yeni skill oluşturma yok, öneri yeter) |
| Gemini Nano v3 / Android 17 duyuruldu | Google I/O 2026 duyuruları | `on-device-ai/SKILL.md` sürüm numarası pinlemiyor, genel API'yi anlatıyor — aksiyon gerekmedi |

## Doğrulanamayan / bilinçli dokunulmayan

- **Kotlin/KSP sürüm çifti** — dördüncü ardışık tur ertelemesi. `google/ksp#2964`
  hâlâ açık görünüyor; kapatıldığına dair kanıt bulunamadı.

## Yeni gözlem (aksiyon değil, öneri)

- **Swift SDK for Android** (Swift 6.3 ile duyuruldu) — Android ve iOS arasında
  Swift kod paylaşımını hedefliyor, KMP'ye alternatif/tamamlayıcı bir yaklaşım.
  Henüz mainstream değil; ilerleyen bir turda `kmp-shared` veya yeni bir skill
  için değerlendirilebilir. **Aksiyon gerekmiyor, sadece not.**

## Açık, ele alınmayan standing item

- `github.com/android/skills` — hâlâ ayrı bir oturumda içerik bazlı inceleme
  bekliyor (tur #4'ten beri).

## Yönlendirme evali / derin denetim (§4c)

Tur 7, ne 4'e ne 12'ye bölünüyor → bu tur hiçbiri çalıştırılmadı. Sıradaki
yönlendirme evali: tur #8 (bir sonraki tur).

## Doğrulama (§3)

```
./scripts/validate.sh   → 31 skill, 0 hata, 0 uyarı
./scripts/check-links.sh → 70 link, 0 kırık
```

## Sonuç

1 doğrulanmış, kaynak linkli değişiklik (AGP bump + flavor parity notu).
`docs/maintenance-log.md`'ye ayrı commit ile işlenecek.
