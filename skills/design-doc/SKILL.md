---
name: design-doc
last_reviewed: 2026-08
description: >
  Kodlamadan önce yazılan tasarım dokümanı: büyük bir feature veya refactor için problem
  tanımı, hedefler/hedef olmayanlar, önerilen tasarım, veri modeli ve API sözleşmesi,
  migration planı, riskler, test stratejisi ve fazlara bölünmüş teslimat planı.

  Şu isteklerde tetiklen: "design doc yaz", "tasarım dokümanı", "kodlamadan önce planlayalım",
  "teknik tasarım", "bu büyük bir iş, nasıl bölelim", "RFC yaz", "yaklaşımı yazıya dökelim",
  "migration planı". Karar zaten verildiyse ve kaydı isteniyorsa adr skill'ine devret.
---

# Design Doc Skill

Sen kodlamadan önce düşünmeyi kurumsallaştıran kişisin. Design doc'un amacı
**yanlış kodu yazmadan önce yanlış olduğunu anlamak.** Tasarımı tartışmak ucuz,
kodu yeniden yazmak pahalıdır.

## Ne Zaman Gerekir?

| Gerekir | Gerekmez |
|---|---|
| 1 haftadan uzun iş | Tek ekran, tek gün |
| 3+ modüle dokunuyor | Tek modül içi |
| Şema/API sözleşmesi değişiyor | Sadece UI düzenlemesi |
| Geri dönüşü pahalı bir yaklaşım seçiliyor | Yerleşik desenin tekrarı |
| Birden fazla kişi paralel çalışacak | Tek kişilik iş |

Ölçüt: **birden fazla makul yaklaşım var mı?** Tek doğru yol varsa doküman yazma, yap.

`design-doc` vs `adr`: design doc **nasıl yapacağımızı** anlatır (kodlamadan önce),
ADR **neden bu yolu seçtiğimizi** kaydeder (karar anında). Büyük bir işte ikisi de olur:
design doc içindeki kritik seçim ayrı bir ADR'ye çıkar.

---

## Şablon

`docs/design/YYYY-MM-kebab-case-baslik.md`:

```markdown
# Design: Sipariş geçmişi offline desteği

- **Durum:** Draft | In Review | Approved | Implemented | Abandoned
- **Yazar:** @ahmetoguzer
- **Gözden geçirenler:** @takim-lead, @backend-lead
- **Tarih:** 2026-08-10
- **İlgili:** ADR-0004, JIRA-1234

## 1. Problem

Kullanıcı kapsama dışındayken sipariş geçmişini göremiyor. Ekran boş açılıyor,
retry dışında bir yol yok. Destek taleplerinin %12'si bu.

Bugünkü akış: `OrderListViewModel → OrderApi` (doğrudan, cache yok).

## 2. Hedefler

- Kullanıcı offline'ken son bilinen sipariş listesini görebilmeli
- Ağ döndüğünde liste otomatik tazelenmeli
- Mevcut ekranların davranışı bozulmamalı

## 3. Hedef Olmayanlar

- Offline'da sipariş oluşturma/iptal (ayrı iş)
- Sayfalama (kullanıcı başına < 100 sipariş)
- Diğer 39 ekranın geçişi (bu doküman yalnızca pilot)

## 4. Önerilen Tasarım

Room SSOT (ADR-0004 uyarınca):

    OrderListScreen ← StateFlow ← OrderListViewModel
                                     ↓
                              GetOrdersUseCase
                                     ↓
                          OrderRepository (arayüz)
                                     ↓
                        OrderRepositoryImpl
                         ↙                ↘
                  OrderDao (Room)     OrderApi
                     ↑ SSOT              ↓
                     └──── refresh ──────┘

`observeOrders(): Flow<List<Order>>` — yalnızca Room'dan okur.
`refreshOrders(): Result<Unit>` — API'den çeker, Room'a upsert eder, UI'ı dolaylı günceller.

## 5. Veri Modeli

| Alan | Tip | Not |
|---|---|---|
| id | TEXT PK | sunucu id'si |
| number | TEXT | görünen sipariş no |
| totalCents | INTEGER | kuruş cinsinden, float kullanılmıyor |
| currency | TEXT | ISO 4217 |
| status | TEXT | enum adı |
| createdAt | INTEGER | epoch millis |
| updatedAt | INTEGER | yerel senkron zamanı, stale temizliği için |

Index: `status`, `createdAt DESC`.
Migration: 4 → 5, `orders` tablosu eklenir (veri kaybı yok, yeni tablo).

## 6. API Sözleşmesi

`GET /v2/orders?since={epochMillis}` → `200 { items: [...], hasMore: bool }`
- `since` verilmezse son 12 ay döner
- Backend değişikliği gerekiyor mu: **Hayır**, mevcut endpoint yeterli

## 7. Teslimat Fazları

| Faz | Kapsam | Bağımsız merge edilebilir? |
|---|---|---|
| 1 | Domain: model, repository arayüzü, use case'ler | Evet |
| 2 | Data: entity, DAO, migration, repository impl, sync | Evet |
| 3 | UI: ViewModel + ekran offline state'i | Evet |
| 4 | WorkManager periyodik sync | Evet |

Her faz kendi testleriyle birlikte merge edilir; feature flag gerekmez çünkü
davranış değişimi yalnızca son fazda görünür hale gelir.

## 8. Test Stratejisi

- Mapper: DTO → Entity → Domain dönüşümleri, null alan senaryoları
- Repository: ağ hatasında cache'in korunduğu
- Migration: 4 → 5 `MigrationTestHelper` ile
- ViewModel: offline + boş cache → boş state; offline + dolu cache → liste
- Manuel: uçak modunda açılış

## 9. Riskler

| Risk | Olasılık | Etki | Azaltma |
|---|---|---|---|
| Migration'da veri kaybı | Düşük | Yüksek | Yeni tablo, mevcut veriye dokunulmuyor; migration testi |
| Cache tutarsızlığı (stale veri) | Orta | Orta | `updatedAt` ile 7 günden eski kayıt temizliği |
| DB boyutu büyümesi | Düşük | Düşük | Kayıt başına ~200 byte, 100 kayıt = 20 KB |

## 10. Açık Sorular

- [ ] Stale eşiği 7 gün mü olmalı? → @backend-lead
- [x] Sayfalama gerekli mi? → Hayır, karar verildi (2026-08-09)
```

---

## Yazım Kuralları

- **"Hedef olmayanlar" bölümünü atlama.** Kapsam kaymasını engelleyen tek bölüm odur.
- **Diyagram metin olarak** çizilebiliyorsa metin çiz — resim eskiyince kimse güncellemez.
- **Fazlar bağımsız merge edilebilir olmalı.** "Hepsi bitince merge" planı, iki hafta
  açık kalan bir PR demektir.
- **Açık soruları listele ve sahibini yaz.** Cevaplananları sil değil, işaretle —
  aynı soru iki kez sorulmasın.
- Riskleri **olasılık × etki** ile derecelendirin; her risk için azaltma yazın.
  Azaltması olmayan risk, risk değil kabul edilmiş bedeldir — öyle yazın.

---

## Yaşam Döngüsü

```
Draft → In Review → Approved → Implemented
                        ↓
                   Abandoned (nedeni bir paragrafla yazılır)
```

İmplementasyon sırasında tasarım değişirse **dokümanı güncelle** — sonradan okuyan
kişi kodla dokümanı çelişik bulursa ikisine de güvenmez. Bitince durumu
`Implemented` yap ve varsa `change-docs` ile feature dokümanına link ver.

---

## Checklist

- [ ] Problem ölçülebilir veriyle tanımlanmış
- [ ] Hedefler ve **hedef olmayanlar** ayrı ayrı yazılmış
- [ ] Tasarım metin diyagramıyla gösterilmiş
- [ ] Veri modeli ve API sözleşmesi net (migration dahil)
- [ ] Fazlar bağımsız merge edilebilir
- [ ] Test stratejisi katman katman belirtilmiş
- [ ] Riskler olasılık/etki/azaltma ile tablolanmış
- [ ] Açık sorular sahipleriyle listelenmiş
- [ ] Durum alanı güncel
- [ ] Kritik seçimler ayrıca ADR'ye çıkarıldı
