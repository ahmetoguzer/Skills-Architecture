<!--
  ŞABLON — projenize kopyalayıp <ACILI PARANTEZ> alanlarını doldurun.
  Bu dosya bilerek YALINDIR. Derinlik skill'lerde (.claude/skills/) yaşar.
  Bir kuralı hem buraya hem skill'e yazmayın — biri eskir ve çelişirler.
-->

# CLAUDE.md — <proje-adı>

Bu repoda Claude Code için rehber. Dosya bilerek yalın; derinlik **skill'lerde**
(`.claude/skills/`) ve onların referans verdiği dokümanlarda.

## Bu ne

**<Ürün adı>** — <bir cümlelik tanım: kime, ne yapıyor>.
<Büyük/küçük> **<multi-module | single-module>** Kotlin/Android kod tabanı.
Mevcut mimariye ve takım standartlarına uy; paralel stack kurma, katman kısayolu yapma.

## Varsayılan akış

**Önemsiz olmayan her değişiklikte — yeni feature, bug fix veya refactor** —
`delivery-pipeline` skill'ini varsayılan al: **netleştir → yönlendir → planla → fazlar →
kodla → test → doküman → self-review → commit → push/PR**.

İstek belirsizse önce odaklı soru sor (yalnızca kullanıcının karar vermesi gerekenleri);
kodlamadan önce plan onayı al; **kod yazmadan önce feature branch'ini `<develop>`'tan aç**
(asla `<develop>` üzerinde geliştirme yapma); commit öncesi onay al (çok fazlı işte faz
başına atomik commit öner); push / PR için **ayrıca** onay al.

Soru, açıklama veya tek satırlık düzeltmede pipeline'ı atla — cevapla ya da yap.

## Skill'ler — önce doğru olanı yükle

Detaylı ve güncel konvansiyonlar skill'lerde. Kuralları sıfırdan yeniden türetmek yerine
skill'i yükle:

| Skill | Ne zaman |
|---|---|
| `delivery-pipeline` | Önemsiz olmayan bir değişikliği uçtan uca yürütmek (yukarıdaki varsayılan akış) |
| `android-architect` | Katman sınırı, modül kararı, MVVM/MVI seçimi, DI tasarımı |
| `feature-scaffold` | Domain + data + UI kapsayan yeni feature iskeleti |
| `android-data-layer` | Repository, DataSource, UseCase, offline/cache, Room, sync |
| `android-compose-ui` | Compose ekranı oluşturma/değiştirme, design system, a11y |
| `android-navigation` | Ekranlar arası geçiş, route tanımı, deep link, back stack |
| `android-auth-credentials` | Giriş akışı, passkey, biyometrik kilit, oturum yönetimi |
| `android-notifications` | Push bildirim, FCM, bildirim izni ve kanalları |
| `android-media-camera` | Kamera, video oynatma, medya seçimi, görüntü yükleme |
| `android-adaptive-formfactors` | Tablet/foldable düzeni, widget, Wear/TV kararı |
| `on-device-ai` | Cihaz üstü/bulut AI özelliği, ML Kit, model entegrasyonu |
| `android-testing` | ViewModel/UseCase/Repository testleri, Flow testi, UI testi |
| `android-performance` | Startup, jank, bellek, APK boyutu, baseline profile, ANR |
| `android-gradle-build` | Gradle, modül tanımı, bağımlılık, build süresi |
| `android-security` | Token saklama, SSL pinning, izinler, biyometrik |
| `mobile-analytics` | Event tracking ekleme/taşıma, event taksonomisi |
| `feature-flags` | Kademeli açılış, A/B testi, kill switch |
| `mobile-observability` | Üretimdeki crash/hata izleme, alarm, olay müdahalesi |
| `android-platform-upgrade` | targetSdk yükseltme, yeni Android sürümü uyumu |
| `mobile-code-review` | PR incelemek veya kodu review'a hazırlamak |
| `git-workflow` | Branch açma, commit, PR açma/güncelleme |
| `mobile-ci-release` | CI pipeline, imzalama, store yayını, staged rollout |
| `xml-compose-migration` | XML/Fragment ekranı Compose'a taşıma |
| `kmp-shared` | iOS ile kod paylaşımı, Kotlin Multiplatform |
| `ios-swift-architect` | iOS/SwiftUI tarafı |
| `android-native-ndk` | JNI / C++ / NDK |
| `docs-guide` | Bir bilginin nereye yazılacağı (skill mi, docs mı, yorum mu) |
| `adr` | Önemli bir mimari kararı kaydetmek |
| `design-doc` | Büyük bir feature/refactor için kodlama öncesi tasarım |
| `change-docs` | Tamamlanan feature/fix/refactor kaydı, release notes |
| `kdoc-standards` | KDoc / kod içi yorum yazımı |

Tam mimari ve kullanım rehberi: `docs/architecture/SKILLS_ARCHITECTURE.md`.
Skill yazım referansı: `.claude/skills/README.md`.

## Non-negotiables (detaylar skill'lerde)

<!-- 6-8 madde. Her biri TEK SATIR ve DOĞRULANABİLİR olmalı.
     "Temiz kod yazın" non-negotiable değildir. -->

- Bağımlılıklar içe akar: `:app → :feature:* → :core:domain ← :core:data`.
  **Core asla feature'a bağımlı olmaz.** `:core:domain` saf Kotlin
  (`android.*`/`androidx.*`/Retrofit/Room yok).
- Yeni Compose ViewModel'leri `<BaseViewModel sınıfınız>`'ı genişletir;
  state `<setState { copy(...) } gibi mekanizmanız>` ile değişir.
  Akış: ViewModel → UseCase → Repository (ViewModel doğrudan Repository çağırmaz).
- Dispatcher inject edilir (`@IoDispatcher`) — `Dispatchers.IO` hardcode edilmez.
  Remote/local çağrılar `runCatching { }` ile sarılır.
- Kullanıcıya görünen string'ler `<string yöneticiniz, örn. ContentManager.getValue(R.string.key)>`
  üzerinden gelir — hardcode edilmez. Kaynak kodda ve log'da sır/PII bulunmaz.
- Testler: `runTest` + `<test kuralınız>` + MockK + Turbine;
  `runBlocking`/`Thread.sleep`/Mockito kullanılmaz.
- Analytics event'leri ViewModel'den gönderilir, asla `@Composable` içinden.
- <Projeye özel diğer madde>

## Build hızlı referans

```zsh
./gradlew :app:assemble<Flavor>Debug     # <ne zaman kullanılır>
./gradlew test<Flavor>DebugUnitTest      # unit testler
./gradlew <detektAll>                    # statik analiz (takım config + baseline)
./gradlew --stop                         # branch değiştirmeden önce
```

## Kanonik dokümanlar

- `AGENTS.md` — genel AI ajan rehberi (mimari, test, komutlar).
- `.github/copilot-instructions.md` — tam takım standardı (Copilot'u da besler).
- `docs/` — kategorili (bkz. `docs/README.md`): `architecture/` (ADR'ler,
  `SKILLS_ARCHITECTURE.md`), `testing/`, `ci-cd/`, `performance/`, `security/`, `changes/`.
- Modül-local `copilot-instructions.md` (örn. `feature/<takım>/<modül>/…`) o paket için
  bu dosyaları **ezer**.
