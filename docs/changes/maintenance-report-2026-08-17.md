# Bakım Turu Raporu — 2026-08-17 (Tur #4)

İlk gerçek planlı haftalık tur (önceki 3 giriş test/teşhis turlarıydı).
Prosedür: [docs/MAINTENANCE.md](../MAINTENANCE.md).

## Yapılan değişiklikler

| Skill | Değişiklik | Kaynak |
|---|---|---|
| `android-gradle-build` | `agp` 8.7.3 → 9.2.0 | [AGP 9.2.0 release notes](https://developer.android.com/build/releases/agp-9-2-0-release-notes) |
| `android-gradle-build` | `composeBom` 2024.12.01 → 2026.08.00 | [Jetpack Compose August '26 release](https://android-developers.googleblog.com/2026/08/jetpack-compose-august-2026-release.html) |
| `android-platform-upgrade` | Play Store targetSdk bölümüne somut tarih/eşik eklendi (31 Ağustos 2026, API 36/35, 1 Kasım uzatma) | [Play Console Help — Target API level requirements](https://support.google.com/googleplay/android-developer/answer/11926878) |

## Teyit edilemeyen / bilinçli dokunulmayan

- **Kotlin/KSP sürüm çifti** — Kotlin 2.3.0'ın stable olduğu teyitli
  (kotlinlang.org), ancak ona eşlenen tam KSP patch sürümü bu turda
  bağımsız doğrulanamadı. İkisini birlikte güncellemek gerektiğinden
  (uyumsuz çift = bozuk örnek), bu tur dokunulmadı. **Sonraki tur için not.**

## İncelenip değişiklik gerektirmeyen (referans repo taraması, §1b)

- `android-architect` vs `nowinandroid` — katman yapısı (data/domain/UI,
  tek yönlü akış) hâlâ örtüşüyor, desen sapması yok
- `kmp-shared` — Compose Multiplatform iOS stabilliği zaten doğru
  ifade ediliyor, değişiklik gerekmedi
- `ios-swift-architect` vs Apple örnek kod / Swift 6 pattern'leri —
  `@Observable` + MVVM + strict concurrency rehberliği güncel pratikle uyumlu
- `android-compose-ui` vs `compose-samples` — orada görülen BOM (2026.03.00)
  zaten bizim uyguladığımız daha güncel sürümden eski, çelişki yok

## İnsan kararı bekleyen — önemli bulgu

**`github.com/android/skills`** — Google'ın kendi resmî "AI-optimized"
Android skill koleksiyonu (~6.8k yıldız, aktif). Kapsamı bizimkiyle
doğrudan örtüşüyor: Compose, testing, performans (R8), build system
(AGP 9 upgrade), güvenlik (intent security), Wear/TV. Otomatik bir
bakım turunda harmanlanamayacak kadar büyük bir bulgu — runbook §0
("küçük ve doğrulanabilir değişiklikler") sınırını aşıyor.

**Öneri:** ayrı bir oturumda bu repo içerik bazında incelenip hangi
fikirlerin bizim yapımıza (karar rehberi + kod + checklist, TR/EN)
harmanlanacağına karar verilmeli. Kopyalama değil, seçici harman.

## Yönlendirme evali (§4c, her 4. tur)

`evals/routing.yaml` — **58/58 vaka geçti** (12 tuzak dahil), yalnızca
skill description'ları okunarak. Description değişikliği gerekmedi.

İki yumuşak belirsizlik notu (eşik altı, gelecekte tekrar ederse
description'a işlenir):
- *"login ekranı çok yavaş açılıyor"* → doğru cevap `android-performance`,
  ama `android-auth-credentials`'ın description'ında **birebir**
  "login ekranı" tetikleyicisi var — saf substring eşleştirme yapan bir
  yönlendirici burada yanılabilir. Holistik okuma doğru sonucu veriyor.
- *"üretimde ödeme başarı oranı düştü"* → doğru cevap
  `mobile-observability`, ama `mobile-analytics`'in "funnel" tetikleyicisi
  gerçek bir çekişme yaratıyor (başarı oranı hem sağlık hem funnel metriği
  okunabilir).

## Doğrulama

`validate.sh` ve `check-links.sh` temiz: 31 skill, 0 hata, 0 uyarı; 69 link çözülüyor.
