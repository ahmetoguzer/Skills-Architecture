# Skills Mimarisi

Bu doküman, koleksiyondaki skill'lerin **nasıl bölündüğünü**, birbirine nasıl bağlandığını
ve bir isteğin hangi yoldan ilerlediğini anlatır.

---

## 1. Tasarım Prensipleri

### P1 — Talep anında yükleme (progressive disclosure)

Skill'ler her sohbette değil, **ilgili istek geldiğinde** yüklenir. Bu yüzden:
- `SKILL.md` odaklı ve kısa tutulur (hedef: < 500 satır)
- Derin içerik `references/*.md` altına konur, gerektiğinde okunur
- Giriş dosyası (`CLAUDE.md`) yalın kalır; derinliği skill'lere devreder

### P2 — Tek sorumluluk

Bir skill tek bir uzmanlık alanını kapsar. "Android'in her şeyi" tek skill olursa
tetikleme belirsizleşir ve bağlamın çoğu ilgisiz bilgiyle dolar.

### P3 — Karar + kod + doğrulama

Her skill üç şeyi birlikte verir:
1. **Karar rehberi** — hangi durumda hangi yaklaşım, tradeoff'lar
2. **Kod şablonu** — kopyalanabilir, derlenebilir örnek
3. **Checklist** — çıktının doğrulanabileceği somut maddeler

Sadece kod veren skill "kütüphane"dir, sadece prensip veren skill "blog yazısı".

### P4 — Açık devretme

Skill'ler sınırlarını bilir ve komşusuna yönlendirir. Devretme kuralı `description`
alanında **açıkça yazılır**, örtük bırakılmaz.

### P5 — İki dilli tetikleme

`description` hem Türkçe hem İngilizce tetikleyici ifade içerir. Açıklamalar Türkçe,
kod ve tanımlayıcılar İngilizce.

### P6 — Süreç de bir skill'dir

En kritik prensip. Skill'ler yalnızca "nasıl yazılır"ı değil, **"nasıl teslim edilir"i**
de kodlar. `delivery-pipeline` diğerlerini sırayla çağıran orkestratördür:
plan onayı, faz disiplini, test kanıtı, self-review, commit/push onayları.

Süreç kodlanmazsa her sohbette yeniden pazarlık edilir; kimi zaman plan yapılır,
kimi zaman doğrudan koda girilir. Tutarlılık burada kaybolur.

---

## 2. Katman Haritası

```
                    ┌──────────────────────────┐
                    │    delivery-pipeline     │  ← orkestratör / varsayılan giriş
                    │  netleştir → yönlendir → │
                    │  planla → fazlar → test  │
                    │  → doküman → review →    │
                    │  commit → push/PR        │
                    └────────────┬─────────────┘
                                 │ yönlendirir
     ┌───────────────┬───────────┼───────────────┬──────────────────┐
     ▼               ▼           ▼               ▼                  ▼
┌──────────┐  ┌────────────┐ ┌────────┐  ┌─────────────┐  ┌────────────────┐
│ ÇEKİRDEK │  │  KALİTE    │ │PLATFORM│  │   SÜREÇ     │  │ DOKÜMANTASYON  │
├──────────┤  ├────────────┤ ├────────┤  ├─────────────┤  ├────────────────┤
│architect │  │testing     │ │ndk     │  │gradle-build │  │docs-guide      │
│feature-  │  │performance │ │kmp     │  │git-workflow │  │adr             │
│ scaffold │  │security    │ │ios     │  │ci-release   │  │design-doc      │
│data-layer│  │code-review │ │xml→cmp │  │             │  │change-docs     │
│compose-ui│  │            │ │        │  │             │  │kdoc-standards  │
│analytics │  │            │ │        │  │             │  │                │
└──────────┘  └────────────┘ └────────┘  └─────────────┘  └────────────────┘
```

| Grup | Rolü |
|---|---|
| **Orkestrasyon** | İşi uçtan uca yürütür, diğerlerini çağırır |
| **Çekirdek** | Kod üretir |
| **Kalite** | Üretilen kodu doğrular |
| **Platform** | Teknoloji sınırlarını yönetir |
| **Süreç** | Build, sürüm kontrolü, teslimat |
| **Dokümantasyon** | Kurumsal hafızayı korur |

---

## 3. Tipik Akışlar

### Yeni feature ekleme

```
Kullanıcı: "Sipariş geçmişi ekranı ekle, offline da çalışsın"

delivery-pipeline devreye girer:
  Faz 0  netleştir     → "Sayfalama gerekli mi? Yeni modül mü?"
  Faz 1  yönlendir     → feature-scaffold + data-layer + compose-ui + testing
  Faz 2  planla        → modüller, fazlar, varsayımlar, kapsam dışı, risk → ONAY
  Faz 3  branch        → git-workflow: feature/order-history ← develop
  Faz 4  kodla         → feature-scaffold → data-layer → compose-ui (faz faz)
  Faz 5  test          → android-testing, gerçek çıktı raporlanır
  Faz 6  doküman       → docs-guide → change-docs (feature-doc)
  Faz 7  self-review   → mobile-code-review kendi diff'ine
  Faz 8  commit        → ONAY, faz başına atomik
  Faz 9  push/PR       → AYRI ONAY
```

### Performans şikâyeti

```
"Liste kaydırırken takılıyor"

1. android-performance → teşhis aracı ve metrik (FrameTimingMetric)
2. android-compose-ui  → recomposition/stability düzeltmeleri
3. android-performance → Macrobenchmark ile önce/sonra ölçümü
4. change-docs         → ölçüm sayılarıyla fix kaydı
```

### Bug fix

```
"Boş sepette checkout çöküyor"

1. mobile-code-review  → kök nedeni bul (belirti değil)
2. ilgili katman skill'i → düzeltme
3. android-testing     → hatayı yakalayan test önce yazılır
4. change-docs         → fix-doc: kök neden + tekrar önleme maddeleri
```

### Platform genişletme

```
"Bunu iOS'a da taşıyalım"

1. design-doc          → kapsam ve fazlar (büyük iş)
2. kmp-shared          → ne paylaşılır/paylaşılmaz, kademeli plan
3. adr                 → KMP'ye geçiş kararının kaydı
4. ios-swift-architect → SwiftUI katmanı
5. mobile-ci-release   → macOS runner, XCFramework, TestFlight
```

### Yayın

```
"Sürüm çıkacağız"

1. mobile-code-review  → son tarama
2. android-performance → baseline profile, Play Vitals eşikleri
3. android-security    → sır sızıntısı, pinning, Data Safety
4. mobile-ci-release   → imzalama, staged rollout, izleme
5. change-docs         → release notes (kullanıcı + teknik ayrı)
```

---

## 4. Skill Sınırları

| Soru | Doğru skill | Yanlış skill |
|---|---|---|
| "ViewModel nereye koyayım?" | architect | compose-ui |
| "Yeni feature iskeleti kur" | feature-scaffold | architect |
| "Bu composable neden recompose oluyor?" | compose-ui → performance | architect |
| "Cache nasıl invalid edilir?" | data-layer | architect |
| "Flow'u nasıl test ederim?" | testing | architect |
| "Token nerede saklanır?" | security | data-layer |
| "Gradle build 6 dakika sürüyor" | gradle-build | performance |
| "Uygulama açılışı 2 saniye" | performance | gradle-build |
| "C++ kütüphanesi entegre edeceğim" | native-ndk | architect |
| "iOS ile kod paylaşalım" | kmp-shared | ios-swift-architect |
| "SwiftUI ekranı nasıl yazılır?" | ios-swift-architect | kmp-shared |
| "Eski Fragment'ı yenile" | xml-compose-migration | compose-ui |
| "Bu event'i nereden göndereyim?" | mobile-analytics | compose-ui |
| "Bu kararı yazalım" | adr | design-doc |
| "Nasıl yapacağımızı planlayalım" | design-doc | adr |
| "Bu bilgiyi nereye yazayım?" | docs-guide | ilgili doküman skill'i |

Sık karışan iki ayrım:
- **build süresi** → gradle-build, **runtime süresi** → performance
- **neden** (karar anı) → adr, **nasıl** (kodlama öncesi) → design-doc

---

## 5. Projeye Bağlanma

Skill'ler tek başına çalışmaz; projenin giriş dosyası onlara yönlendirmelidir.

```
<proje>/
├── CLAUDE.md                        ← yalın giriş (templates/CLAUDE.md'den)
│   ├─ Bu ne (1 paragraf)
│   ├─ Varsayılan akış → delivery-pipeline
│   ├─ Skill tablosu (hangi durumda hangisi)
│   ├─ Non-negotiables (6-8 tek satırlık doğrulanabilir kural)
│   └─ Build hızlı referans
├── AGENTS.md                        ← genel AI ajan rehberi
├── .github/copilot-instructions.md  ← tam takım standardı
├── .claude/skills/                  ← bu koleksiyondan symlink'ler
└── docs/
    ├── README.md
    ├── architecture/SKILLS_ARCHITECTURE.md
    ├── architecture/adr/
    ├── design/  testing/  ci-cd/  performance/  security/
    └── changes/features|fixes|refactors/
```

**Çok tüketicili standart:** Aynı kuralı hem `CLAUDE.md`'ye hem skill'e yazma.
`CLAUDE.md` yönlendirir, skill anlatır. Kopyalanan kural er ya da geç çelişir.

**Modül-local override:** Büyük monorepo'da bir modülün kökündeki talimat dosyası
o paket için üsttekini ezer. Override yalnızca **farkı** yazar ve genel standarda
uyum sağlanınca **silinir** — kalıcı istisna istisna değildir.

---

## 6. Dosya Yapısı

```
Skills-Architecture/
├── README.md                  ← katalog ve kurulum
├── docs/
│   ├── ARCHITECTURE.md        ← bu dosya
│   └── AUTHORING.md           ← yeni skill yazma rehberi
├── templates/
│   └── CLAUDE.md              ← projeye kopyalanacak yalın giriş dosyası
├── scripts/
│   ├── install.sh             ← ~/.claude/skills veya <proje>/.claude/skills
│   └── validate.sh            ← frontmatter, referans ve katalog senkron kontrolü
├── skills/
│   ├── README.md              ← in-tree indeks + yönlendirme haritası
│   └── <skill-adı>/
│       ├── SKILL.md
│       └── references/        ← opsiyonel derin dokümanlar
└── .github/workflows/validate.yml
```

Skill listesi **üç yerde** görünür: kök `README.md`, `skills/README.md`,
`templates/CLAUDE.md`. `validate.sh` üçünün senkron olduğunu kontrol eder —
kataloğa yazılmayan skill pratikte görünmezdir.

---

## 7. Versiyonlama ve Bakım

- Skill içerikleri **sürüm bağımlıdır**: AGP, Kotlin, Compose hızla değişir.
  `android-gradle-build` içindeki version catalog'u çeyrek dönemde gözden geçir.
- Bir pattern deprecate olduğunda skill'den **sil**, "eskiden şöyleydi" bölümü ekleme —
  bağlamı şişirir ve modeli eski yaklaşıma yönlendirir.
- Yeni Android sürümünde etkilenenler: `performance` (yeni kısıtlar),
  `security` (izin modeli), `native-ndk` (ABI/page size), `mobile-ci-release` (targetSdk).
- Süreç skill'leri (`delivery-pipeline`, `git-workflow`) daha yavaş eskir ama
  ekip alışkanlığı değiştiğinde güncellenmeli — kâğıt üzerindeki süreç uygulanmıyorsa
  ya süreci düzelt ya belgeyi.
