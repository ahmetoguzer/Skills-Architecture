---
name: kdoc-standards
description: >
  KDoc ve kod içi yorum standartları: ne dokümante edilir ne edilmez, KDoc etiketleri,
  public API sözleşmesi yazımı, "neden" yorumları, TODO/FIXME disiplini, Swift tarafında
  DocC karşılıkları ve Dokka üretimi.

  Şu isteklerde tetiklen: "KDoc yaz", "dokümantasyon yorumu", "bu fonksiyonu açıkla",
  "javadoc", "kod yorumu ekle", "public API dokümante et", "Dokka", "yorum standardı",
  "TODO bırak".
---

# KDoc & Comment Standards Skill

Sen kod dokümantasyonu disiplinini kuran kişisin. Temel ilken:
**Kod ne yaptığını söyler; yorum neden yaptığını söyler.**

Kodun kendisinin anlattığı şeyi tekrarlayan yorum, bakım yüküdür — kod değişir, yorum kalır, yalan söyler.

## Ne Dokümante Edilir?

| Dokümante et | Etme |
|---|---|
| Public API (kütüphane/modül sınırı) | Private yardımcı fonksiyonlar |
| Sezgiye aykırı davranış | Getter/setter |
| Sözleşme: ne fırlatır, ne döner, thread güvenli mi | `fun getName(): String` |
| İş kuralının kaynağı (yasal zorunluluk, backend kısıtı) | Değişken adının tekrarı |
| Geçici çözümün nedeni + kaldırma koşulu | Sınıf adının tekrarı |
| Karmaşık algoritmanın fikri | Döngünün ne yaptığı |

```kotlin
// KÖTÜ — kodun tekrarı
/** Kullanıcı adını döner. */
fun getUserName(): String

// KÖTÜ — açıklamıyor, tekrarlıyor
// i'yi bir artır
i++

// İYİ — nedeni söylüyor
// Backend 100'den büyük sayfa boyutunu sessizce 100'e kırpıyor (bkz. JIRA-1188),
// bu yüzden istemcide sınırlıyoruz ki sayfalama hesabı tutarlı kalsın.
private const val MAX_PAGE_SIZE = 100
```

---

## KDoc Yapısı

```kotlin
/**
 * Siparişleri yerel veritabanından akış olarak yayınlar.
 *
 * Bu akış tek doğruluk kaynağıdır (ADR-0004): ağdan okuma yapmaz.
 * Güncel veri için önce [refreshOrders] çağrılmalıdır. Ağ hatası bu akışı
 * etkilemez — son bilinen veri yayınlanmaya devam eder.
 *
 * @param status Yalnızca bu durumdaki siparişler; `null` ise tümü.
 * @return Sipariş listesi akışı; veritabanı her değiştiğinde yeniden yayınlar.
 *         Veri yoksa boş liste yayınlar, hata fırlatmaz.
 * @see refreshOrders
 * @sample com.example.samples.observeOrdersSample
 */
fun observeOrders(status: OrderStatus? = null): Flow<List<Order>>
```

Sıra: **özet cümlesi** → boş satır → detay → boş satır → etiketler.

Özet cümlesi:
- Tek cümle, nokta ile biter
- Üçüncü tekil şahıs ("döner", "yayınlar"), "Bu fonksiyon…" diye başlamaz
- IDE'de tek satır olarak görüneceği için kendi başına anlamlı olmalı

### Etiketler

| Etiket | Ne zaman |
|---|---|
| `@param` | Adından anlaşılmayan veya kısıtı olan parametrelerde |
| `@return` | Dönüş değerinin özel durumu varsa (boş liste vs null vs hata) |
| `@throws` | Fırlatılabilecek her exception ve **hangi koşulda** |
| `@see` | İlgili API'ye yönlendirme |
| `@sample` | Kullanımı sezgisel değilse (kod örneği ayrı dosyada, derlenir) |
| `@property` | `data class` constructor property'leri için |
| `@since` | Kütüphane API'sinde sürüm takibi |

**Tüm parametreleri mekanik olarak `@param`'lamak zorunda değilsin.**
`@param userId Kullanıcı id'si` satırı hiçbir bilgi katmaz — sil.

### Suspend ve Flow için ek sözleşme

```kotlin
/**
 * Siparişleri sunucudan çekip yerel veritabanını günceller.
 *
 * @return Başarıda [Result.success]; ağ/sunucu hatasında [Result.failure].
 *         Hata durumunda yerel veri **değişmeden kalır**.
 * @throws CancellationException Çağıran scope iptal edilirse (yakalanmamalı).
 */
suspend fun refreshOrders(): Result<Unit>
```

Suspend fonksiyonlarda mutlaka belirt: hangi dispatcher'da çalışır (veya çağıranın
dispatcher'ını kullanır), iptal edilebilir mi, yeniden çağrılabilir (idempotent) mi.

---

## "Neden" Yorumları

En değerli yorum türü. Şu üç durumda mutlaka yaz:

```kotlin
// 1. Geçici çözüm — nedeni + kaldırma koşulu
// Android 12'de BiometricPrompt, DEVICE_CREDENTIAL ile birlikte kullanıldığında
// setUserAuthenticationRequired(true) anahtarlarda IllegalStateException atıyor.
// minSdk 33'e çıktığında bu dal kaldırılacak (JIRA-1301).
if (Build.VERSION.SDK_INT == Build.VERSION_CODES.S) { ... }

// 2. Sezgiye aykırı ama doğru kod
// Sıralama BURADA yapılıyor, DAO'da değil: SQLite'ın COLLATE'i Türkçe
// karakterleri yanlış sıralıyor (ı/i, ş/s). Liste küçük (< 100), maliyeti önemsiz.
val sorted = orders.sortedWith(turkishCollator)

// 3. İş kuralının kaynağı
// KVKK gereği kişisel veri log'lanamaz; bu alan maskelenmeden log'a girmemeli.
private fun maskTckn(value: String) = value.take(3) + "********"
```

---

## TODO / FIXME Disiplini

```kotlin
// TODO(ahmetoguzer, JIRA-1290): Derin bağlantı ön koşullarını diğer 6 ekrana yay.
// FIXME(JIRA-1305): Bu retry sonsuz döngüye girebilir; backoff sayacı eklenmeli.
```

Kurallar:
- **Sahip + issue numarası zorunlu.** Sahipsiz TODO asla yapılmaz, kalıcı çöp olur
- `FIXME` bilinen bir hatadır — issue'su yoksa açılır
- Sahipsiz veya 6 aydan eski TODO'ları review'da işaretle: ya issue aç ya sil
- `TODO()` (Kotlin fonksiyonu, `NotImplementedError` atar) ile yorum TODO'sunu karıştırma

---

## Modül ve Paket Dokümanı

Her public modül için `Module.md` (Dokka `includes`):

```markdown
# Module core-data

Uygulamanın veri katmanı: repository implementasyonları, Room ve ağ kaynakları.

`:core:domain` arayüzlerini implemente eder. Bu modüle **dışarıdan doğrudan
bağımlılık verilmez** — `:feature:*` yalnızca `:core:domain`'i görür.

## Package com.example.core.data.repository

SSOT desenini uygulayan repository'ler (ADR-0004). Her repository
`observeX(): Flow<T>` + `refreshX(): Result<Unit>` ikilisini sunar.
```

---

## Dokka

```kotlin
plugins { alias(libs.plugins.dokka) }

dokka {
    moduleName.set("core-data")
    dokkaSourceSets.main {
        includes.from("Module.md")
        sourceLink {
            localDirectory.set(file("src/main/kotlin"))
            remoteUrl("https://github.com/org/repo/blob/main/core/data/src/main/kotlin")
            remoteLineSuffix.set("#L")
        }
        externalDocumentationLinks.register("coroutines") {
            url("https://kotlinlang.org/api/kotlinx.coroutines/")
        }
    }
}
```

`./gradlew dokkaGenerate` — public API dokümanını CI'da üret, kırılırsa fark et.

---

## Swift Tarafı (DocC)

```swift
/// Siparişleri yerel önbellekten yayınlar.
///
/// Bu dizi tek doğruluk kaynağıdır; ağdan okuma yapmaz.
/// Güncel veri için önce ``refreshOrders()`` çağırın.
///
/// - Parameter status: Yalnızca bu durumdaki siparişler; `nil` ise tümü.
/// - Returns: Sipariş dizisi; veritabanı değiştikçe yeni değer yayınlar.
/// - Throws: ``OrderError/storageUnavailable`` yerel depo açılamazsa.
func observeOrders(status: OrderStatus?) -> AsyncStream<[Order]>
```

Aynı prensipler geçerli: özet cümlesi, sözleşme, "neden" yorumları.
Çift eğik çizgi üç kez (`///`), çapraz referans için ``çift backtick``.

---

## Checklist

- [ ] Public API'ler dokümante edilmiş, private yardımcılar gereksiz yere değil
- [ ] Özet cümlesi tek satırda anlamlı ve nokta ile bitiyor
- [ ] Bilgi katmayan `@param`/`@return` satırları yok
- [ ] Fırlatılan exception'lar koşullarıyla belirtilmiş
- [ ] Suspend fonksiyonlarda iptal/dispatcher/idempotency sözleşmesi yazılmış
- [ ] Geçici çözümlerin nedeni **ve kaldırma koşulu** yazılı
- [ ] Sezgiye aykırı her kod parçasında "neden" yorumu var
- [ ] TODO/FIXME'lerde sahip ve issue numarası var
- [ ] Kodun tekrarı olan yorumlar temizlendi
- [ ] Modül için `Module.md` var ve Dokka'ya bağlı
