---
name: feature-scaffold
description: >
  Domain + data + UI katmanlarını kapsayan yeni bir feature'ı sıfırdan iskeletleyen skill:
  modül oluşturma, paket yapısı, model/UseCase/Repository/DataSource/ViewModel/Screen dosyaları,
  Hilt binding'leri, navigasyon kaydı ve test iskeleti — hepsi tutarlı isimlendirmeyle.

  Şu isteklerde tetiklen: "yeni feature ekle", "X ekranı oluştur", "sıfırdan modül kur",
  "feature scaffold", "boilerplate oluştur", "yeni bir akış ekleyeceğiz", "X özelliğini ekle".
  Sadece tek dosya/ekran değişikliğiyse android-compose-ui'ye devret.
---

# Feature Scaffold Skill

Sen feature iskeleti kuran mimarsın. Amacın **tutarlılık**: aynı isimlendirme, aynı paket
yapısı, aynı dosya sırası. Yeni feature, projedeki diğerlerinden ayırt edilemez olmalı.

## Önce Bak, Sonra Yaz

Kod üretmeden önce mevcut bir feature modülünü **oku ve deseni kopyala**:

```bash
ls feature/                                  # mevcut feature'lar
find feature/<en-yeni-feature> -name "*.kt" | head -30
cat feature/<en-yeni-feature>/build.gradle.kts
```

Projenin kendi konvansiyonu bu skill'deki jenerik örnekten **her zaman önceliklidir**.
Base sınıf varsa (`ComposeBaseViewModel`, `BaseUseCase`), string yönetimi özelse
(`ContentManager.getValue(...)`), dispatcher qualifier'ı farklıysa — onları kullan.

---

## Dosya Haritası

Bir feature (`orders` örneği) şu dosyalara dokunur:

```
core/domain/src/main/kotlin/.../orders/
├── model/Order.kt                       ← domain modeli, non-null, doğrulanmış
├── repository/OrderRepository.kt        ← arayüz (implementasyon yok)
└── usecase/
    ├── GetOrdersUseCase.kt
    └── RefreshOrdersUseCase.kt

core/data/src/main/kotlin/.../orders/
├── remote/
│   ├── OrderApi.kt
│   └── dto/OrderDto.kt
├── local/
│   ├── OrderDao.kt
│   └── entity/OrderEntity.kt
├── mapper/OrderMapper.kt
├── repository/OrderRepositoryImpl.kt
└── di/OrderDataModule.kt                ← @Binds / @Provides

feature/orders/src/main/kotlin/.../
├── list/
│   ├── OrderListScreen.kt               ← Screen (stateful) + Content (stateless)
│   ├── OrderListViewModel.kt
│   └── OrderListUiState.kt              ← State (+ Event/Effect, MVI ise)
├── component/OrderRow.kt
└── navigation/OrdersNavigation.kt       ← route + NavGraphBuilder extension

feature/orders/src/test/kotlin/.../
├── OrderListViewModelTest.kt
└── ...
```

**Yazma sırası: domain → data → UI.** Ters sırada yazarsan UI, henüz olmayan bir
domain modelini uydurur ve sonradan uyumsuzluk çıkar.

---

## 1. Domain

```kotlin
// model/Order.kt — Android import'u YOK
data class Order(
    val id: String,
    val number: String,
    val total: Money,
    val status: OrderStatus,
    val createdAt: Instant,
)

enum class OrderStatus { PENDING, SHIPPED, DELIVERED, CANCELLED }

// repository/OrderRepository.kt
interface OrderRepository {
    fun observeOrders(): Flow<List<Order>>
    suspend fun refreshOrders(): Result<Unit>
}

// usecase/GetOrdersUseCase.kt
class GetOrdersUseCase @Inject constructor(
    private val repository: OrderRepository,
) {
    operator fun invoke(): Flow<List<Order>> = repository.observeOrders()
}
```

UseCase tek sorumluluk taşır. "Get + filter + sort" yapıyorsa ya adı bunu söylemeli
(`GetActiveOrdersSortedByDateUseCase` — kötü koku) ya da ayrılmalı.

---

## 2. Data

```kotlin
// di/OrderDataModule.kt
@Module
@InstallIn(SingletonComponent::class)
abstract class OrderDataModule {

    @Binds
    @Singleton
    abstract fun bindOrderRepository(impl: OrderRepositoryImpl): OrderRepository

    companion object {
        @Provides
        @Singleton
        fun provideOrderApi(retrofit: Retrofit): OrderApi = retrofit.create()

        @Provides
        fun provideOrderDao(db: AppDatabase): OrderDao = db.orderDao()
    }
}
```

Repository implementasyonu, mapper'lar ve SSOT akışı için `android-data-layer` skill'ini yükle.

---

## 3. UI

```kotlin
// OrderListUiState.kt
data class OrderListUiState(
    val isLoading: Boolean = false,
    val isRefreshing: Boolean = false,
    val orders: List<Order> = emptyList(),
    val error: String? = null,
)

// OrderListViewModel.kt
@HiltViewModel
class OrderListViewModel @Inject constructor(
    getOrders: GetOrdersUseCase,
    private val refreshOrders: RefreshOrdersUseCase,
) : ViewModel() {

    val uiState: StateFlow<OrderListUiState> = getOrders()
        .map { OrderListUiState(orders = it) }
        .catch { emit(OrderListUiState(error = it.toUserMessage())) }
        .stateIn(
            scope = viewModelScope,
            started = SharingStarted.WhileSubscribed(5_000),
            initialValue = OrderListUiState(isLoading = true),
        )

    fun onRefresh() = viewModelScope.launch { refreshOrders() }
}
```

Ekran ve preview yapısı için `android-compose-ui` skill'ini yükle.

---

## 4. Navigasyon

```kotlin
// navigation/OrdersNavigation.kt
@Serializable data object OrderListRoute
@Serializable data class OrderDetailRoute(val orderId: String)

fun NavGraphBuilder.ordersGraph(
    onOrderClick: (String) -> Unit,
    onBack: () -> Unit,
) {
    composable<OrderListRoute> {
        OrderListScreen(onOrderClick = onOrderClick)
    }
    composable<OrderDetailRoute> { entry ->
        OrderDetailScreen(orderId = entry.toRoute<OrderDetailRoute>().orderId, onBack = onBack)
    }
}
```

Route tanımları feature modülünde durur; navigasyon **kararı** `:app` composition root'unda verilir.
Feature'lar birbirini doğrudan çağırmaz.

---

## 5. Modül Tanımı

```kotlin
// feature/orders/build.gradle.kts
plugins {
    id("myapp.android.feature")
    id("myapp.android.compose")
    id("myapp.android.hilt")
}

android { namespace = "com.example.feature.orders" }

dependencies {
    implementation(projects.core.domain)
    implementation(projects.core.designsystem)
    testImplementation(projects.core.testing)
}
```

`settings.gradle.kts`'e `include(":feature:orders")` eklemeyi unutma.
`:feature:*` modülü **`:core:data`'ya bağımlı olmaz** — sadece `:core:domain`.

---

## 6. Test İskeleti

Her katman için en az bir test dosyası oluştur — boş bırakma, ilk testi yaz:

```
core/domain/src/test/.../GetOrdersUseCaseTest.kt
core/data/src/test/.../OrderRepositoryImplTest.kt
core/data/src/test/.../OrderMapperTest.kt
feature/orders/src/test/.../OrderListViewModelTest.kt
```

Detay için `android-testing`.

---

## İsimlendirme Kuralları

| Tip | Kalıp | Örnek |
|---|---|---|
| Domain model | isim, tekil | `Order` |
| DTO | `<Model>Dto` | `OrderDto` |
| Entity | `<Model>Entity` | `OrderEntity` |
| Repository arayüzü | `<Model>Repository` | `OrderRepository` |
| Repository impl | `<Model>RepositoryImpl` | `OrderRepositoryImpl` |
| UseCase | `<Fiil><Nesne>UseCase` | `RefreshOrdersUseCase` |
| ViewModel | `<Ekran>ViewModel` | `OrderListViewModel` |
| State | `<Ekran>UiState` | `OrderListUiState` |
| Screen | `<Ekran>Screen` + `<Ekran>Content` | `OrderListScreen` |
| Hilt modülü | `<Alan><Katman>Module` | `OrderDataModule` |

---

## Scaffold Checklist

- [ ] Mevcut bir feature modülü örnek alınarak desen kopyalandı
- [ ] Yazma sırası domain → data → UI olarak izlendi
- [ ] `:core:domain`'de Android import'u yok
- [ ] `:feature:*` sadece `:core:domain`'e bağımlı, `:core:data`'ya değil
- [ ] Hilt binding'leri yazıldı, `@Binds` tercih edildi
- [ ] Route tanımları feature modülünde, navigasyon kararı `:app`'te
- [ ] `settings.gradle.kts`'e modül eklendi
- [ ] Her katman için en az bir gerçek test yazıldı
- [ ] İsimlendirme tablosuna uyuldu
- [ ] Modül derleniyor: `./gradlew :feature:orders:assembleDebug`
