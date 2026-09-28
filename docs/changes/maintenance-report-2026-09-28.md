# Bakım Turu #10 — 2026-09-28

Kalıcı oturuma bağlı Routine, cron ile zamanında ateşlendi; `docs/MAINTENANCE.md`
prosedürü uygulandı.

Tur sayısı: 10 (4'e ve 12'ye bölünmüyor → periyodik görev yok).

## Taranan kaynaklar (§1)

AGP, Compose/Navigation/CameraX, Kotlin/KSP, Play Console politikası, Xcode
27/Swift 6.4/App Store Connect, Android Weekly/KMP/on-device AI ekosistem
haberleri — 6 WebSearch sorgusu + 1 doğrulama sorgusu (ADK for Kotlin detayları).

## Bulgular ve değişiklik

| Bulgu | Kaynak | Aksiyon |
|---|---|---|
| **Google, ADK for Kotlin 1.0'ı yayınladı** — Kotlin Multiplatform üzerine kurulu, production-ready AI agent (çok adımlı, tool-calling) çerçevesi. Cihaz üstünde LiteRT-LM (Gemma, tam tool calling) veya hibrit olarak Firebase AI Logic ile çalışıyor | Google Developers Blog, github.com/google/adk-kotlin | `on-device-ai/SKILL.md`'ye yeni bölüm eklendi: "Ajan (Agent) Mimarisi Gerekiyorsa — ADK for Kotlin", ne zaman gerekli ne zaman gereksiz karmaşıklık olduğuna dair karar notuyla; description'a tetikleyici kelimeler eklendi |
| AGP hâlâ 9.4.0, Compose hâlâ 1.12/BOM 2026.08.00 — yeni davranış değişikliği yok | AGP/AndroidX sürüm sayfaları | Aksiyon gerekmedi |
| Xcode 27.1 beta / Swift 6.4 devam ediyor | Apple duyuruları | `ios-swift-architect` sürüm pinlemiyor — aksiyon gerekmedi |
| Play Store geliştirici doğrulama — 30 Eylül 2026 uyum tarihi yaklaşıyor ama kapsam (4 ülke) değişmedi | Play Console duyuruları | Tur #8'de zaten not edilmişti, ek aksiyon gerekmedi |
| KSP: KMP projelerinde `ksp(...)` Gradle konfigürasyonu hedef-özel konfigürasyonlar lehine deprecate edildi | Kotlin/KSP dokümantasyonu | `kmp-shared/SKILL.md` KSP konfigürasyon syntax'ı içermiyor — aksiyon gerekmedi |

## Açık, ele alınmayan standing item

- `github.com/android/skills` — hâlâ ayrı bir oturumda içerik bazlı inceleme
  bekliyor (tur #4'ten beri).

## Doğrulama (§3)

```
./scripts/validate.sh   → 31 skill, 0 hata, 0 uyarı
./scripts/check-links.sh → 70 link, 0 kırık
```

## Sonuç

1 doğrulanmış, kaynak linkli yeni içerik (ADK for Kotlin bölümü).
`docs/maintenance-log.md`'ye ayrı commit ile işlenecek.
