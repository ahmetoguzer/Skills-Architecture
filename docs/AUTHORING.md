# Skill Yazma Rehberi

Bu koleksiyona yeni bir skill eklerken izlenecek kurallar.

## 1. Dosya İskeleti

```
skills/<skill-adı>/
├── SKILL.md            ← zorunlu
└── references/         ← opsiyonel
    └── <konu>.md
```

Klasör adı = frontmatter'daki `name` = küçük harf, kelimeler `-` ile ayrılmış.

## 2. Frontmatter

```yaml
---
name: android-compose-ui
description: >
  Ne yaptığının 1-2 cümlelik özeti.

  Şu isteklerde tetiklen: "türkçe ifade", "english phrase", ...
  <Sınır cümlesi: hangi durumda başka skill'e devredilir.>
---
```

Kurallar:
- `name` klasör adıyla **birebir** aynı olmalı
- `description` skill seçimini belirleyen tek alandır — üstünde en çok burada çalış
- Tetikleyici ifadeleri **kullanıcının yazacağı gibi** yaz ("uygulama yavaş"), teknik
  terminolojiyle değil ("performance degradation")
- Türkçe + İngilizce ifadeleri birlikte ver
- Devretme sınırını açıkça belirt

### İyi vs kötü description

```yaml
# Kötü — genel, her şeye tetiklenir, hiçbir şeye net değil
description: Android geliştirme yardımı sağlar.

# İyi — kapsam + somut tetikleyiciler + sınır
description: >
  Android veri katmanı uzmanlığı: offline-first, Room, Retrofit, Paging 3, WorkManager.
  Şu isteklerde tetiklen: "offline çalışsın", "cache", "Room", "sonsuz liste", "sync".
  Genel mimari sorusu ise android-architect'e devret.
```

## 3. İçerik Yapısı

Sırayla:

1. **Rol cümlesi** — "Sen … uzmanısın" + temel ilke (1-3 cümle)
2. **Karar rehberi** — tablo veya "ne zaman X, ne zaman Y"
3. **Kod şablonları** — derlenebilir, `// TODO` içermeyen örnekler
4. **Tuzaklar** — yaygın hatalar ve düzeltmeleri
5. **Checklist** — `- [ ]` maddeleri, doğrulanabilir

## 4. Yazım Kuralları

| Kural | Gerekçe |
|---|---|
| Açıklamalar Türkçe, kod/tanımlayıcı İngilizce | Ekip dili Türkçe, kod tabanı uluslararası |
| Kod örnekleri gerçek ve tam | Yarım örnek kopyalanamaz, model de tamamlarken uydurur |
| Yanlış/doğru çiftleri göster | Model neyi yapmayacağını da öğrenir |
| Tradeoff'ları yaz | Tek doğru varmış gibi anlatma; bağlam değişir |
| Sürüm bağımlı bilgiye tarih/sürüm ekle | Eskidiğinde fark edilsin |
| Emir kipi kullan ("… kullan", "… yazma") | Talimat olarak okunur |

## 5. Uzunluk

- `SKILL.md` hedefi **200-400 satır**, üst sınır 500
- Aşıyorsa: derin bölümü `references/<konu>.md`'ye taşı, SKILL.md'de tek satırla referans ver:
  ```markdown
  Detaylı MVI implementasyonu için `references/mvi-pattern.md`.
  ```
- `references/` dosyalarında uzunluk sınırı yoktur; sadece gerektiğinde okunurlar

## 6. Checklist Yazımı

Kötü: `- [ ] Kod kaliteli`
İyi: `- [ ] Lazy list item'larında key verilmiş`

Her madde **tek bir şeyi**, **bakarak doğrulanabilir** şekilde sorar.

## 7. Kataloglara Ekle

Bir skill üç yerde listelenir. Üçünü de güncelle, yoksa skill pratikte görünmez olur:

| Dosya | Ne yazılır |
|---|---|
| `README.md` | Doğru grup tablosunda satır: link + kapsam özeti |
| `skills/README.md` | İndeks satırı + gerekiyorsa yönlendirme haritasına ekleme |
| `templates/CLAUDE.md` | Skill tablosunda "ne zaman" satırı |

Yeni skill bir başkasının alanına yakınsa **sınır kuralları** tablolarına da bir satır ekle
(`skills/README.md` ve `docs/ARCHITECTURE.md`) — karışma ihtimalini baştan çöz.

Mevcut bir skill'i **değiştirirken** de aynı disiplin geçerli: değiştirdiğin kuralın
anahtar terimini tüm `skills/` altında grep'le; başka bir skill aynı konuyu anlatıyorsa
kopyayı silip devretme notuna çevir. Kontrol maddeleri `mobile-code-review` skill'inin
"Skill / Doküman PR'ları" bölümünde.

## 8. Doğrulama

```bash
./scripts/validate.sh
```

Kontrol ettikleri:
- Her skill klasöründe `SKILL.md` var
- Klasör adı kebab-case
- Frontmatter geçerli, `name` ve `description` dolu
- `name` klasör adıyla eşleşiyor
- SKILL.md içindeki `references/...` yolları gerçekten var
- Üç katalog (README, skills/README, templates/CLAUDE.md) skill listesiyle senkron
- Katalogda anılan ama var olmayan skill yok (yeniden adlandırma artığı)
- Satır sayısı 500'ü aşmıyor (uyarı)
- Checklist bölümü var (uyarı)

CI'da `.github/workflows/validate.yml` ile her PR'da otomatik çalışır.

## 9. Test Etme

Yeni skill'i yazdıktan sonra tetiklemeyi elle dene: 5 farklı ifadeyle iste ve
doğru skill'in seçildiğini gör. Seçilmiyorsa `description`'daki tetikleyicileri güncelle —
içeriği değil.

Yanlış tetikleniyorsa (alakasız isteklerde açılıyorsa) description'ı **daralt** ve
sınır cümlesini netleştir.
