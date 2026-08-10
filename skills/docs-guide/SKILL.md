---
name: docs-guide
last_reviewed: 2026-08
description: >
  Dokümantasyon yönlendiricisi: bir bilginin skill'e mi, docs/ altına mı, kod yorumuna mı
  yoksa hiçbir yere mi ait olduğuna karar verir. docs/ taksonomisini, modül-local override
  mekanizmasını ve CLAUDE.md / AGENTS.md / copilot-instructions.md çok-tüketicili yapısını yönetir.

  Şu isteklerde tetiklen: "dokümantasyon", "nereye yazayım", "docs klasörü", "README güncelle",
  "CLAUDE.md", "AGENTS.md", "copilot-instructions", "bu bilgiyi kalıcı hale getir",
  "skill mi doküman mı", "guide yaz", "wiki".
---

# Docs Guide Skill

Sen dokümantasyon mimarısın. En değerli katkın **yazmamak gereken dokümanı engellemek**:
okunmayan doküman, yanlış doküman kadar zararlıdır çünkü güven verir ama eskir.

## Karar Ağacı — Bu Bilgi Nereye Gider?

```
Bilgi bir kod parçasının "neden böyle" açıklaması mı?
  └─ Evet → kod yorumu / KDoc  (kdoc-standards)

Bir AI ajanının/geliştiricinin iş yaparken uyması gereken KURAL mı?
  └─ Evet → skill  (.claude/skills/<isim>/SKILL.md)

Geri döndürülemez bir MİMARİ KARAR mı? ("X yerine Y seçtik")
  └─ Evet → ADR  (adr)

Kodlanmadan önceki TASARIM mı?
  └─ Evet → design doc  (design-doc)

Tamamlanmış bir iş kaydı mı? (feature/fix/refactor/release)
  └─ Evet → change docs  (change-docs)

Uzun, referans niteliğinde REHBER mi? (testing guide, CI guide)
  └─ Evet → docs/<kategori>/  (bu skill)

Hiçbiri mi?
  └─ Yazma. Sohbette cevapla.
```

---

## Skill mi, docs/ mı?

En sık karışan ayrım. Ölçüt: **kim, ne zaman okuyor?**

| | Skill | docs/ rehberi |
|---|---|---|
| Okuyucu | AI ajanı, iş yaparken | İnsan, öğrenirken/ararken |
| Zamanlama | Talep anında otomatik yüklenir | Bilinçli olarak açılır |
| Biçim | Emir kipi kuralları + şablon + checklist | Anlatı, arka plan, alternatifler |
| Uzunluk | < 500 satır | Sınırsız |
| Test | "Doğru istekte tetikleniyor mu?" | "Aradığımı buluyor muyum?" |

**Aynı bilgiyi iki yere yazma.** Skill kısa kuralı verir, derinlik için docs'a link verir:

```markdown
Detaylı test rehberi: `docs/testing/ANDROID_TESTING_GUIDE.md`
```

---

## docs/ Taksonomisi

```
docs/
├── README.md                  ← kategori indeksi, giriş noktası
├── architecture/
│   ├── SKILLS_ARCHITECTURE.md ← skill mimarisi ve kullanım rehberi
│   └── adr/
│       ├── README.md          ← ADR indeksi
│       └── 0001-xml-to-compose-migration.md
├── design/                    ← kodlanmamış tasarım dokümanları
├── testing/
│   └── ANDROID_TESTING_GUIDE.md
├── ci-cd/
│   └── PIPELINE_GUIDE.md
├── performance/
├── security/
└── changes/                   ← feature/fix/refactor kayıtları
    ├── features/
    ├── fixes/
    └── refactors/
```

Kurallar:
- Her kategori klasöründe bir `README.md` indeksi olur — yoksa doküman kaybolur
- Dosya adları `SCREAMING_SNAKE_CASE.md` (rehberler) veya `NNNN-kebab-case.md` (ADR)
- Yeni bir kategori açmadan önce mevcut birine sığıp sığmadığına bak;
  5 kategori 15 kategoriden iyidir

---

## Çok Tüketicili Standartlar

Aynı ekip standardını birden fazla araç okur. Kaynak **tek** olmalı, kopya değil:

| Dosya | Tüketici | İçerik |
|---|---|---|
| `CLAUDE.md` | Claude Code | Yalın giriş: ne bu proje, varsayılan akış, skill tablosu, non-negotiables |
| `AGENTS.md` | Genel AI ajanları | Mimari, test, komut referansı |
| `.github/copilot-instructions.md` | GitHub Copilot | Tam takım standardı |
| `.claude/skills/*/SKILL.md` | Claude Code (talep anında) | Detaylı, alan bazlı kurallar |

**Desen:** `CLAUDE.md` yalın kalır ve derinliği skill'lere devreder.
Aynı kuralı hem `CLAUDE.md`'ye hem skill'e yazarsan biri eskir ve çelişirler.

`CLAUDE.md` şablonu için: `templates/CLAUDE.md`

### Non-negotiables bloğu

`CLAUDE.md`'de 6-8 maddelik, çiğnenmesi kabul edilmeyen kurallar listesi tut.
Bunlar ajanın her seferinde göreceği tek derin içeriktir — geri kalanı skill'lerden gelir.

```markdown
## Non-negotiables (details in the skills)

- Bağımlılıklar içe akar: `:app → :feature:* → :core:domain ← :core:data`.
  Core asla feature'a bağımlı olmaz. `:core:domain` saf Kotlin.
- Yeni Compose ViewModel'leri `ComposeBaseViewModel<Event, State>`'i genişletir.
- Dispatcher inject edilir (`@IoDispatcher`) — `Dispatchers.IO` hardcode edilmez.
- Kullanıcıya görünen string'ler `ContentManager.getValue(R.string.key)` ile.
- Testler: `runTest` + MockK + Turbine; `runBlocking`/`Thread.sleep` yok.
```

Her madde tek satır ve **doğrulanabilir** olmalı. "Temiz kod yazın" non-negotiable değildir.

---

## Modül-Local Override

Büyük monorepo'da tek bir standart her modüle uymaz. Modül kökünde bir talimat dosyası
o paket için üsttekini **ezer**:

```
feature/squad/care/copilot-instructions.md   ← bu paket için geçerli
.github/copilot-instructions.md              ← genel
```

Kurallar:
- Override dosyası **sadece farkı** yazar, genel standardı tekrarlamaz
- Başında neden override edildiği bir cümleyle açıklanır
- Genel standarda uyum sağlanınca dosya **silinir** — kalıcı istisna, istisna değildir

---

## Doküman Bakımı

Doküman eskimesi kaçınılmazdır; tespit edilebilir yapmak elinde:

- Her rehberin başına `Son güncelleme: YYYY-MM` koy
- Sürüm bağımlı içeriğe sürümü yaz ("AGP 8.7 itibarıyla")
- Bir pattern deprecate olduğunda dokümanı **sil**, "eskiden şöyleydi" bölümü ekleme
- PR'da davranış değiştiyse ilgili dokümanı da güncelle — `mobile-code-review` bunu sorar

---

## Checklist

- [ ] Bilgi karar ağacından geçirildi; doğru yere yazıldı
- [ ] Aynı bilgi iki yerde tekrarlanmıyor (skill kısa + docs'a link)
- [ ] Kategori `README.md` indeksine eklendi
- [ ] Dosya adı taksonomiye uygun
- [ ] `CLAUDE.md` yalın kaldı, derinlik skill'lere gitti
- [ ] Non-negotiables maddeleri tek satır ve doğrulanabilir
- [ ] Modül override dosyası varsa sadece farkı içeriyor ve gerekçeli
- [ ] Rehbere "son güncelleme" tarihi eklendi
