# Bakım Turu #8 — 2026-09-14

Kalıcı oturuma bağlı Routine, cron ile zamanında ateşlendi; `docs/MAINTENANCE.md`
prosedürü uygulandı.

Tur sayısı: 8 (4'e bölünüyor → **yönlendirme evali bu tur çalıştırıldı**; 12'ye
bölünmüyor → derin denetim yok).

## Taranan kaynaklar (§1)

AGP, Compose/Navigation/CameraX, google/ksp#2964 takibi + versiyonlama şeması,
Play Console politikası, Xcode/Swift/App Store Connect, KMP/Firebase — 6
WebSearch sorgusu + 1 WebFetch doğrulaması (google/ksp/releases sayfası).

## Bulgular ve değişiklikler

| Bulgu | Kaynak | Aksiyon |
|---|---|---|
| **`google/ksp#2964` kapandı**, KSP 2.3.10'da düzeltildi (Temmuz 2026) | github.com/google/ksp/issues/2964 | `android-gradle-build/SKILL.md`: `kotlin = "2.1.0"` → `"2.4.0"`, `ksp = "2.1.0-1.0.29"` → `"2.3.12"`. **4 tur süren erteleme sona erdi.** |
| KSP sürümleme şeması değişti: artık bağımsız semver (`2.3.x`), eski `<kotlin>-<ksp>` bileşik format terk edildi | github.com/google/ksp/releases (WebFetch ile doğrulandı) | Version catalog'daki not güncellendi; bu format değişikliğini bilmeyen biri eski deseni arayabilirdi |
| KSP 2.3.12 (Eylül 9) ayrıca AGP 9'un gömülü Kotlin'iyle R-class çözümleme hatasını düzeltiyor | KSP 2.3.12 sürüm notları | 2.3.10 değil, en güncel 2.3.12 seçildi — AGP 9.4.0 kullandığımız için doğrudan ilgili |
| Play Store: **geliştirici kimlik doğrulama** zorunluluğu Eylül 2026'da 4 ülkede başladı (Brezilya, Endonezya, Singapur, Tayland), küresel genişleme 2027 | Play Console duyurusu | `android-platform-upgrade/SKILL.md` §7'ye izleme notu eklendi — henüz hiçbir bölgemizde zorunlu değil |
| AGP/Compose/CameraX'te yeni davranış değişikliği yok (son AGP hâlâ 9.4.0, Compose hâlâ 1.12) | AGP/AndroidX sürüm sayfaları | Aksiyon gerekmedi |
| Xcode 27 RC/beta süreçleri, App Store Connect TestFlight güncellemeleri | Apple duyuruları | `ios-swift-architect` sürüm pinlemiyor — aksiyon gerekmedi |
| Firebase Remote Config kullanım bazlı fiyatlandırma + A/B testi entegrasyonu | Firebase duyuruları | Maliyet/iş kararı, mimari değil — skill kapsamı dışı |

## Yönlendirme evali (§4c, her 4. tur)

31 skill'in tamamının frontmatter `description`'ları **yalnızca** okunarak
`evals/routing.yaml`'daki 58 vaka (12 tuzak dahil) değerlendirildi:

**Sonuç: 58/58 geçti.**

İki yumuşak belirsizlik notu (eşik altı, description değişikliği tetiklemedi —
tur #4'teki bulgularla tutarlı, yeni bir regresyon yok):
- "login ekranı çok yavaş açılıyor" — doğru cevap performance, ama
  auth-credentials'ın description'ında birebir "login ekranı" tetikleyicisi var
- "üretimde ödeme başarı oranı düştü" — observability ile analytics (funnel)
  arasında gerçek bir çekişme var

Her iki not da iki tur önceki (#4) tespitle birebir aynı — zamanla kötüleşmemiş,
description değişikliği gerekmiyor.

## Açık, ele alınmayan standing item

- `github.com/android/skills` — hâlâ ayrı bir oturumda içerik bazlı inceleme
  bekliyor (tur #4'ten beri).

## Doğrulama (§3)

```
./scripts/validate.sh   → 31 skill, 0 hata, 0 uyarı
./scripts/check-links.sh → 70 link, 0 kırık
```

## Sonuç

2 doğrulanmış, kaynak linkli değişiklik (Kotlin/KSP bump + Play Store izleme
notu) + yönlendirme evali 58/58. `docs/maintenance-log.md`'ye ayrı commit ile
işlenecek.
