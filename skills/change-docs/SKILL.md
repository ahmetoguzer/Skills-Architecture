---
name: change-docs
last_reviewed: 2026-08
description: >
  Tamamlanmış işlerin kaydı: feature dokümanı (ne geldi, nasıl çalışıyor), fix dokümanı
  (kök neden + tekrar önleme), refactor dokümanı (önce/sonra + migration rehberi) ve
  release notes (sürümün getirdikleri). Dört şablonu ve dosyalama düzenini içerir.

  Şu isteklerde tetiklen: "feature dokümanı yaz", "fix dokümante et", "kök neden analizi",
  "refactor dokümanı", "önce sonra karşılaştırması", "release notes", "sürüm notları",
  "changelog", "bu işi kayıt altına al", "postmortem".
---

# Change Docs Skill

Sen tamamlanmış işin kâtibisin. Bu dokümanların okuyucusu **altı ay sonraki bir
geliştirici** — muhtemelen sen. Ona "ne yaptık" değil, "neden böyle yaptık ve
nelere dikkat etmeli" anlat.

## Dört Tür, Dört Amaç

| Tür | Ne zaman | Asıl sorusu | Konum |
|---|---|---|---|
| **feature-doc** | Feature yayına çıkınca | "Bu nasıl çalışıyor?" | `docs/changes/features/` |
| **fix-doc** | Önemsiz olmayan bug fix | "Neden oldu, tekrar olur mu?" | `docs/changes/fixes/` |
| **refactor-doc** | Önemsiz olmayan refactor | "Ne değişti, nasıl uyum sağlarım?" | `docs/changes/refactors/` |
| **release-notes** | Sürüm çıkarken | "Bu sürümde ne var?" | `docs/releases/` |

Dosya adı: `YYYY-MM-DD-kebab-case.md`. Her klasörde `README.md` indeksi.

**Ne zaman yazma:** tek satırlık düzeltme, tipografi, bağımlılık patch bump'ı,
davranış değiştirmeyen yeniden adlandırma. Kayıt zorunluluğu, kaydı değersizleştirmemeli.

---

## 1. Feature Doc

```markdown
# Feature: Sipariş geçmişi offline desteği

- **Sürüm:** 4.12.0
- **Tarih:** 2026-08-10
- **PR:** #1287
- **İlgili:** ADR-0004, design doc `2026-08-order-history-offline.md`

## Ne geldi
Kullanıcı kapsama dışındayken son bilinen sipariş listesini görebiliyor;
ağ döndüğünde liste sessizce tazeleniyor.

## Nasıl çalışıyor
Room artık siparişler için tek doğruluk kaynağı. UI yalnızca `OrderDao.observeAll()`
akışını dinler; `refreshOrders()` API'den çekip Room'a upsert eder ve UI dolaylı güncellenir.
Ağ hatası listeyi silmez, yalnızca bir uyarı satırı gösterir.

Periyodik senkron: `SyncWorker`, 6 saatte bir, `CONNECTED` + `BATTERY_NOT_LOW` kısıtıyla.

## Dokunulan yerler
| Modül | Değişiklik |
|---|---|
| `:core:domain` | `Order`, `OrderRepository`, `GetOrdersUseCase` |
| `:core:data` | `OrderEntity`, `OrderDao`, migration 4→5, `OrderRepositoryImpl` |
| `:feature:orders` | `OrderListViewModel` offline state |

## Nasıl doğrulanır
1. Uygulamayı aç, sipariş listesini yükle
2. Uçak moduna al, uygulamayı kapat-aç
3. Liste görünmeli, üstte "Çevrimdışı — son güncelleme 5 dk önce" satırı olmalı

## Bilinen sınırlar
- Offline'da sipariş iptali yok
- 7 günden eski cache temizleniyor; 7+ gün offline kalan kullanıcı boş liste görür

## Konfigürasyon
Feature flag yok. Sync aralığı `SyncConfig.ORDER_SYNC_HOURS` (varsayılan 6).
```

---

## 2. Fix Doc

Bir bug fix dokümanının **tek amacı vardır: aynı hatanın tekrar etmemesi.**
"Düzeltildi" yazmak yeterli değil.

```markdown
# Fix: Boş sepette çöken checkout ekranı

- **Sürüm:** 4.11.3 (hotfix)
- **Tarih:** 2026-08-05
- **PR:** #1274
- **Etki:** 4.11.0–4.11.2, ~%0.8 kullanıcı, 3.412 crash

## Belirti
`CheckoutScreen` açılışında `IndexOutOfBoundsException: Index 0 out of bounds for length 0`.
Yalnızca sepet boşken ve kullanıcı derin bağlantıyla doğrudan checkout'a girdiğinde.

## Kök neden
`CheckoutViewModel` init bloğunda `cartItems.first()` çağrılıyordu. Normal akışta
sepet boşken checkout butonu görünmediği için bu durum test edilmemişti; ancak
`app://checkout` derin bağlantısı sepet kontrolü yapmadan ekranı açıyordu.

Asıl hata tek bir satır değil, **iki eksik varsayımın kesişimi**:
1. ViewModel, boş olmayan sepet varsayıyordu (sözleşmede yazılı değildi)
2. Derin bağlantı yönlendirmesi ön koşul doğrulaması yapmıyordu

## Düzeltme
- `CheckoutUiState.Empty` state'i eklendi; boş sepette bilgilendirici ekran gösteriliyor
- Derin bağlantı yönlendirmesi `CheckoutPrecondition` üzerinden geçiyor,
  ön koşul sağlanmazsa sepet ekranına düşüyor

## Tekrar önleme
- [x] `CheckoutViewModelTest.bosSepetteEmptyStateGosterilir` testi eklendi
- [x] Tüm derin bağlantılar için ön koşul testi (`DeepLinkPreconditionTest`)
- [x] `mobile-code-review` checklist'ine "koleksiyon erişimlerinde boş durum" maddesi
- [ ] Diğer 6 ekranın derin bağlantı ön koşulları taranacak (JIRA-1290)

## Neden daha erken yakalanmadı
Crash yalnızca derin bağlantı + boş sepet kesişiminde oluşuyordu; UI testleri
her zaman dolu sepetle başlıyordu. Test fixture'ları artık boş sepet varyantı da içeriyor.
```

**"Tekrar önleme" bölümü olmayan fix dokümanı yazma.** Test yoksa fix bitmemiştir.

---

## 3. Refactor Doc

```markdown
# Refactor: OrderMapper'ın repository'den ayrılması

- **Sürüm:** 4.12.0
- **Tarih:** 2026-08-08
- **PR:** #1281
- **Davranış değişikliği:** Yok

## Neden
`OrderRepositoryImpl` 340 satıra çıkmıştı; DTO→Entity→Domain dönüşümleri iş mantığıyla
iç içeydi. Mapper'lar ayrı test edilemiyordu ve aynı dönüşüm üç yerde tekrarlanıyordu.

## Önce
```kotlin
class OrderRepositoryImpl(...) {
    override suspend fun refresh(): Result<Unit> = runCatching {
        val dtos = api.getOrders()
        val entities = dtos.map { dto ->
            OrderEntity(
                id = dto.id ?: error("null id"),
                // ... 20 satır dönüşüm, iş mantığının ortasında
            )
        }
        dao.upsertAll(entities)
    }
}
```

## Sonra
```kotlin
class OrderRepositoryImpl(private val mapper: OrderMapper, ...) {
    override suspend fun refresh(): Result<Unit> = runCatching {
        dao.upsertAll(api.getOrders().map(mapper::toEntity))
    }
}
```

## Etki
- `OrderRepositoryImpl`: 340 → 120 satır
- `OrderMapper` bağımsız test edildi: 14 yeni test (null/eksik alan senaryoları dahil)
- Tekrarlanan üç dönüşüm tek yere indi

## Migration rehberi
Bu paketi kullanan kod için:
- `OrderRepositoryImpl` constructor'ı artık `OrderMapper` alıyor —
  Hilt kullanıyorsanız otomatik çözülür, elle örnekleyen testleri güncelleyin
- `OrderEntity.fromDto()` kaldırıldı → `orderMapper.toEntity(dto)`

## Doğrulama
Tüm mevcut testler değişmeden geçti (davranış korundu) + 14 yeni mapper testi.
```

---

## 4. Release Notes

İki hedef kitle, iki metin — karıştırma:

```markdown
# 4.12.0 — 2026-08-12

## Kullanıcıya görünen (mağaza metni)
- Sipariş geçmişiniz artık çevrimdışıyken de görüntülenebiliyor
- Sepet ekranındaki nadir bir çökme giderildi
- Performans iyileştirmeleri

## Teknik (ekip içi)
### Eklendi
- Sipariş geçmişi offline desteği (Room SSOT) — feature-doc, ADR-0004
- `SyncWorker` ile 6 saatlik periyodik senkron

### Değişti
- `OrderRepository` arayüzü: `getOrders()` → `observeOrders()` + `refreshOrders()`
- Room şeması 4 → 5

### Düzeltildi
- Boş sepette checkout çökmesi (#1274)

### Kaldırıldı
- `OrderEntity.fromDto()` (bkz. refactor-doc 2026-08-08)

### Migration gerektiren
- Room 4→5: yeni tablo, veri kaybı yok
- `OrderRepository` kullanan modüller arayüz değişikliğinden etkilenir

## Ölçümler
- APK: 24.1 MB → 24.4 MB (+300 KB, Room entity'leri)
- Cold start: 612 ms → 598 ms
- Crash-free users (ilk 48 saat): %99.7
```

Mağaza metnini teknik terimle doldurma; teknik bölümü pazarlama diliyle yazma.

---

## Checklist

- [ ] Doğru tür seçildi (feature / fix / refactor / release)
- [ ] Dosya `YYYY-MM-DD-kebab-case.md` biçiminde ve doğru klasörde
- [ ] Klasör `README.md` indeksine eklendi
- [ ] PR/JIRA/ADR bağlantıları verildi
- [ ] **Fix ise:** kök neden yazılmış ve "tekrar önleme" maddeleri test içeriyor
- [ ] **Refactor ise:** önce/sonra kod bloğu ve migration rehberi var, davranış değişikliği belirtilmiş
- [ ] **Feature ise:** nasıl doğrulanacağı adım adım yazılmış, bilinen sınırlar listelenmiş
- [ ] **Release ise:** kullanıcı metni ve teknik metin ayrı
- [ ] Ölçüm verilebilecek yerde sayı verilmiş
