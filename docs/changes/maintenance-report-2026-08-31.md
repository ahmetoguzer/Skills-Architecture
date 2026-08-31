# Bakım Turu #6 — 2026-08-31

Kalıcı oturuma bağlı Routine, cron ile zamanında ateşlendi; `docs/MAINTENANCE.md`
prosedürü uygulandı.

Tur sayısı: 6 (4'e ve 12'ye bölünmüyor → periyodik görev yok).

## Taranan kaynaklar (§1)

AGP, Compose/Navigation/CameraX/Credential Manager, Kotlin/KSP, Play Console
politikası, Xcode/Swift/App Store Connect, Kotlin Multiplatform — 6 WebSearch
sorgusu, artı Kotlin sürüm/KSP uyumluluğu için 2 ek doğrulama sorgusu.

## Bulgular ve değişiklik

| Bulgu | Kaynak | Aksiyon |
|---|---|---|
| **AGP 9.3.0** yayınlandı (Temmuz 2026, sayfa 2026-08-28'de güncellendi) — basitleştirilmiş R8 optimizasyon DSL'i, resmi API 37 desteği | AGP resmi sürüm notları | `android-gradle-build/SKILL.md`: `agp = "9.2.0"` → `"9.3.0"`. Kırıcı değişiklik yok, iki tur önce set edilen compileSdk 37 ile tutarlı |
| **Kotlin 2.4.0 stable** (3 Haziran 2026'dan beri) ama **`google/ksp#2964`**: KSP 2.3.9, Kotlin 2.4.0 ile kod üretimini bozuyor (açık hata kaydı) | kotlinlang.org, github.com/google/ksp/issues/2964 | Kotlin/KSP çifti **3. ardışık tur bilinçli ertelendi** — bu kez somut bir açık hata kaydı gerekçe; skill dosyasına satır içi not eklendi (aşağıya bakın) |
| Compose 1.12 / BOM 2026.08.00 — değişiklik yok, geçen turdan beri sabit | Compose resmi blog | Aksiyon gerekmedi |
| Play Console: 26 Ağustos anonim-sohbet + geofencing kuralları zaten yürürlüğe girdi; Vietnam yaş derecelendirmesi, içerik derecelendirme netleştirmesi | Play Console duyuruları | Grep: hiçbir skill'de ilgili referans yok — aksiyon gerekmedi |
| Xcode 26.6 RC / Swift 6.3, App Store Connect Vietnam yaş sistemi | Apple duyuruları | `ios-swift-architect` sürüm pinlemiyor — aksiyon gerekmedi |
| KMP: Room/DataStore/ViewModel/Paging commonMain'den kullanılabilir, yeni proje yapısı güncellemesi | JetBrains blog | `kmp-shared` skill'i zaten bu desenleri anlatıyor, içerik güncel — aksiyon gerekmedi |

## Doğrulanamayan / bilinçli dokunulmayan

- **Kotlin/KSP sürüm çifti** — üçüncü ardışık tur ertelemesi, ama bu kez
  gerekçe daha güçlü: Kotlin 2.4.0 üç aydır stable, fakat KSP tarafında
  bilinen bir üretim hatası var. `android-gradle-build/SKILL.md`'ye artık
  bu gerekçeyi açıklayan satır içi bir not eklendi — sessiz bir eskime
  olmaktan çıkarıldı. KSP düzeltmesi yayınlanınca ele alınacak.

## Açık, ele alınmayan standing item

- `github.com/android/skills` — hâlâ ayrı bir oturumda içerik bazlı inceleme
  bekliyor (tur #4'ten beri).

## Yönlendirme evali / derin denetim (§4c)

Tur 6, ne 4'e ne 12'ye bölünüyor → bu tur hiçbiri çalıştırılmadı. Sıradaki
yönlendirme evali: tur #8. Sıradaki derin denetim: tur #12.

## Doğrulama (§3)

```
./scripts/validate.sh   → 31 skill, 0 hata, 0 uyarı
./scripts/check-links.sh → 70 link, 0 kırık
```

## Sonuç

1 doğrulanmış, kaynak linkli değişiklik (AGP bump) + 1 gerekçelendirilmiş
erteleme notu. `docs/maintenance-log.md`'ye ayrı commit ile işlenecek.
