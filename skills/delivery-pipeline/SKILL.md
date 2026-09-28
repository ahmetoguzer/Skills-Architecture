---
name: delivery-pipeline
last_reviewed: 2026-08
description: >
  Önemsiz olmayan her değişikliği uçtan uca yöneten orkestratör skill: yeni feature, bug fix
  veya refactor. Akış: netleştir → yönlendir → planla → fazlara böl → kodla → test et →
  dokümante et → self-review → commit → push/PR.

  Şu isteklerde tetiklen: "feature ekle", "şunu yap", "bug fix", "refactor et", "şu ekranı
  değiştir", "implement et", "geliştir", "bunu düzelt" — yani kod değişikliği isteyen her şey.
  ATLA: soru, açıklama, tek satırlık typo düzeltmesi — bunlarda doğrudan cevap ver.
---

# Delivery Pipeline Skill

Sen teslimat orkestratörüsün. Kod yazmadan önce **doğru skill'i yükler**, plan onayı alır,
işi fazlara böler ve her fazı kapatmadan bir sonrakine geçmezsin.

Bu skill diğerlerinin yerine geçmez — onları **sırayla çağırır**.

## Ne Zaman Bu Pipeline?

| Durum | Pipeline |
|---|---|
| Yeni feature | **Evet** — tam akış |
| Bug fix (önemsiz değilse) | **Evet** — plan kısa olabilir |
| Refactor | **Evet** — özellikle "önce/sonra" dokümanı için |
| "Bu nasıl çalışıyor?" | Hayır — cevapla |
| Typo, tek satır, log ekleme | Hayır — yap ve geç |

Şüphedeysen pipeline'ı çalıştır ama fazları kısa tut. Ağır süreç, süreçsizlikten iyidir;
ama gereksiz süreç insanları süreçten kaçırır.

---

## Faz 0 — Netleştir

**Sadece kullanıcının karar vermesi gereken şeyleri sor.** Kodda cevabı olan hiçbir şeyi sorma.

İyi sorular:
- "Offline'da bu ekran ne göstersin — son bilinen veri mi, boş state mi?"
- "Yeni modül mü açalım, mevcut `:feature:care` içine mi girsin?"
- "Bu değişiklik mevcut kullanıcıların verisini etkiliyor, migration gerekiyor mu?"

Kötü sorular:
- "Hangi mimariyi kullanıyorsunuz?" → koda bak
- "Hilt mi Koin mi?" → `libs.versions.toml`'a bak
- "Devam edeyim mi?" → planı sun, onayı orada al

En fazla 3-4 soru. Fazlası kullanıcıyı yorar; belirsiz kalanı varsayım olarak yaz ve planda belirt.

---

## Faz 1 — Yönlendir (routing)

İşin kapsamına göre hangi skill'lerin yükleneceğine karar ver ve bunu **açıkça söyle**:

| İşin niteliği | Yüklenecek skill'ler |
|---|---|
| Yeni modül / katman sınırı sorusu | `android-architect` |
| Domain + data + UI kapsayan yeni feature | `feature-scaffold` → `android-data-layer` → `android-compose-ui` |
| Sadece ekran değişikliği | `android-compose-ui` |
| Ekranlar arası geçiş, deep link | `android-navigation` |
| Login / oturum / passkey | `android-auth-credentials` |
| Push bildirim | `android-notifications` |
| Kamera / video / medya | `android-media-camera` |
| Tablet, foldable, widget | `android-adaptive-formfactors` |
| AI / ML özelliği | `on-device-ai` |
| Repository / UseCase / DI | `android-data-layer` |
| Test yazımı veya düzeltmesi | `android-testing` |
| Yavaşlık / jank / bellek | `android-performance` |
| Üretimde hata, crash artışı | `mobile-observability` |
| Kademeli açılış, deney, kill switch | `feature-flags` |
| targetSdk / platform yükseltmesi | `android-platform-upgrade` |
| Token, pinning, izin | `android-security` |
| Gradle, modül tanımı, bağımlılık | `android-gradle-build` |
| C/C++ dokunuşu | `android-native-ndk` |
| iOS ile paylaşım | `kmp-shared`, `ios-swift-architect` |
| XML ekranı Compose'a taşıma | `xml-compose-migration` |
| Branch/commit/PR | `git-workflow` |
| Dokümantasyon | `docs-guide` → `adr` / `design-doc` / `change-docs` |

Kullanıcıya tek satırla bildir: *"Bu iş için `feature-scaffold` + `android-data-layer` +
`android-testing` kullanacağım."* Böylece yanlış yönlendirmeyi baştan düzeltebilir.

---

## Faz 2 — Planla ve Onay Al

Plan şunları içerir:

```markdown
## Plan: Sipariş geçmişi ekranı

**Kapsam:** Kullanıcı geçmiş siparişlerini offline erişilebilir şekilde görür.

**Dokunulacak modüller**
- :core:domain  → Order modeli, OrderRepository arayüzü, GetOrdersUseCase
- :core:data    → OrderRepositoryImpl, OrderDao, OrderApi, mapper'lar
- :feature:orders → OrderListScreen, OrderListViewModel

**Fazlar**
1. Domain katmanı + testleri
2. Data katmanı (Room + API + sync) + testleri
3. UI katmanı (Compose + ViewModel) + testleri
4. Dokümantasyon (feature-doc) ve self-review

**Varsayımlar**
- Sayfalama gerekmiyor (kullanıcı başına < 100 sipariş bekleniyor)
- Mevcut auth interceptor yeterli, yeni endpoint token gerektirmiyor

**Kapsam dışı**
- Sipariş iptali (ayrı iş)

**Risk**
- Room şema değişikliği → migration + migration testi gerekli
```

**Onay almadan kod yazma.** Kullanıcı planı gördükten sonra kapsamı daraltabilir —
bu, yazılmış kodu silmekten ucuzdur.

---

## Faz 3 — Branch Aç

**Kod yazmadan önce** branch'i aç. Ana geliştirme dalında (`develop`/`main`) asla geliştirme yapma.

```bash
git fetch origin develop
git checkout -b feature/order-history origin/develop
```

Detay ve isimlendirme kuralları: `git-workflow` skill'i.

---

## Faz 4 — Fazları Sırayla Uygula

Her faz için döngü:

```
kod yaz → derle → o fazın testlerini yaz → testleri çalıştır → yeşil mi? → sonraki faz
```

Kurallar:
- **Faz yarım bırakılmaz.** Faz 2'ye geçmeden Faz 1 derleniyor ve testleri geçiyor olmalı.
- Bir fazda beklenmedik bir engel çıkarsa **dur ve bildir** — sessizce kapsam daraltma.
- Çok fazlı işlerde her fazın sonunda **atomik commit** öner (`git-workflow`).

Faz sonunda kısa durum ver:
> Faz 2/4 tamam — data katmanı: `OrderDao`, `OrderRepositoryImpl`, migration 4→5.
> 11 test yeşil. Sırada UI katmanı.

---

## Faz 5 — Test

`android-testing` skill'ini yükle. Minimum:

- Her yeni UseCase → happy path + en az bir hata yolu
- Her yeni ViewModel → loading / success / error state geçişleri
- Her yeni DAO → insert/observe + varsa migration testi
- Kritik akış değiştiyse → UI testi

Testleri **çalıştır ve çıktıyı raporla.** "Testler geçmeli" değil, "17 test, hepsi yeşil".
Geçmiyorsa geçmediğini söyle — gizleme.

---

## Faz 6 — Dokümantasyon

`docs-guide` ile hangi dokümanın gerektiğine karar ver:

| Değişiklik | Doküman |
|---|---|
| Mimari karar verildi (kütüphane seçimi, pattern değişimi) | `adr` |
| Büyük feature, kodlamadan önce | `design-doc` |
| Feature tamamlandı | `change-docs` → feature-doc |
| Önemsiz olmayan bug fix | `change-docs` → fix-doc (kök neden + tekrar önleme) |
| Önemsiz olmayan refactor | `change-docs` → refactor-doc (önce/sonra + migration) |
| Public API eklendi | `kdoc-standards` |

Küçük değişiklikte doküman zorlamak süreci boğar; mimari karar dokümante edilmezse
altı ay sonra kimse nedenini hatırlamaz. Dengeyi `docs-guide` kurar.

---

## Faz 7 — Self-Review

Commit'ten **önce** `mobile-code-review` skill'ini kendi diff'ine uygula:

```bash
git diff --stat
git diff
```

Kendi kodunu incelerken en sık kaçırılanlar:
- Debug log'ları / yorum satırına alınmış kod kalmış
- Hata yolu yazılmamış (sadece happy path)
- Hardcoded string / dispatcher
- Katman ihlali (ViewModel'de DTO import'u)
- Kapsam dışına taşma (plan dışı dosya değişmiş)

`git status`'ta plan dışı bir dosya varsa açıkla veya geri al.

---

## Faz 8 — Commit

**Commit öncesi onay al.** Çok fazlı işte faz başına atomik commit öner.

Mesaj biçimi ve kuralları `git-workflow` skill'inde.

---

## Faz 9 — Push / PR

**Push ve PR açmadan önce ayrıca onay al.** Push, dışarıya açılan bir aksiyondur;
commit onayı push onayı anlamına gelmez.

PR açıklaması plan dokümanından türer: kapsam, fazlar, test durumu, kapsam dışı, risk.

---

## Faz 10 — Retrospektif (skill geri beslemesi)

İş kapanırken tek soru: **yüklenen skill'lerden herhangi biri yanlış, eksik veya
çelişkili miydi?** Yanlış tetiklenen, hatalı bilgi veren veya durumu hiç kapsamayan
bir skill varsa claude-code-mobile-skills reposunda `skill-bug` şablonuyla issue aç
(yanlış tetiklemeyse vakayı `evals/routing.yaml`'a eklet).

Bu 30 saniyelik adım, koleksiyonun gerçek kullanımdan öğrenmesini sağlayan tek
mekanizmadır — atlanırsa skill'ler raf dokümanına dönüşür. Sorun yoksa hiçbir şey
yazma, sessizce bitir.

---

## Pipeline Checklist

- [ ] Belirsizlikler netleştirildi (en fazla 3-4 soru, kodda cevabı olan sorulmadı)
- [ ] Hangi skill'lerin kullanılacağı kullanıcıya bildirildi
- [ ] Plan sunuldu ve onaylandı
- [ ] Branch `develop`/`main`'den açıldı, üzerinde geliştirme yapılmadı
- [ ] Her faz derleniyor ve testleri yeşil
- [ ] Test çıktısı gerçek sayılarla raporlandı
- [ ] Gerekli doküman yazıldı (veya gerekmediği belirtildi)
- [ ] Self-review yapıldı, plan dışı değişiklik yok
- [ ] Commit onayı alındı
- [ ] Push/PR onayı ayrıca alındı
- [ ] Retrospektif: skill hatası varsa issue açıldı, yoksa sessizce geçildi
