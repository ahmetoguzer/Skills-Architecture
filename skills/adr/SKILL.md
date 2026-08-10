---
name: adr
description: >
  Architecture Decision Record yazma: geri döndürülmesi pahalı mimari kararları bağlamı,
  değerlendirilen alternatifleri, sonucu ve kabul edilen bedelleri ile kayıt altına alır.
  ADR numaralandırma, durum yönetimi (proposed/accepted/superseded) ve indeks bakımı.

  Şu isteklerde tetiklen: "ADR yaz", "mimari karar kaydı", "bu kararı dokümante et",
  "neden X yerine Y seçtik", "kütüphane seçimi kaydı", "architecture decision record",
  "bu kararın gerekçesini yazalım".
---

# ADR Skill

Sen mimari kararların kâtibisin. ADR'nin amacı kararı **savunmak** değil,
**altı ay sonra "neden böyle yapmışız?" sorusunu cevaplamak.**

## Ne ADR Olur, Ne Olmaz

| ADR olur | ADR olmaz |
|---|---|
| Retrofit yerine Ktor'a geçiş | Bir fonksiyonun adı |
| MVVM'den MVI'ya geçiş | Bir ekranın renk paleti |
| Offline-first stratejisi seçimi | Hangi klasöre dosya konacağı |
| Multi-module sınırlarının tanımı | Kod formatı kuralı |
| KMP'ye geçiş kararı | Bir kütüphanenin minor sürüm bump'ı |

Ölçüt: **geri dönmek pahalı mı?** Yarım günde geri alınabilen karar ADR hak etmez.
Ayda birden fazla ADR yazıyorsanız eşiği düşük tutuyorsunuz demektir.

---

## Şablon

`docs/architecture/adr/NNNN-kebab-case-baslik.md`:

```markdown
# ADR-0004: Offline-first veri stratejisi olarak Room'u SSOT yapmak

- **Durum:** Accepted
- **Tarih:** 2026-08-10
- **Karar verenler:** @ahmetoguzer, @takim-lead
- **İlgili:** ADR-0002 (multi-module sınırları), JIRA-1234

## Bağlam

Kullanıcıların %31'i günün bir kısmında zayıf kapsamada. Mevcut mimaride ekranlar
doğrudan API'den okuyor; ağ hatası boş ekran üretiyor. Play Store yorumlarının
%18'i bu davranışı şikâyet ediyor.

Kısıtlar:
- Mevcut 40+ ekranın hepsini aynı anda değiştiremeyiz
- Backend'de ETag/If-Modified-Since desteği var
- Ekip Room'a aşina, SQLDelight'a değil

## Değerlendirilen Alternatifler

### A. Room'u SSOT yapmak (seçilen)
UI Room'dan Flow ile okur; ağ yalnızca cache'i tazeler.
- (+) Ağ hatası mevcut veriyi silmez
- (+) Ekip Room'u biliyor, öğrenme maliyeti yok
- (+) Ekran ekran kademeli geçiş mümkün
- (−) Her feature için entity + mapper yazma maliyeti
- (−) Şema migration disiplini gerekiyor

### B. Bellek içi cache (Repository seviyesinde)
- (+) En hızlı implementasyon
- (−) Process ölümünde kaybolur — asıl senaryoyu çözmez

### C. OkHttp HTTP cache
- (+) Neredeyse sıfır kod
- (−) Yalnızca GET, yalnızca sunucu header'larına bağlı; sorgu/filtre desteklemiyor

## Karar

**A'yı seçiyoruz.** UI katmanı yalnızca Room'dan okur. Repository'lerde
`observeX(): Flow<T>` + `refreshX(): Result<Unit>` ikilisi standarttır.

## Sonuçlar

**Olumlu**
- Ağ hatası artık "veri biraz eski" durumu; boş ekran değil
- Ekranlar arası tutarlılık: tek okuma yolu

**Olumsuz / kabul edilen bedel**
- Her yeni feature entity + mapper + migration maliyeti taşıyor
- Room şema dosyaları (`schemas/`) repoda tutulacak, migration testleri zorunlu

**Takip işleri**
- `android-data-layer` skill'i bu desenle güncellensin
- Mevcut 40 ekran için geçiş sırası belirlensin (JIRA-1240)
```

---

## Durum Yaşam Döngüsü

| Durum | Anlamı |
|---|---|
| `Proposed` | Tartışmaya açık, henüz uygulanmıyor |
| `Accepted` | Yürürlükte, kod bunu izlemeli |
| `Deprecated` | Artık önerilmiyor ama yerine yenisi yok |
| `Superseded by ADR-00NN` | Yerine yeni karar geçti |

**ADR silinmez, düzenlenmez.** Karar değiştiyse yeni bir ADR yaz ve eskisinin
başına `Superseded by ADR-0007` satırını ekle. Tarih kaydı bozulmamalı —
ADR'nin değeri "o gün ne bildiğimiz"i göstermesinde.

---

## Numaralandırma ve İndeks

```bash
ls docs/architecture/adr/ | tail -1        # son numarayı gör
```

Numara sıfır dolgulu ve **asla yeniden kullanılmaz** (`0001`, `0002`, …).

`docs/architecture/adr/README.md` indeksini her ADR'de güncelle:

```markdown
| # | Başlık | Durum | Tarih |
|---|---|---|---|
| [0004](0004-room-as-ssot.md) | Offline-first için Room'u SSOT yapmak | Accepted | 2026-08-10 |
| [0003](0003-hilt-over-koin.md) | DI için Hilt | Accepted | 2026-05-02 |
| [0002](0002-module-boundaries.md) | Multi-module sınırları | Superseded by 0006 | 2026-03-11 |
```

---

## Yazım Kuralları

- **Bağlam bölümünde sayı kullan.** "Kullanıcılar şikâyet ediyor" değil,
  "yorumların %18'i". Sayı yoksa kararın gerekçesi hissiyattır.
- **Reddedilen alternatifleri gerçekten yaz.** Tek alternatifli ADR, karar kaydı değil
  duyurudur. Okuyucu "şunu neden denemediniz?" diye sorabilmemeli.
- **Olumsuz sonuçları sakla ma.** Bedelini yazmayan ADR güvenilmezdir; ayrıca ileride
  "bunu bilmiyorduk" savunmasını imkânsız kılar.
- **Kısa tut.** 1-2 sayfa. Uzun tasarım anlatısı ADR değil design doc'tur (`design-doc`).
- Karar cümlesi **kesin ve emir kipinde** olmalı: "Room'u SSOT yapıyoruz",
  "Room iyi bir seçenek olabilir" değil.

---

## Checklist

- [ ] Karar gerçekten geri dönmesi pahalı bir karar
- [ ] Numara sırayla ve sıfır dolgulu
- [ ] Bağlam ölçülebilir veri içeriyor
- [ ] En az 2 gerçek alternatif artı/eksileriyle değerlendirilmiş
- [ ] Karar cümlesi net ve emir kipinde
- [ ] Olumsuz sonuçlar / kabul edilen bedel açıkça yazılmış
- [ ] Takip işleri listelenmiş
- [ ] `adr/README.md` indeksi güncellendi
- [ ] Eski bir ADR'yi geçersiz kılıyorsa oraya `Superseded by` satırı eklendi
