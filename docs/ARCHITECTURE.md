# Skills Mimarisi

Bu doküman, koleksiyondaki skill'lerin **nasıl bölündüğünü**, birbirine nasıl bağlandığını
ve bir isteğin hangi yoldan ilerlediğini anlatır.

---

## 1. Tasarım Prensipleri

### P1 — Talep anında yükleme (progressive disclosure)

Skill'ler her sohbette değil, **ilgili istek geldiğinde** yüklenir. Bu yüzden:
- `SKILL.md` odaklı ve kısa tutulur (hedef: < 500 satır)
- Derin içerik `references/*.md` altına konur, gerektiğinde okunur

### P2 — Tek sorumluluk

Bir skill tek bir uzmanlık alanını kapsar. "Android'in her şeyi" tek skill olursa:
- Tetikleme belirsizleşir (her şeye tetiklenir)
- Bağlamın çoğu ilgisiz bilgiyle dolar

### P3 — Karar + kod + doğrulama

Her skill üç şeyi birlikte verir:
1. **Karar rehberi** — hangi durumda hangi yaklaşım, tradeoff'lar
2. **Kod şablonu** — kopyalanabilir, derlenebilir örnek
3. **Checklist** — çıktının doğrulanabileceği somut maddeler

Sadece kod veren skill "kütüphane"dir, sadece prensip veren skill "blog yazısı".
İkisi birlikte olduğunda kullanışlı olur.

### P4 — Açık devretme

Skill'ler sınırlarını bilir ve komşusuna yönlendirir:
`android-compose-ui` genel mimari sorusunu `android-architect`'e,
`ios-swift-architect` kod paylaşımı sorusunu `kmp-shared`'a devreder.

### P5 — İki dilli tetikleme

`description` alanı hem Türkçe hem İngilizce tetikleyici ifade içerir
("uygulama yavaş" ve "app is slow" aynı skill'e gitmeli). Açıklamalar Türkçe,
kod ve tanımlayıcılar İngilizce.

---

## 2. Katman Haritası

```
                        ┌──────────────────────┐
                        │  android-architect   │  ← giriş noktası / mimari otorite
                        │  (Clean Arch, DI,    │
                        │   MVVM/MVI, modül)   │
                        └──────────┬───────────┘
                                   │
        ┌──────────────┬───────────┼───────────┬──────────────┐
        ▼              ▼           ▼           ▼              ▼
┌──────────────┐ ┌───────────┐ ┌───────┐ ┌──────────┐ ┌──────────────┐
│ compose-ui   │ │ data-layer│ │testing│ │performance│ │  security   │
│ (sunum)      │ │ (veri)    │ │(kalite)│ │(kalite)  │ │  (kalite)   │
└──────────────┘ └───────────┘ └───────┘ └──────────┘ └──────────────┘

        ── platform genişlemesi ──          ── süreç ──
┌──────────────┐ ┌───────────┐ ┌────────────────┐   ┌──────────────────┐
│ native-ndk   │ │ kmp-shared│ │ ios-swift-arch │   │ gradle-build     │
│ (C/C++)      │ │ (ortak)   │ │ (iOS)          │   │ mobile-ci-release│
└──────────────┘ └───────────┘ └────────────────┘   │ mobile-code-review│
                                                     └──────────────────┘
```

**Üç grup:**

| Grup | Skill'ler | Rolü |
|---|---|---|
| **Çekirdek** | architect, compose-ui, data-layer | Kod üretir |
| **Kalite** | testing, performance, security, code-review | Üretilen kodu doğrular |
| **Platform & Süreç** | native-ndk, kmp-shared, ios-swift-architect, gradle-build, ci-release | Sınırları ve teslimatı yönetir |

---

## 3. Tipik Akışlar

### Yeni feature ekleme

```
Kullanıcı: "Sipariş geçmişi ekranı ekle, offline da çalışsın"

1. android-architect   → modül yapısı, katmanlar, UseCase/Repository iskeleti
2. android-data-layer  → Room entity + DAO, API, SSOT akışı, sync
3. android-compose-ui  → ekran, state, preview, tema token'ları
4. android-testing     → ViewModel + UseCase + DAO testleri
5. mobile-code-review  → çıktının checklist'e göre son kontrolü
```

### Performans şikâyeti

```
Kullanıcı: "Liste kaydırırken takılıyor"

1. android-performance → teşhis: hangi araç, hangi metrik (FrameTimingMetric)
2. android-compose-ui  → recomposition/stability düzeltmeleri
3. android-performance → Macrobenchmark ile önce/sonra ölçümü
```

### Platform genişletme

```
Kullanıcı: "Bunu iOS'a da taşıyalım"

1. kmp-shared          → ne paylaşılır/paylaşılmaz kararı, kademeli plan
2. android-architect   → domain/data'nın commonMain'e taşınabilirlik kontrolü
3. ios-swift-architect → iOS tarafındaki SwiftUI + Observation katmanı
4. mobile-ci-release   → macOS runner, XCFramework, TestFlight
```

### Yayın

```
Kullanıcı: "Sürüm çıkacağız"

1. mobile-code-review  → değişikliklerin son taraması
2. android-performance → baseline profile güncel mi, Play Vitals eşikleri
3. android-security    → sır sızıntısı, pinning, Data Safety kontrolü
4. mobile-ci-release   → imzalama, staged rollout, izleme planı
```

---

## 4. Skill Sınırları (kim neye bakar)

| Soru | Doğru skill | Yanlış skill |
|---|---|---|
| "ViewModel nereye koyayım?" | architect | compose-ui |
| "Bu composable neden recompose oluyor?" | compose-ui → performance | architect |
| "Cache nasıl invalid edilir?" | data-layer | architect |
| "Flow'u nasıl test ederim?" | testing | architect |
| "Token nerede saklanır?" | security | data-layer |
| "Gradle build 6 dakika sürüyor" | gradle-build | performance |
| "Uygulama açılışı 2 saniye" | performance | gradle-build |
| "C++ kütüphanesi entegre edeceğim" | native-ndk | architect |
| "iOS ile kod paylaşalım" | kmp-shared | ios-swift-architect |
| "SwiftUI ekranı nasıl yazılır?" | ios-swift-architect | kmp-shared |

`gradle-build` vs `performance` ayrımı sık karışır:
**build süresi** → gradle-build, **runtime süresi** → performance.

---

## 5. Dosya Yapısı

```
Skills-Architecture/
├── README.md
├── docs/
│   ├── ARCHITECTURE.md        ← bu dosya
│   └── AUTHORING.md           ← yeni skill yazma rehberi
├── scripts/
│   ├── install.sh             ← ~/.claude/skills veya <proje>/.claude/skills'e kur
│   └── validate.sh            ← frontmatter ve yapı doğrulaması
├── skills/
│   └── <skill-adı>/
│       ├── SKILL.md           ← frontmatter (name, description) + içerik
│       └── references/        ← opsiyonel derin dokümanlar
└── .github/workflows/validate.yml
```

---

## 6. Versiyonlama ve Bakım

- Skill içerikleri **sürüm bağımlıdır**: AGP, Kotlin, Compose sürümleri hızla değişir.
  `android-gradle-build` içindeki version catalog'u çeyrek dönemde bir gözden geçir.
- Bir pattern deprecate olduğunda skill'den **sil**, "eskiden şöyleydi" bölümü ekleme —
  bağlamı şişirir ve modeli eski yaklaşıma yönlendirir.
- Yeni bir Android sürümü çıktığında etkilenen skill'ler:
  `performance` (yeni kısıtlar), `security` (yeni izin modeli), `native-ndk` (ABI/page size),
  `mobile-ci-release` (targetSdk zorunlulukları).
