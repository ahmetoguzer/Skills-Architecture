---
name: mobile-analytics
last_reviewed: 2026-08
description: >
  Analytics ve event tracking mimarisi: event taksonomisi ve isimlendirme, tracking'in
  hangi katmandan gönderileceği, sağlayıcı soyutlaması (Firebase/Tealium/Amplitude),
  thread güvenliği ve cold-start ertelemesi, PII sızıntısını önleme, test edilebilirlik.

  Şu isteklerde tetiklen: "analytics ekle", "event gönder", "tracking", "Firebase Analytics",
  "Tealium", "Amplitude", "ekran görüntüleme eventi", "funnel", "kullanıcı davranışı ölç",
  "screen_view", "event isimlendirme", "analytics testi".
---

# Mobile Analytics Skill

Sen ölçümleme mimarisini kuran kişisin. İki kuralın var:
**event'ler ViewModel'den gönderilir** ve **hiçbir event'e kişisel veri konmaz.**

Analytics kodu, ürün kodunu kirletmeye en yatkın koddur — her ekrana serpilmiş
`Analytics.log(...)` çağrıları bakımı imkânsız bir yapı üretir.

## Katman Kuralı

```
Composable  ──(kullanıcı aksiyonu)──▶  ViewModel  ──▶  AnalyticsTracker  ──▶  SDK
     ✗ buradan event gönderme              ✓ buradan
```

**Composable'dan event göndermeme sebebi:** recomposition. Bir composable saniyede
onlarca kez yeniden çalışabilir; composition body'sindeki bir `track()` çağrısı
event'i tekrar tekrar gönderir. ViewModel ise state değişimini bir kez işler.

```kotlin
// YANLIŞ — her recomposition'da tetiklenir
@Composable
fun OrderListScreen() {
    analytics.trackScreen("order_list")     // ✗
    ...
}

// KABUL EDİLEBİLİR — sadece ekran görüntüleme için, bir kez
@Composable
fun OrderListScreen(viewModel: OrderListViewModel = hiltViewModel()) {
    LaunchedEffect(Unit) { viewModel.onScreenViewed() }   // ✓ ViewModel'e delege
    ...
}

// DOĞRU — aksiyon ViewModel'de işlenir, event orada gönderilir
fun onOrderClicked(orderId: String) {
    analytics.track(AnalyticsEvent.OrderSelected(position = indexOf(orderId)))
    sendEffect(NavigateToDetail(orderId))
}
```

---

## Event Taksonomisi

Event'leri **string olarak dağıtma** — tip güvenli tanımla:

```kotlin
sealed interface AnalyticsEvent {
    val name: String
    val params: Map<String, Any?> get() = emptyMap()

    data class ScreenViewed(val screen: String) : AnalyticsEvent {
        override val name = "screen_view"
        override val params = mapOf("screen_name" to screen)
    }

    data class OrderSelected(val position: Int) : AnalyticsEvent {
        override val name = "order_selected"
        override val params = mapOf("position" to position)
    }

    data class PurchaseCompleted(
        val orderId: String,
        val amountCents: Long,
        val currency: String,
        val itemCount: Int,
    ) : AnalyticsEvent {
        override val name = "purchase_completed"
        override val params = mapOf(
            "order_id" to orderId,
            "value" to amountCents / 100.0,
            "currency" to currency,
            "item_count" to itemCount,
        )
    }
}
```

Kazanç: yeni event eklerken tüm parametreler zorunlu hale gelir, yazım hatası
compile-time'da yakalanır, ve tüm event kataloğu tek dosyada görünür.

### İsimlendirme

| Kural | Örnek |
|---|---|
| `snake_case`, küçük harf | `order_selected` |
| `<nesne>_<fiil-geçmiş-zaman>` | `checkout_started`, `payment_failed` |
| Ekran adları tutarlı ve sabit | `order_list`, `order_detail` |
| Parametre adları da `snake_case` | `item_count`, `error_code` |
| Kısaltma yok | `qty` değil `quantity` |

Event adı **bir kez yayına çıktıktan sonra değiştirilmez** — geçmiş veriyle kıyaslanamaz
hale gelir. Yeni ad gerekiyorsa yeni event ekle, eskisini deprecate et.

---

## Sağlayıcı Soyutlaması

```kotlin
// :core:analytics — domain'e yakın, SDK'dan bağımsız arayüz
interface AnalyticsTracker {
    fun track(event: AnalyticsEvent)
    fun setUserProperty(key: String, value: String?)
}

// :core:analytics:impl
class CompositeAnalyticsTracker @Inject constructor(
    private val trackers: Set<@JvmSuppressWildcards AnalyticsTracker>,
) : AnalyticsTracker {
    override fun track(event: AnalyticsEvent) = trackers.forEach { it.track(event) }
}

@Module
@InstallIn(SingletonComponent::class)
abstract class AnalyticsModule {
    @Binds @IntoSet abstract fun bindFirebase(impl: FirebaseAnalyticsTracker): AnalyticsTracker
    @Binds @IntoSet abstract fun bindInternal(impl: InternalAnalyticsTracker): AnalyticsTracker
}
```

Bu soyutlama sayesinde: SDK değiştirmek tek sınıf değişikliği, testte `FakeAnalyticsTracker`
kullanılabilir, debug build'de bir logger tracker eklenebilir.

---

## Thread Güvenliği ve Cold Start

Analytics SDK'ları genelde init edilmeden çağrılırsa event'i **sessizce düşürür**.
Cold start'ta ilk ekranın event'leri bu yüzden kaybolur.

```kotlin
@Singleton
class DeferredAnalyticsTracker @Inject constructor(
    private val delegate: Provider<AnalyticsTracker>,
    @ApplicationScope private val scope: CoroutineScope,
) : AnalyticsTracker {

    private val ready = MutableStateFlow(false)
    private val pending = Channel<AnalyticsEvent>(capacity = 64)

    init {
        scope.launch {
            ready.first { it }                 // SDK hazır olana kadar bekle
            for (event in pending) delegate.get().track(event)
        }
    }

    fun onSdkReady() { ready.value = true }

    override fun track(event: AnalyticsEvent) {
        pending.trySend(event)                 // asla bloklamaz
    }
}
```

Kurallar:
- Analytics çağrısı **hiçbir zaman** main thread'i bloklamaz
- SDK init'i `Application.onCreate`'te senkron yapılıyorsa startup'a maliyeti ölçülmeli
  (`android-performance`)
- Kuyruk sınırlı olmalı; dolduğunda en eskiyi düşür, uygulamayı OOM'a sürükleme

---

## PII / Gizlilik

**Asla event parametresi yapma:** ad-soyad, telefon, e-posta, TCKN, adres, IBAN,
kart numarası, tam konum, cihaz tanımlayıcıları, serbest metin girdisi
(kullanıcı içine PII yazar).

```kotlin
// YANLIŞ
AnalyticsEvent.Search(query = userInput)              // kullanıcı "Ahmet 0532..." yazabilir

// DOĞRU — türetilmiş, kimliksiz metrikler
AnalyticsEvent.Search(
    queryLength = userInput.length,
    hasResults = results.isNotEmpty(),
    resultCount = results.size,
)
```

Kontrol listesi:
- Kullanıcıyı ayırt etmen gerekiyorsa **pseudonim id** kullan (rotasyonlu, geri döndürülemez)
- Event kataloğunu gizlilik/hukuk ekibiyle bir kez gözden geçir, sonra değişiklikleri onlara bildir
- Play Console **Data Safety** formu gönderilen verilerle birebir uyumlu olmalı
- Debug build'de gönderilen event'leri logla ki ne yolladığın görünür olsun

---

## Test

```kotlin
class FakeAnalyticsTracker : AnalyticsTracker {
    val events = mutableListOf<AnalyticsEvent>()
    override fun track(event: AnalyticsEvent) { events += event }
    override fun setUserProperty(key: String, value: String?) = Unit
}

@Test
fun `siparis tiklandiginda position ile event gonderilir`() = runTest {
    val analytics = FakeAnalyticsTracker()
    val viewModel = OrderListViewModel(getOrders, analytics)

    viewModel.onOrderClicked("order-3")

    assertThat(analytics.events).containsExactly(AnalyticsEvent.OrderSelected(position = 2))
}
```

Kritik funnel event'leri (satın alma, kayıt) **test edilir** — sessizce kaybolan bir
purchase event'i, doğrudan gelir raporunu bozar.

SDK'yı testte stub'lamayı unutma: gerçek SDK'nın statik init'i test ortamında patlar.

---

## Checklist

- [ ] Event'ler tip güvenli (`sealed interface`), string literal dağıtılmıyor
- [ ] Tracking ViewModel'den gönderiliyor, `@Composable` içinden değil
- [ ] Ekran görüntüleme `LaunchedEffect` ile bir kez tetikleniyor
- [ ] Sağlayıcı arayüz arkasında; testte fake kullanılabiliyor
- [ ] Analytics çağrısı main thread'i bloklamıyor
- [ ] Cold start'ta event kaybı yok (kuyruk/deferral var)
- [ ] Hiçbir parametrede PII yok; serbest metin gönderilmiyor
- [ ] Event adları `snake_case` ve yayınlanmış adlar değiştirilmiyor
- [ ] Kritik funnel event'leri için test var
- [ ] Data Safety formu event kataloğuyla uyumlu
