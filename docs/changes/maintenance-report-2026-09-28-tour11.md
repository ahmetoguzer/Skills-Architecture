# Bakım Turu #11 — 2026-09-28 (ikinci tetiklenme, elle ateşlendi)

Kullanıcının açık isteğiyle Routine bugün ikinci kez ateşlendi (`fire_trigger`);
`docs/MAINTENANCE.md` prosedürü, **yeni eklenen §2a** dahil olmak üzere uygulandı.

Tur sayısı: 11 (4'e ve 12'ye bölünmüyor → periyodik görev yok).

## §2a — İlk tam version-catalog geçişi (yeni kural)

Önceki turda eklenen kural gereği, `android-gradle-build`'in `[versions]`
bloğundaki **her** giriş tek tek gözden geçirildi (yalnızca değişen değil):

| Giriş | Mevcut | Kontrol sonucu | Aksiyon |
|---|---|---|---|
| `agp` | 9.4.0 | En güncel stable, değişiklik yok | Dokunulmadı |
| `kotlin` | 2.4.20 | En güncel stable, değişiklik yok | Dokunulmadı |
| `ksp` | 2.3.12 | En güncel, Kotlin 2.4.20 ile uyumlu | Dokunulmadı |
| `composeBom` | 2026.08.00 | En güncel, değişiklik yok | Dokunulmadı |
| `hilt` | **2.53.1 → 2.60.1** | Bekleyen bump, doğrulandı: `google/dagger/releases`'ten teyitli | **Güncellendi** |
| `coroutines` | **1.9.0 → 1.11.0** | İki minör sürüm geride, kırıcı API değişikliği yok | **Güncellendi** |
| `retrofit` | **2.11.0 → 2.12.0** | 3.0.0 de var ama major bump (OkHttp 3.14→4.12) — §2a "küçük bump" sınırını aşıyor | **Güncellendi (2.x içinde)**, 3.0.0 ayrı değerlendirme için not edildi |

## Diğer bulgular

| Bulgu | Kaynak | Aksiyon |
|---|---|---|
| **Play Store geliştirici doğrulama artık kesin tarihli**: 30 Eylül 2026'dan itibaren 4 ülkede (Brezilya, Endonezya, Singapur, Tayland) sertifikalı cihazlarda doğrulanmamış geliştiricilerin uygulamaları normal yoldan kurulamıyor (ADB/advanced flow hariç) | Android Developers Blog, Play Console Help | `android-platform-upgrade/SKILL.md` §7 güncellendi — somut tarih ve sonuç eklendi |
| Retrofit 3.0.0 mevcut (OkHttp 4.12'ye geçiş) | github.com/square/retrofit/releases | Şimdilik uygulanmadı — büyük bağımlılık zinciri değişikliği, ayrı bir değerlendirme gerektiriyor |
| AGP/Compose/CameraX'te bu hafta yeni davranış değişikliği yok | AGP/AndroidX sürüm sayfaları | Aksiyon gerekmedi |
| Xcode 27.1 beta devam ediyor | Apple duyuruları | `ios-swift-architect` sürüm pinlemiyor — aksiyon gerekmedi |

## Açık, ele alınmayan standing item

- `github.com/android/skills` incelemesi tamamlandı (bu oturumda, ayrı bir
  değerlendirme olarak) — bu standing item artık **kapalı**. Tespit edilen
  tek somut fark (Hilt sürümü) bu turda uygulandı.
- **Yeni açık item:** Retrofit 3.0.0'a geçiş — ayrı bir oturumda breaking
  change taraması gerektiriyor (OkHttp major bump'ının etkisi).

## Doğrulama (§3)

```
./scripts/validate.sh   → 31 skill, 0 hata, 0 uyarı
./scripts/check-links.sh → 70 link, 0 kırık
```

## Sonuç

3 doğrulanmış, kaynak linkli sürüm güncellemesi (Hilt, coroutines, Retrofit) +
1 somut tarih güncellemesi (Play Store geliştirici doğrulama) + §2a'nın ilk
tam koşumu. `docs/maintenance-log.md`'ye ayrı commit ile işlenecek.
