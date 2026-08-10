# Skills Architecture — Android & Native Mobile

Android, Kotlin Multiplatform ve iOS geliştirme için **Claude Skills** koleksiyonu.
Her skill; o alandaki mimari kararları, kod şablonlarını ve kalite kontrol listelerini içerir.
Claude bir istekle karşılaştığında ilgili skill'i talep anında yükleyip o standartlara göre üretim yapar.

## Neden?

Tek büyük bir "Android uzmanı" prompt'u yerine **konuya göre ayrılmış, talep anında yüklenen**
skill'ler kullanılır. Sonuç:

- Bağlam israfı yok — sadece ilgili bilgi yüklenir
- Kararlar tek yerde tanımlı — her sohbette aynı mimariyi tekrar anlatmazsın
- Ekip standardı versiyonlanır — skill'i güncellersin, herkes yeni standarda geçer
- Süreç de kodlanır — `delivery-pipeline` işin nasıl teslim edileceğini belirler, sadece nasıl yazılacağını değil

## Skill Kataloğu

### Orkestrasyon
| Skill | Kapsam |
|---|---|
| [`delivery-pipeline`](skills/delivery-pipeline) | **Varsayılan giriş noktası.** netleştir → yönlendir → planla → fazlar → kodla → test → doküman → self-review → commit → push/PR |

### Çekirdek — kod üretir
| Skill | Kapsam |
|---|---|
| [`android-architect`](skills/android-architect) | Clean Architecture, MVVM/MVI, Hilt, multi-module, katman sınırları |
| [`feature-scaffold`](skills/feature-scaffold) | Domain + data + UI kapsayan yeni feature iskeleti, isimlendirme, DI, navigasyon |
| [`android-data-layer`](skills/android-data-layer) | Offline-first/SSOT, Room, Retrofit/Ktor, Paging 3, WorkManager, DataStore |
| [`android-compose-ui`](skills/android-compose-ui) | Design system, Material 3, theming, animasyon, accessibility, adaptive UI |
| [`mobile-analytics`](skills/mobile-analytics) | Event taksonomisi, ViewModel'den tracking, sağlayıcı soyutlaması, PII koruması |

### Kalite — üretileni doğrular
| Skill | Kapsam |
|---|---|
| [`android-testing`](skills/android-testing) | Unit/integration/UI test, Turbine, MockK, fake vs mock, flaky teşhisi |
| [`android-performance`](skills/android-performance) | Startup, jank, bellek, APK boyutu, baseline profile, ANR, Macrobenchmark |
| [`android-security`](skills/android-security) | Keystore, cert pinning, token yönetimi, biyometrik, Play Integrity, KVKK/GDPR |
| [`mobile-code-review`](skills/mobile-code-review) | PR review, katman ihlali, anti-pattern ve güvenlik taraması |

### Platform
| Skill | Kapsam |
|---|---|
| [`android-native-ndk`](skills/android-native-ndk) | JNI, CMake, C++ entegrasyonu, native crash analizi, ABI, 16 KB page size |
| [`kmp-shared`](skills/kmp-shared) | Kotlin Multiplatform, expect/actual, Ktor/SQLDelight, SKIE, kademeli geçiş |
| [`ios-swift-architect`](skills/ios-swift-architect) | SwiftUI + Observation, Swift Concurrency, SPM modülerlik, Swift Testing |
| [`xml-compose-migration`](skills/xml-compose-migration) | XML/Fragment → Compose kademeli geçiş, interop, davranış eşdeğerliği |

### Süreç
| Skill | Kapsam |
|---|---|
| [`android-gradle-build`](skills/android-gradle-build) | Version catalog, convention plugin, build-logic, variant, build hızı |
| [`git-workflow`](skills/git-workflow) | Branch stratejisi, atomik commit, rebase/merge, PR, conflict çözümü |
| [`mobile-ci-release`](skills/mobile-ci-release) | GitHub Actions **ve Jenkins**, detekt/Sonar kapıları, imzalama, staged rollout |

### Dokümantasyon
| Skill | Kapsam |
|---|---|
| [`docs-guide`](skills/docs-guide) | Bilgi nereye gider: skill mi, `docs/` mı, yorum mu; çok-tüketicili standart yapısı |
| [`adr`](skills/adr) | Architecture Decision Record: bağlam, alternatifler, karar, kabul edilen bedel |
| [`design-doc`](skills/design-doc) | Kodlama öncesi teknik tasarım, fazlara bölünmüş teslimat planı |
| [`change-docs`](skills/change-docs) | feature-doc / fix-doc (kök neden) / refactor-doc / release notes |
| [`kdoc-standards`](skills/kdoc-standards) | KDoc, "neden" yorumları, TODO disiplini, Dokka, DocC |

Skill'lerin nasıl birbirine bağlandığı, yönlendirme haritası ve sınır kuralları:
**[docs/ARCHITECTURE.md](docs/ARCHITECTURE.md)** · in-tree indeks: **[skills/README.md](skills/README.md)**

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

### Projeye bağlama

Skill'ler tek başına yeterli değil — projenin **giriş dosyası** onlara yönlendirmeli:

```bash
cp templates/CLAUDE.md /yol/projene/CLAUDE.md    # sonra <ACILI PARANTEZ> alanlarını doldur
```

`templates/CLAUDE.md` bilerek yalındır: ne olduğu, varsayılan akış, skill tablosu,
non-negotiables ve build komutları. Derinlik skill'lerde kalır — aynı kuralı iki yere
yazarsan biri eskir ve çelişirler.

### Doğrulama

```bash
./scripts/validate.sh           # frontmatter, isim eşleşmesi, kırık referans, katalog senkronu
```

## Kullanım

Kurulumdan sonra ayrı bir şey yapman gerekmez — istek yaz, Claude uygun skill'i seçer:

```
"Sepet ekranı için offline çalışan bir feature ekle"
   → delivery-pipeline → feature-scaffold → android-data-layer
                       → android-compose-ui → android-testing → change-docs

"Uygulama açılışı 2 saniye sürüyor"
   → android-performance

"Bu PR'ı incele"
   → mobile-code-review

"Bu ekranı iOS'ta da çalıştırmak istiyorum"
   → kmp-shared (+ ios-swift-architect)

"Şu eski Fragment'ı Compose'a taşı"
   → xml-compose-migration
```

Açıkça çağırmak istersen: `/delivery-pipeline`, `/android-architect`, `/adr` …

## Katkı / Genişletme

Yeni bir skill eklerken:

1. `skills/<isim>/SKILL.md` oluştur — YAML frontmatter'da `name` ve `description` zorunlu
2. `description` alanına **tetikleyici ifadeleri** (Türkçe + İngilizce) ve devretme sınırını yaz
3. 500 satırı geçen içeriği `references/` altına böl, SKILL.md'den referans ver
4. Sonuna bir **checklist** koy — üretilen kodun doğrulanabilir olması için
5. Üç kataloğu güncelle: bu dosya, `skills/README.md`, `templates/CLAUDE.md`
6. `./scripts/validate.sh` çalıştır (katalog senkronunu da kontrol eder)

Detaylı yazım kuralları: [docs/AUTHORING.md](docs/AUTHORING.md)

## Lisans

MIT
