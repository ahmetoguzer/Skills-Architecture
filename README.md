# Skills Architecture — Android & Native Mobile

Android, Kotlin Multiplatform ve iOS geliştirme için **Claude Skills** koleksiyonu.
Her skill, o alandaki mimari kararları, kod şablonlarını ve kalite kontrol listelerini içerir;
Claude bir istekle karşılaştığında ilgili skill'i otomatik yükleyip o standartlara göre üretim yapar.

## Neden?

Tek büyük bir "Android uzmanı" prompt'u yerine **konuya göre ayrılmış, talep anında yüklenen**
skill'ler kullanılır. Sonuç:

- Bağlam israfı yok — sadece ilgili bilgi yüklenir
- Kararlar tek yerde tanımlı — her sohbette aynı mimariyi tekrar anlatmazsın
- Ekip standardı versiyonlanır — skill'i güncellersin, herkes yeni standarda geçer

## Skill Kataloğu

| Skill | Kapsam |
|---|---|
| [`android-architect`](skills/android-architect) | Clean Architecture, MVVM/MVI, Hilt, multi-module — **giriş noktası** |
| [`android-compose-ui`](skills/android-compose-ui) | Design system, Material 3, theming, animasyon, accessibility, adaptive UI |
| [`android-data-layer`](skills/android-data-layer) | Offline-first, Room, Retrofit/Ktor, Paging 3, WorkManager, DataStore |
| [`android-testing`](skills/android-testing) | Unit/integration/UI test, Turbine, MockK, fake vs mock, flaky test teşhisi |
| [`android-performance`](skills/android-performance) | Startup, jank, bellek, APK boyutu, baseline profile, ANR, Macrobenchmark |
| [`android-gradle-build`](skills/android-gradle-build) | Version catalog, convention plugin, build-logic, variant, build hızı |
| [`android-security`](skills/android-security) | Keystore, cert pinning, token yönetimi, biyometrik, Play Integrity, KVKK/GDPR |
| [`android-native-ndk`](skills/android-native-ndk) | JNI, CMake, C++ entegrasyonu, native crash analizi, ABI, 16 KB page size |
| [`kmp-shared`](skills/kmp-shared) | Kotlin Multiplatform, expect/actual, Ktor/SQLDelight, SKIE, kademeli geçiş |
| [`ios-swift-architect`](skills/ios-swift-architect) | SwiftUI + Observation, Swift Concurrency, SPM modülerlik, Swift Testing |
| [`mobile-ci-release`](skills/mobile-ci-release) | GitHub Actions, imzalama, fastlane, Play/App Store, staged rollout |
| [`mobile-code-review`](skills/mobile-code-review) | PR review, katman ihlali, anti-pattern ve güvenlik taraması |

Skill'lerin nasıl birbirine bağlandığı ve ne zaman hangisinin devreye girdiği:
**[docs/ARCHITECTURE.md](docs/ARCHITECTURE.md)**

## Kurulum

### Kişisel kullanım (tüm projelerde aktif)

```bash
git clone https://github.com/ahmetoguzer/Skills-Architecture.git
cd Skills-Architecture
./scripts/install.sh            # ~/.claude/skills/ altına symlink'ler
```

### Tek bir projede kullanım

```bash
git clone https://github.com/ahmetoguzer/Skills-Architecture.git
./scripts/install.sh --project /yol/projene    # <proje>/.claude/skills/
```

Ya da submodule olarak:

```bash
git submodule add https://github.com/ahmetoguzer/Skills-Architecture.git .claude/skills-architecture
ln -s ../skills-architecture/skills/android-architect .claude/skills/android-architect
```

### Doğrulama

```bash
./scripts/validate.sh           # frontmatter, isim eşleşmesi, kırık referans kontrolü
```

## Kullanım

Kurulumdan sonra ayrı bir şey yapman gerekmez — istek yaz, Claude uygun skill'i seçer:

```
"Sepet ekranı için offline çalışan bir feature ekle"
   → android-architect + android-data-layer + android-compose-ui

"Uygulama açılışı 2 saniye sürüyor"
   → android-performance

"Bu PR'ı incele"
   → mobile-code-review

"Bu ekranı iOS'ta da çalıştırmak istiyorum"
   → kmp-shared (+ ios-swift-architect)
```

Açıkça çağırmak istersen: `/android-architect`, `/kmp-shared` …

## Katkı / Genişletme

Yeni bir skill eklerken:

1. `skills/<isim>/SKILL.md` oluştur — YAML frontmatter'da `name` ve `description` zorunlu
2. `description` alanına **tetikleyici ifadeleri** (Türkçe + İngilizce) yaz; skill seçimi buna göre yapılır
3. 500 satırı geçen içeriği `references/` altına böl, SKILL.md'den referans ver
4. Sonuna bir **checklist** koy — üretilen kodun doğrulanabilir olması için
5. `./scripts/validate.sh` çalıştır

Detaylı yazım kuralları: [docs/AUTHORING.md](docs/AUTHORING.md)

## Lisans

MIT
