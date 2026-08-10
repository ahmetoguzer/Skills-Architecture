---
name: xml-compose-migration
last_reviewed: 2026-08
description: >
  XML/Fragment tabanlı ekranların Jetpack Compose'a kademeli taşınması: interop stratejisi
  (ComposeView / AndroidView), Fragment'tan Compose'a geçiş sırası, XML ViewModel'ini
  MVI reducer'a dönüştürme, RecyclerView → LazyColumn, davranış eşdeğerliği doğrulaması
  ve geri dönüş planı.

  Şu isteklerde tetiklen: "XML'i Compose'a çevir", "Fragment'ı Compose'a taşı",
  "Compose migration", "RecyclerView'ı LazyColumn yap", "ComposeView", "AndroidView",
  "kademeli Compose geçişi", "eski ekranı yenile", "MVI'ya taşı".
  Sıfırdan yeni ekran yazılacaksa android-compose-ui'ye devret.
---

# XML → Compose Migration Skill

Sen kademeli migration uzmanısın. En kritik kuralın: **migration bir refactor'dır,
feature değildir.** Taşırken davranış değiştirme; iyileştirme fikirlerini ayrı işe yaz.

Aksi halde bir hata çıktığında "migration mı bozdu, yeni özellik mi?" sorusunun
cevabı olmaz ve geri dönüş imkânsızlaşır.

## Migration Sırası (yukarıdan aşağı)

Ekranları rastgele seçme. Sıralama ölçütleri:

1. **Düşük riskli, kapalı ekranlar** — ayarlar, hakkında, statik içerik → ilk
2. **Yüksek trafikli ama basit** — liste ekranları → ikinci (kazanç görünür olur)
3. **Karmaşık, durum yoğun** — checkout, form akışları → son
4. **Üçüncü parti SDK view'ı barındıranlar** — mümkünse hiç taşıma, `AndroidView` ile sar

İlk ekranı ekip için **referans implementasyon** olarak seç ve fazladan özen göster;
sonraki 30 ekran onu kopyalayacak.

---

## Interop: İki Yön

### A. XML içinde Compose (tercih edilen geçiş yolu)

Mevcut Fragment'ı koru, içeriğini Compose'a devret:

```kotlin
class OrderListFragment : Fragment() {
    private val viewModel: OrderListViewModel by viewModels()

    override fun onCreateView(
        inflater: LayoutInflater, container: ViewGroup?, savedInstanceState: Bundle?,
    ): View = ComposeView(requireContext()).apply {
        setViewCompositionStrategy(ViewCompositionStrategy.DisposeOnViewTreeLifecycleDestroyed)
        setContent {
            AppTheme {
                OrderListScreen(
                    viewModel = viewModel,
                    onOrderClick = { findNavController().navigate(toDetail(it)) },
                )
            }
        }
    }
}
```

`setViewCompositionStrategy` **zorunlu** — varsayılan strateji Fragment'ın view
lifecycle'ı ile uyumsuzdur ve sızıntı/çökme üretir.

### B. Compose içinde XML view (kaçınılmazsa)

```kotlin
AndroidView(
    factory = { context -> LegacyChartView(context) },
    update = { view -> view.setData(uiState.chartData) },
    onRelease = { view -> view.cleanup() },
    modifier = Modifier.fillMaxWidth().height(200.dp),
)
```

`factory` yalnızca bir kez çalışır, `update` her recomposition'da. Ağır işi `factory`'ye koy.
`onRelease` ile listener/kaynak temizle — yoksa sızar.

---

## Adım Adım Geçiş

### Adım 1 — Davranışı dondur ve kayıt altına al

Taşımadan **önce** mevcut ekranın davranışını yaz:

```
- Boş listede: "Siparişiniz yok" + ikon
- Yükleniyor: tam ekran spinner (liste gizli)
- Hata: snackbar + retry butonu, liste eski veriyi gösterir
- Pull-to-refresh var
- Geri tuşu: sepet ekranına döner (özel davranış!)
```

Bu liste, migration sonrası **kabul kriteri** olacak. Yazmazsan kaybolur.

### Adım 2 — Mümkünse önce test yaz

Mevcut ekranın UI testi yoksa, taşımadan önce kritik akış için bir tane yaz.
Test XML'de geçiyorsa Compose'da da geçmeli — eşdeğerliğin kanıtı budur.

### Adım 3 — State'i modelle

XML ViewModel'i genelde birden çok `LiveData`/`MutableState` tutar:

```kotlin
// ÖNCE — dağınık state, imkânsız kombinasyonlara açık
val isLoading = MutableLiveData<Boolean>()
val orders = MutableLiveData<List<Order>>()
val error = MutableLiveData<String?>()
val isEmpty = MutableLiveData<Boolean>()      // orders ile çelişebilir
```

```kotlin
// SONRA — tek state, imkânsız durumlar temsil edilemez
data class OrderListUiState(
    val isLoading: Boolean = false,
    val isRefreshing: Boolean = false,
    val orders: List<Order> = emptyList(),
    val error: String? = null,
) {
    val isEmpty: Boolean get() = !isLoading && orders.isEmpty() && error == null
}
```

`isEmpty` **türetilmiş** olmalı, ayrı state değil. Ayrı tutulan türev state,
er ya da geç ana state ile çelişir.

### Adım 4 — MVI reducer'a dönüştür (proje bunu kullanıyorsa)

```kotlin
sealed interface OrderListEvent {
    data object Load : OrderListEvent
    data object Refresh : OrderListEvent
    data class OrderClicked(val id: String) : OrderListEvent
}

sealed interface OrderListEffect {
    data class NavigateToDetail(val id: String) : OrderListEffect
    data class ShowError(val message: String) : OrderListEffect
}

class OrderListViewModel @Inject constructor(
    private val getOrders: GetOrdersUseCase,
) : BaseMviViewModel<OrderListEvent, OrderListUiState, OrderListEffect>(OrderListUiState()) {

    override fun onEvent(event: OrderListEvent) = when (event) {
        OrderListEvent.Load -> load()
        OrderListEvent.Refresh -> refresh()
        is OrderListEvent.OrderClicked -> sendEffect(OrderListEffect.NavigateToDetail(event.id))
    }
}
```

Projede bir base sınıf varsa (`ComposeBaseViewModel`, `BaseMviViewModel`) **onu kullan**,
yenisini icat etme. Mevcut bir MVI ekranını örnek alıp deseni kopyala.

### Adım 5 — UI'ı taşı

| XML | Compose |
|---|---|
| `RecyclerView` + Adapter + ViewHolder + DiffUtil | `LazyColumn` + `items(key = )` |
| `ConstraintLayout` | `Column`/`Row`/`Box`, gerekirse `ConstraintLayout` composable |
| `include` layout | Composable fonksiyon |
| `ViewStub` | `if (condition) { }` |
| `SwipeRefreshLayout` | `PullToRefreshBox` |
| `ViewPager2` | `HorizontalPager` |
| `BottomSheetDialogFragment` | `ModalBottomSheet` |
| `Toolbar` + menu XML | `TopAppBar` + `actions = { }` |
| `View.GONE` / `VISIBLE` | Composable'ı hiç çağırmama |
| `android:contentDescription` | `Modifier.semantics { contentDescription = }` |

Adapter kodu tamamen silinir — DiffUtil'in yerini `key` alır.

### Adım 6 — Eşdeğerliği doğrula

Adım 1'deki listeyi tek tek geç. Özellikle unutulanlar:
- **Sistem geri tuşu** davranışı (`BackHandler`)
- **Klavye** davranışı: `imePadding()`, odak sırası, "Done" aksiyonu
- **Konfigürasyon değişimi**: döndürme sonrası scroll pozisyonu ve form içeriği
- **Process death**: `rememberSaveable` / `SavedStateHandle`
- **Erişilebilirlik**: TalkBack ile gezinti, XML'deki `contentDescription`'lar taşındı mı
- **Analytics**: XML'de gönderilen her event Compose'da da gönderiliyor mu
- **Deep link** girişleri

### Adım 7 — Temizlik

Migration PR'ında sil:
- `fragment_order_list.xml` ve alt layout'ları
- `OrderListAdapter`, `OrderViewHolder`, `OrderDiffCallback`
- Yalnızca bu ekranın kullandığı `drawable`/`style` kaynakları
- ViewBinding referansları

Silmezsen ölü kod birikir ve bir sonraki geliştirici hangisinin canlı olduğunu bilemez.

---

## Riskler ve Azaltma

| Risk | Azaltma |
|---|---|
| Davranış sessizce değişti | Adım 1 listesi + mevcut UI testinin geçmesi |
| Performans gerilemesi | Öncesi/sonrası `FrameTimingMetric` ölçümü (`android-performance`) |
| Tema tutarsızlığı (XML tema ≠ Compose tema) | `AppTheme` XML `Theme.MaterialComponents` değerlerinden türetilsin |
| Karma ekranda çift tema | Geçiş süresince tek renk kaynağı: XML renkleri Compose token'larına maplensin |
| Büyük PR | Ekran başına bir PR; 400 satırı geçerse ekranı da böl |

Geri dönüş planı: migration ekran bazlı olduğu için `git revert` tek PR'ı geri alır.
Bu yüzden **bir PR'da birden fazla ekran taşıma.**

---

## Checklist

- [ ] Taşımadan önce mevcut davranış maddeler halinde yazıldı
- [ ] Migration sırasında davranış/özellik değişikliği yapılmadı
- [ ] `ComposeView`'da `setViewCompositionStrategy` verildi
- [ ] Dağınık LiveData'lar tek `UiState`'e toplandı, türev state ayrı tutulmadı
- [ ] Projedeki mevcut base ViewModel / MVI deseni kullanıldı
- [ ] `LazyColumn` item'larında `key` var
- [ ] Geri tuşu, klavye, döndürme, process death doğrulandı
- [ ] Erişilebilirlik etiketleri taşındı, TalkBack ile denendi
- [ ] Analytics event'leri birebir korundu ve ViewModel'den gönderiliyor
- [ ] Eski XML, adapter ve kullanılmayan kaynaklar silindi
- [ ] Performans öncesi/sonrası ölçüldü
- [ ] PR tek ekran kapsıyor
