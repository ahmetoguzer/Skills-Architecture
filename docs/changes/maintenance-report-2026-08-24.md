# Bakım Turu #5 — 2026-08-24

**İlk tam otomatik, elle müdahalesiz tur.** Routine `trig_01EACSXPUGoWmo3nTw7ovUrG`
zamanlanmış cron ile 2026-08-24T00:07:10Z'de kalıcı oturuma ateşlendi;
`docs/MAINTENANCE.md` prosedürü baştan sona insan girdisi olmadan uygulandı.

Tur sayısı: 5 (4'e ve 12'ye bölünmüyor → periyodik görev yok, sadece
düzenli tarama).

## Taranan kaynaklar (§1)

AGP, Compose/Navigation/CameraX/Credential Manager, Kotlin/KSP, Play Console
politikası, Xcode/Swift/App Store, Firebase (Crashlytics/Remote Config) —
6 WebSearch sorgusu.

## Bulgular ve değişiklik

| Bulgu | Kaynak | Aksiyon |
|---|---|---|
| Compose 1.12 / BOM 2026.08.00, AGP 9.2.0+ ile **compileSdk API 37 gerektiriyor** | Compose resmi sürüm notları | `android-gradle-build/SKILL.md`: `compileSdk = 35` → `37` (geçen turun kendi AGP/Compose güncellemesiyle oluşan tutarsızlığı kapatıyor) |
| AGP 9.3.0 yayınlandı (Temmuz 2026, "keep rules source sets") | AGP resmi sürüm sayfası | Sadece not — 9.2.0 hâlâ desteklenen, zorunlu geçiş değil; bir sonraki turda izlenecek |
| `Modifier.onFirstVisible()` deprecated → `onVisibilityChanged()` | Compose değişiklik notları | Grep: `skills/*/SKILL.md` içinde referans yok — aksiyon gerekmedi |
| Play Console: 26 Ağustos 2026 anonim-sohbet kuralı + geofencing'in onaylı foreground-service kullanım listesinden çıkarılması | Play Console politika duyurusu | Grep: geofencing referansı yok — aksiyon gerekmedi |
| Play Console: `READ_CALL_LOG` ile telefon-arama doğrulaması artık kabul edilmiyor, Digital Credentials API / SMS Retriever API'ye geçiş isteniyor | Play Console politika duyurusu | Grep: `android-auth-credentials/SKILL.md` yalnızca genel "SMS OTP" (satır 11, 28) içeriyor, zaten temkinli — aksiyon gerekmedi |
| Xcode 26.6 RC / Swift 6.3 | Apple geliştirici duyuruları | `ios-swift-architect` sürüm numarası pinlemiyor — aksiyon gerekmedi |
| Firebase Crashlytics init-timing düzeltmesi, Remote Config Swift `configUpdates` AsyncSequence eklendi | Firebase sürüm notları | Düşük öncelik, davranış değişikliği değil — aksiyon gerekmedi |

## Doğrulanamayan / bilinçli dokunulmayan

- **Kotlin/KSP sürüm çifti** — Kotlin 2.4.20-RC (12 Ağustos 2026), stable
  sürüm Eylül 2026'da planlanıyor. Eşlenen bağımsız doğrulanmış KSP sürümü
  bulunamadı. **İkinci ardışık tur ertelemesi** (tur #4'te de aynı sebep).
  Stable Kotlin sürümü ve KSP eşleşmesi netleşince ele alınacak.

## Açık, ele alınmayan standing item

- `github.com/android/skills` (Google'ın resmî Android AI-skill koleksiyonu)
  — tur #4'te bulundu, ayrı bir oturumda içerik bazlı inceleme bekliyor.
  Bu tur yeniden araştırılmadı (§1b her turda zorunlu değil).

## Yönlendirme evali (§4c)

Tur 5, 4'e bölünmüyor → bu tur çalıştırılmadı. Sıradaki: tur #8.

## Doğrulama (§3)

```
./scripts/validate.sh   → 31 skill, 0 hata, 0 uyarı
./scripts/check-links.sh → 70 link, 0 kırık
```

## Sonuç

1 doğrulanmış, kaynak linkli değişiklik. `docs/maintenance-log.md`'ye ayrı
commit ile işlenecek.
