# Skills — In-Tree Referans

Bu klasördeki her alt dizin bir Claude Skill'idir. Bu dosya **hızlı indeks** ve
**yönlendirme haritası**; yazım kuralları için `../docs/AUTHORING.md`,
mimari gerekçe için `../docs/ARCHITECTURE.md`.

## İndeks

### Orkestrasyon
| Skill | Ne zaman |
|---|---|
| [`delivery-pipeline`](delivery-pipeline) | Önemsiz olmayan her değişikliği uçtan uca yürütür — **varsayılan giriş noktası** |

### Çekirdek (kod üretir)
| Skill | Ne zaman |
|---|---|
| [`android-architect`](android-architect) | Katman sınırı, modül kararı, MVVM/MVI, DI tasarımı |
| [`feature-scaffold`](feature-scaffold) | Domain + data + UI kapsayan yeni feature iskeleti |
| [`android-data-layer`](android-data-layer) | Repository, offline/SSOT, Room, Retrofit/Ktor, Paging, sync |
| [`android-compose-ui`](android-compose-ui) | Compose ekranı, design system, tema, animasyon, a11y |
| [`android-navigation`](android-navigation) | Route tanımı, nav graph, deep link, back stack |
| [`android-auth-credentials`](android-auth-credentials) | Giriş, passkey, biyometrik kilit, oturum |
| [`android-notifications`](android-notifications) | FCM, bildirim izni, kanallar, teslimat |
| [`android-media-camera`](android-media-camera) | CameraX, Media3, Photo Picker, görüntü yükleme |
| [`mobile-analytics`](mobile-analytics) | Event tracking, taksonomi, sağlayıcı soyutlaması |
| [`on-device-ai`](on-device-ai) | ML Kit, Gemini Nano, özel model, hibrit cihaz-bulut |
| [`feature-flags`](feature-flags) | Flag türleri, kill switch, A/B testi, kademeli açılış |

### Kalite (üretileni doğrular)
| Skill | Ne zaman |
|---|---|
| [`android-testing`](android-testing) | Unit/integration/UI test, Turbine, fake vs mock |
| [`android-performance`](android-performance) | Startup, jank, bellek, APK, baseline profile, ANR |
| [`android-security`](android-security) | Keystore, pinning, token, biyometrik, izinler |
| [`mobile-observability`](mobile-observability) | Crash/non-fatal, trace, sürüm sağlığı, alarm |
| [`mobile-code-review`](mobile-code-review) | PR incelemesi, self-review |

### Platform
| Skill | Ne zaman |
|---|---|
| [`android-native-ndk`](android-native-ndk) | JNI, CMake, C/C++, native crash |
| [`kmp-shared`](kmp-shared) | Kotlin Multiplatform, iOS ile kod paylaşımı |
| [`ios-swift-architect`](ios-swift-architect) | SwiftUI, Swift Concurrency, SPM |
| [`android-adaptive-formfactors`](android-adaptive-formfactors) | Tablet/foldable, widget, Wear/TV kararı |
| [`android-platform-upgrade`](android-platform-upgrade) | targetSdk yükseltme, platform davranış değişiklikleri |
| [`xml-compose-migration`](xml-compose-migration) | XML/Fragment → Compose kademeli geçiş |

### Süreç
| Skill | Ne zaman |
|---|---|
| [`android-gradle-build`](android-gradle-build) | Version catalog, convention plugin, build süresi |
| [`git-workflow`](git-workflow) | Branch, commit, PR, rebase, conflict |
| [`mobile-ci-release`](mobile-ci-release) | GitHub Actions / Jenkins, imzalama, store yayını |

### Dokümantasyon
| Skill | Ne zaman |
|---|---|
| [`docs-guide`](docs-guide) | Bir bilgi nereye yazılır: skill mi, docs mı, yorum mu |
| [`adr`](adr) | Geri dönüşü pahalı mimari kararın kaydı |
| [`design-doc`](design-doc) | Kodlama öncesi teknik tasarım |
| [`change-docs`](change-docs) | feature-doc / fix-doc / refactor-doc / release notes |
| [`kdoc-standards`](kdoc-standards) | KDoc, kod yorumu, TODO disiplini |

---

## Yönlendirme Haritası

`delivery-pipeline` bu tabloya göre alt skill'leri çağırır:

| İşin niteliği | Sırasıyla yüklenecekler |
|---|---|
| Yeni feature (tam yığın) | `feature-scaffold` → `android-data-layer` → `android-compose-ui` → `android-navigation` → `android-testing` |
| Sadece ekran değişikliği | `android-compose-ui` → `android-testing` |
| Veri/cache işi | `android-data-layer` → `android-testing` |
| Bug fix | `mobile-code-review` (kök neden) → ilgili katman skill'i → `android-testing` → `change-docs` |
| Performans şikâyeti | `android-performance` → ilgili katman skill'i → `android-performance` (doğrulama) |
| Güvenlik bulgusu | `android-security` → `android-testing` |
| Giriş / oturum akışı | `android-auth-credentials` → `android-security` → `android-testing` |
| Push bildirim kurulumu | `android-notifications` → `android-navigation` (deep link) → `android-testing` |
| Kamera / medya özelliği | `android-media-camera` → `android-performance` → `android-testing` |
| AI özelliği | `on-device-ai` → `android-performance` → `mobile-observability` |
| Tablet / foldable uyumu | `android-adaptive-formfactors` → `android-navigation` → `android-testing` |
| targetSdk yükseltme | `android-platform-upgrade` → `android-testing` → `mobile-ci-release` |
| Riskli değişikliği kademeli açma | `feature-flags` → `mobile-observability` → `mobile-ci-release` |
| Üretimde crash artışı | `mobile-observability` → `feature-flags` (kill switch) → ilgili katman → `change-docs` |
| XML ekranı yenileme | `xml-compose-migration` → `android-compose-ui` → `android-testing` |
| iOS'a açılma | `kmp-shared` → `ios-swift-architect` → `mobile-ci-release` |
| Mimari karar | `adr` (büyükse önce `design-doc`) |
| Sürüm çıkma | `mobile-code-review` → `android-performance` → `android-security` → `mobile-ci-release` → `change-docs` |

## Sınır Kuralları

Sık karışan ayrımlar:

| Karışan | Ayrım |
|---|---|
| `android-gradle-build` vs `android-performance` | **Build** süresi vs **runtime** süresi |
| `android-architect` vs `feature-scaffold` | Karar/sınır tasarımı vs dosya iskeleti üretimi |
| `design-doc` vs `adr` | Kodlamadan önce **nasıl** vs karar anında **neden** |
| `android-compose-ui` vs `xml-compose-migration` | Sıfırdan yeni ekran vs mevcut ekranın taşınması |
| `docs-guide` vs diğer doküman skill'leri | Nereye yazılacağı kararı vs dokümanın kendisi |
| `mobile-code-review` vs `android-testing` | Var olan kodu incelemek vs test yazmak |
| `android-navigation` vs `android-architect` | Route/geçiş mekaniği vs katman ve modül kararı |
| `android-auth-credentials` vs `android-security` | Giriş **akışı** vs token saklama/pinning |
| `android-adaptive-formfactors` vs `android-compose-ui` | Pencere boyutuna göre **düzen** vs bileşen/tema |
| `android-platform-upgrade` vs `android-performance` | Yeni sürüm **uyumu** vs hız/kaynak |
| `mobile-observability` vs `android-performance` | Üretimde **ne oluyor** vs lokalde **neden yavaş** |
| `feature-flags` vs `mobile-ci-release` | Uygulama içi açma/kapama vs mağaza staged rollout |
| `on-device-ai` vs `android-media-camera` | Model/inference vs kamera-medya boru hattı |
| `mobile-analytics` vs `mobile-observability` | Kullanıcı **davranışı** ölçümü vs sistem **sağlığı** (crash/hata/gecikme) |

## Yeni Skill Ekleme

```bash
mkdir -p skills/<isim>
$EDITOR skills/<isim>/SKILL.md      # frontmatter: name + description
../scripts/validate.sh
```

Sonra güncellemeyi unutma: bu dosyadaki indeks, kök `README.md` kataloğu,
`templates/CLAUDE.md` skill tablosu. `scripts/validate.sh` bu üçünün senkron
olduğunu kontrol eder.

Detaylı kurallar: [`../docs/AUTHORING.md`](../docs/AUTHORING.md)
