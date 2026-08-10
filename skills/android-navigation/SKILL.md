---
name: android-navigation
last_reviewed: 2026-08
description: >
  Compose navigasyon mimarisi: type-safe route'lar (@Serializable), nav graph tasarımı,
  nested graph ve modüller arası navigasyon, deep link / App Links, argüman ve sonuç geçişi,
  back stack yönetimi, adaptive (list-detail) navigasyon ve navigasyon testi.

  Şu isteklerde tetiklen: "navigation", "navigasyon", "ekranlar arası geçiş", "NavHost",
  "route tanımla", "deep link", "app link", "argüman geçir", "geri dönünce sonuç al",
  "back stack", "bottom navigation", "nested graph", "Navigation 3", "type-safe route",
  "modüller arası geçiş".
---

# Android Navigation Skill

Sen navigasyon mimarısın. Temel kuralın: **feature'lar birbirini tanımaz.**
Navigasyon kararı composition root'ta (`:app`) verilir; feature yalnızca
"bir şey oldu" der, nereye gidileceğini bilmez.

Bu kural bozulduğunda modüller arasında döngüsel bağımlılık oluşur ve
multi-module yapının tüm faydası kaybolur.

## Sorumluluk Dağılımı

```
:feature:orders          → OrderListRoute tanımı + ordersGraph() extension
                           onOrderClick: (String) -> Unit   ← sadece olayı bildirir
:app                     → NavHost, tüm graph'ları birleştirir,
                           onOrderClick = { navController.navigate(OrderDetailRoute(it)) }
:core:navigation         → (gerekiyorsa) modüller arası paylaşılan route sözleşmeleri
```

Feature A, feature B'nin route sınıfını import etmek zorunda kalıyorsa
o route `:core:navigation`'a taşınır — ya da daha iyisi, callback ile `:app`'e delege edilir.

---

## Type-Safe Route'lar

String route'lar bitti. `@Serializable` sınıflar kullan:

```kotlin
@Serializable data object OrderListRoute

@Serializable data class OrderDetailRoute(val orderId: String)

@Serializable data class SearchRoute(
    val query: String = "",
    val categoryId: String? = null,
)
```

```kotlin
composable<OrderDetailRoute> { entry ->
    val route: OrderDetailRoute = entry.toRoute()
    OrderDetailScreen(orderId = route.orderId)
}

navController.navigate(OrderDetailRoute(orderId = "123"))
```

Kazanç: yazım hatası compile-time'da yakalanır, argüman tipleri korunur,
manuel URL encode/decode yok, opsiyonel argümanlar varsayılan değerle çalışır.

### ViewModel'de argümana erişim

```kotlin
@HiltViewModel
class OrderDetailViewModel @Inject constructor(
    savedStateHandle: SavedStateHandle,
    getOrder: GetOrderUseCase,
) : ViewModel() {
    private val route = savedStateHandle.toRoute<OrderDetailRoute>()

    val uiState = getOrder(route.orderId)
        .map { OrderDetailUiState(order = it) }
        .stateIn(viewModelScope, SharingStarted.WhileSubscribed(5_000), OrderDetailUiState())
}
```

Argümanı composable'dan ViewModel'e parametre olarak geçirme —
`SavedStateHandle` üzerinden oku ki process death sonrası da doğru çalışsın.

---

## Graph Yapısı

```kotlin
// :feature:orders — modülün kendi graph'ı
fun NavGraphBuilder.ordersGraph(
    onOrderClick: (String) -> Unit,
    onBack: () -> Unit,
) {
    composable<OrderListRoute> {
        OrderListScreen(onOrderClick = onOrderClick)
    }
    composable<OrderDetailRoute> {
        OrderDetailScreen(onBack = onBack)
    }
}

// :app — kararlar burada
@Composable
fun AppNavHost(navController: NavHostController) {
    NavHost(navController, startDestination = HomeRoute) {
        homeGraph(
            onOrdersClick = { navController.navigate(OrderListRoute) },
        )
        ordersGraph(
            onOrderClick = { navController.navigate(OrderDetailRoute(it)) },
            onBack = navController::popBackStack,
        )
        profileGraph(
            onLogout = {
                navController.navigate(LoginRoute) {
                    popUpTo(0) { inclusive = true }    // tüm back stack temizlenir
                }
            },
        )
    }
}
```

### Nested graph (çok adımlı akış)

```kotlin
@Serializable data object CheckoutGraph

navigation<CheckoutGraph>(startDestination = CartRoute) {
    composable<CartRoute> { ... }
    composable<AddressRoute> { ... }
    composable<PaymentRoute> { ... }
}
```

Akış boyunca paylaşılan state için graph-scoped ViewModel:

```kotlin
@Composable
fun rememberCheckoutViewModel(entry: NavBackStackEntry, navController: NavController): CheckoutViewModel {
    val parentEntry = remember(entry) { navController.getBackStackEntry(CheckoutGraph) }
    return hiltViewModel(parentEntry)
}
```

Bu ViewModel graph'tan çıkılınca temizlenir — Activity-scoped ViewModel kullanma,
akış yarıda bırakılıp tekrar girildiğinde eski veri sızar.

---

## Back Stack Yönetimi

```kotlin
// Login sonrası: login'e geri dönülemesin
navController.navigate(HomeRoute) {
    popUpTo(LoginRoute) { inclusive = true }
}

// Bottom nav: sekmeler arası geçişte stack birikmesin, state korunsun
navController.navigate(route) {
    popUpTo(navController.graph.findStartDestination().id) { saveState = true }
    launchSingleTop = true
    restoreState = true
}

// Çift tıklamada iki kez navigate olmasın
navController.navigate(route) { launchSingleTop = true }
```

`launchSingleTop` olmadan hızlı çift tıklama aynı ekranı iki kez açar —
kullanıcı iki kez geri tuşuna basmak zorunda kalır. Bu, en sık gözden kaçan navigasyon bug'ıdır.

---

## Sonuç Döndürme

Önceki ekrana veri döndürmenin doğru yolu — `SavedStateHandle` **değil**, akış yönü korunmalı:

```kotlin
// Yaklaşım 1 (tercih edilen): paylaşılan state'i repository/graph ViewModel'de tut
// Seçim ekranı repository'yi günceller, liste ekranı Flow'dan okur.

// Yaklaşım 2: back stack entry üzerinden (basit tek seferlik seçimler için)
// Seçim ekranı:
navController.previousBackStackEntry
    ?.savedStateHandle
    ?.set("selected_address_id", addressId)
navController.popBackStack()

// Dinleyen ekran:
val entry = navController.currentBackStackEntry
LaunchedEffect(entry) {
    entry?.savedStateHandle?.getStateFlow<String?>("selected_address_id", null)
        ?.filterNotNull()
        ?.collect { id ->
            viewModel.onAddressSelected(id)
            entry.savedStateHandle["selected_address_id"] = null   // tüket ve temizle
        }
}
```

Tüketmeyi unutursan aynı sonuç ekrana her dönüşte tekrar işlenir.

---

## Deep Link / App Links

```kotlin
composable<OrderDetailRoute>(
    deepLinks = listOf(
        navDeepLink<OrderDetailRoute>(basePath = "https://example.com/orders")
    ),
) { ... }
```

```xml
<intent-filter android:autoVerify="true">
    <action android:name="android.intent.action.VIEW" />
    <category android:name="android.intent.category.DEFAULT" />
    <category android:name="android.intent.category.BROWSABLE" />
    <data android:scheme="https" android:host="example.com" android:pathPrefix="/orders" />
</intent-filter>
```

Kritik noktalar:
- `assetlinks.json` sunucuda `https://example.com/.well-known/assetlinks.json` yolunda
  yayınlanmalı; yoksa `autoVerify` sessizce başarısız olur ve link tarayıcıda açılır
- Doğrulama: `adb shell pm verify-app-links --re-verify <paket>` ve
  `adb shell dumpsys package domain-preferred-apps`
- **Gelen her deep link parametresi doğrulanmamış girdidir** — id formatını kontrol et,
  yetki kontrolünü ekranda yap (`android-security`)
- Ön koşul gerektiren ekranlara (checkout, profil) gelen deep link'i bir
  yönlendirme katmanından geçir; koşul sağlanmıyorsa uygun ekrana düşür
- Test: `adb shell am start -a android.intent.action.VIEW -d "https://example.com/orders/123"`

---

## Adaptive Navigasyon (list-detail)

Tablet ve foldable'da liste ve detay yan yana durur; telefonda ayrı ekranlardır.
Bunu iki ayrı NavHost ile çözme — tek kaynak kullan:

```kotlin
val scaffoldNavigator = rememberListDetailPaneScaffoldNavigator<String>()

NavigableListDetailPaneScaffold(
    navigator = scaffoldNavigator,
    listPane = {
        OrderListScreen(onOrderClick = { id ->
            scaffoldNavigator.navigateTo(ListDetailPaneScaffoldRole.Detail, id)
        })
    },
    detailPane = {
        scaffoldNavigator.currentDestination?.contentKey?.let { OrderDetailScreen(it) }
    },
)
```

Geri tuşu davranışı pane yapısına göre otomatik ayarlanır — telefonda detaydan listeye,
tablette uygulamadan çıkışa. Detay: `android-adaptive-formfactors`.

---

## Test

```kotlin
@Test
fun `siparise tiklaninca detay ekranina gidilir`() {
    lateinit var navController: TestNavHostController

    composeRule.setContent {
        navController = TestNavHostController(LocalContext.current).apply {
            navigatorProvider.addNavigator(ComposeNavigator())
        }
        AppNavHost(navController)
    }

    composeRule.onNodeWithText("Sipariş #123").performClick()

    val route = navController.currentBackStackEntry?.toRoute<OrderDetailRoute>()
    assertThat(route?.orderId).isEqualTo("123")
}
```

Deep link'leri de test et — en sık kırılan ve en az test edilen yol onlardır.

---

## Checklist

- [ ] Route'lar `@Serializable`, string route yok
- [ ] Feature modülleri birbirinin route'unu import etmiyor; kararlar `:app`'te
- [ ] ViewModel argümanı `SavedStateHandle.toRoute()` ile okuyor
- [ ] Çok adımlı akışlarda graph-scoped ViewModel kullanılıyor
- [ ] Navigasyon çağrılarında `launchSingleTop` var
- [ ] Login/logout akışında back stack doğru temizleniyor
- [ ] Sonuç döndürme tüketiliyor ve temizleniyor
- [ ] Deep link'ler `assetlinks.json` ile doğrulanmış ve adb ile test edilmiş
- [ ] Deep link parametreleri valide ediliyor, ön koşullar kontrol ediliyor
- [ ] Navigasyon akışları için test var
