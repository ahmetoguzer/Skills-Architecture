# Bakım Turu #9 — 2026-09-21

Kalıcı oturuma bağlı Routine, cron ile zamanında ateşlendi; `docs/MAINTENANCE.md`
prosedürü uygulandı.

Tur sayısı: 9 (4'e ve 12'ye bölünmüyor → periyodik görev yok).

## Taranan kaynaklar (§1)

AGP, Compose/Navigation/CameraX/Compose Multiplatform, Kotlin 2.4.x/KSP uyumu
(2 WebFetch doğrulaması dahil), Play Console politikası, Xcode 27/Swift 6.4,
genel Android geliştirici haberleri — 6 WebSearch sorgusu + 2 WebFetch.

## Bulgular ve değişiklikler

| Bulgu | Kaynak | Aksiyon |
|---|---|---|
| **Kotlin 2.4.20 stable** (tooling release, 7 Eylül 2026) | kotlinlang.org/docs/releases.html (WebFetch ile doğrulandı) | `android-gradle-build/SKILL.md`: `kotlin = "2.4.0"` → `"2.4.20"` |
| 2.4.20'nin breaking change'leri Kotlin/Native, Kotlin/JS, Kotlin/Wasm'a özgü — tek JVM-ilgili değişiklik: companion object'ler artık superclass→subclass sırayla başlatılıyor (JVM davranışıyla eşleşti) | JetBrains blog, kotlinlang.org/docs/whatsnew2420.html | Section 6 "Sık Karşılaşılan Hatalar" tablosuna satır eklendi |
| **Kendi hatamız:** aynı tabloda "KSP versiyonunun ilk parçası Kotlin sürümüyle aynı olmalı" satırı, iki tur önceki versiyonlama şeması değişikliğinden (KSP artık bağımsız semver) beri **yanlış/stale** kalmış | İç tutarlılık taraması | Satır düzeltildi — artık `github.com/google/ksp/releases`'ten hedef Kotlin'i destekleyen güncel sürümü seçmeyi öneriyor |
| Ön uyarı doğrulaması: "KSP still has no 2.4 line" iddiası bir üçüncü parti kaynaktan geldi, WebFetch ile google/ksp/releases sayfası doğrudan kontrol edildi — **yanlış çıktı**, KSP 2.3.10+ zaten Kotlin 2.4.0 modül adı düzeltmesini içeriyor | github.com/google/ksp/releases (WebFetch) | İki tur önceki Kotlin/KSP bump'ının doğru olduğu teyit edildi, geri alma gerekmedi |
| AGP hâlâ 9.4.0 (en güncel), Compose hâlâ 1.12/BOM 2026.08.00 — davranış değişikliği yok | AGP/AndroidX sürüm sayfaları | Aksiyon gerekmedi |
| Compose Multiplatform 1.12.0 yayınlandı (1 Eylül) | Android geliştirici haberleri | `kmp-shared/SKILL.md` sürüm pinlemiyor — aksiyon gerekmedi |
| Xcode 27 / Swift 6.4 yayınlandı (14 Eylül) | Apple duyuruları | `ios-swift-architect` sürüm pinlemiyor — aksiyon gerekmedi |
| Play Store geliştirici doğrulama — yeni gelişme yok, hâlâ aynı 4 ülke | Play Console duyuruları | Aksiyon gerekmedi, tur #8'de zaten not edildi |

## Açık, ele alınmayan standing item

- `github.com/android/skills` — hâlâ ayrı bir oturumda içerik bazlı inceleme
  bekliyor (tur #4'ten beri).

## Doğrulama (§3)

```
./scripts/validate.sh   → 31 skill, 0 hata, 0 uyarı
./scripts/check-links.sh → 70 link, 0 kırık
```

## Sonuç

1 doğrulanmış, kaynak linkli değişiklik (Kotlin 2.4.20 bump) + 1 kendi
tutarsızlık düzeltmesi (stale KSP-pairing notu). `docs/maintenance-log.md`'ye
ayrı commit ile işlenecek.
