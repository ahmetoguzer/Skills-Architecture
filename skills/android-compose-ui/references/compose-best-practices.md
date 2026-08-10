# Jetpack Compose Best Practices

## Recomposition'ı Anlamak

Compose'un en önemli performans prensibi: **sadece değişen composable'lar recompose edilir**.
Bunu bozan durumları bil ve önle.

---

## Stability ve @Stable

Compose, parametrelerin değişip değişmediğini bilmek için **stability** kullanır.

```kotlin
// YANLIŞ — List<T> unstable, her recomposition'da farklı olarak değerlendirilir
@Composable
fun ProductList(products: List<Product>) { ... }

// DOĞRU — ImmutableList stable olarak işaretlenmiş
@Composable
fun ProductList(products: ImmutableList<Product>) { ... }

// veya — data class'ı @Stable ile işaretle
@Stable
data class ProductUiModel(
    val id: String,
    val name: String,
    val price: String
)
```

Alternatif: `kotlinx.collections.immutable` kütüphanesi:
```kotlin
val products: ImmutableList<Product> = persistentListOf(...)
```

---

## Lambda Referansları

```kotlin
// YANLIŞ — her recomposition'da yeni lambda instance oluşur
@Composable
fun ProductCard(product: Product, viewModel: ProductViewModel) {
    Button(onClick = { viewModel.onProductClick(product.id) }) { ... }
}

// DOĞRU — remember ile stabilize et
@Composable
fun ProductCard(product: Product, onProductClick: (String) -> Unit) {
    Button(onClick = { onProductClick(product.id) }) { ... }
}

// ViewModel'da:
val onProductClick: (String) -> Unit = remember { viewModel::onProductClick }
```

---

## State Hoisting

State her zaman **yukarıya kaldırılır** (hoisted). Bu composable'ları reusable ve test edilebilir yapar.

```kotlin
// YANLIŞ — state composable içinde sıkışmış
@Composable
fun SearchBar() {
    var query by remember { mutableStateOf("") }
    TextField(value = query, onValueChange = { query = it })
}

// DOĞRU — state hoisted
@Composable
fun SearchBar(
    query: String,
    onQueryChange: (String) -> Unit,
    modifier: Modifier = Modifier
) {
    TextField(value = query, onValueChange = onQueryChange, modifier = modifier)
}

// Kullanım
@Composable
fun SearchScreen(viewModel: SearchViewModel = hiltViewModel()) {
    val query by viewModel.query.collectAsStateWithLifecycle()
    SearchBar(query = query, onQueryChange = viewModel::onQueryChange)
}
```

---

## LazyList Performansı

```kotlin
LazyColumn {
    items(
        items = products,
        key = { product -> product.id }  // key şart! recomposition'ı optimize eder
    ) { product ->
        ProductCard(product = product)
    }
}
```

`key` olmadan Compose liste elemanlarını position'a göre track eder — öğe silinip eklendiğinde yanlış animasyonlar çıkar.

---

## derivedStateOf

Bir state'i başka bir state'ten türetiyorsan:

```kotlin
// YANLIŞ — her recomposition'da hesaplanır
@Composable
fun CartScreen(items: List<CartItem>) {
    val total = items.sumOf { it.price * it.quantity }  // her seferinde
    Text("Toplam: $total")
}

// DOĞRU — sadece items değişince yeniden hesaplanır
@Composable
fun CartScreen(items: List<CartItem>) {
    val total by remember(items) {
        derivedStateOf { items.sumOf { it.price * it.quantity } }
    }
    Text("Toplam: $total")
}
```

---

## Modifier Sırası Önemlidir

```kotlin
// YANLIŞ — padding tıklanabilir alanın dışında kalır
Box(
    modifier = Modifier
        .clickable { }
        .padding(16.dp)
)

// DOĞRU — padding tıklanabilir alana dahil
Box(
    modifier = Modifier
        .padding(16.dp)
        .clickable { }
)
```

Genel kural: `padding` → `clickable` → `size` sırası çoğu durumda mantıklıdır.

---

## Compose Preview Stratejisi

```kotlin
// Multi-preview annotation
@Preview(name = "Light Mode", uiMode = Configuration.UI_MODE_NIGHT_NO)
@Preview(name = "Dark Mode", uiMode = Configuration.UI_MODE_NIGHT_YES)
@Preview(name = "Large Font", fontScale = 1.5f)
annotation class ThemePreviews

@ThemePreviews
@Composable
private fun ProductCardPreview() {
    AppTheme {
        ProductCard(
            product = ProductUiModel(
                id = "1",
                name = "Örnek Ürün",
                price = "₺299"
            ),
            onProductClick = {}
        )
    }
}
```

Preview'da **hiç ViewModel kullanma** — bu zaten stateless Content composable'ı kullanmanın ödülü.

---

## Side Effects Rehberi

| Effect | Ne zaman kullan |
|--------|-----------------|
| `LaunchedEffect(key)` | Key değişince coroutine başlat (navigation, network call) |
| `rememberCoroutineScope()` | User event'te (onClick) coroutine başlat |
| `DisposableEffect` | Lifecycle'a bağlı kaynakları temizle (listener kaydet/kaldır) |
| `SideEffect` | Her successful recomposition'da non-Compose koda state bildir |
| `produceState` | Non-Compose kaynakları State'e dönüştür |

```kotlin
// LaunchedEffect örneği — SharedFlow effect'leri dinle
LaunchedEffect(Unit) {
    viewModel.effects.collect { effect ->
        when (effect) {
            is UiEffect.Navigate -> navController.navigate(effect.route)
            is UiEffect.ShowSnackbar -> snackbarHostState.showSnackbar(effect.message)
        }
    }
}
```

---

## Compose Testing

```kotlin
class ProductCardTest {
    @get:Rule
    val composeTestRule = createComposeRule()

    @Test
    fun `product card shows name and price`() {
        val product = ProductUiModel(id = "1", name = "Test Ürün", price = "₺100")

        composeTestRule.setContent {
            AppTheme {
                ProductCard(product = product, onProductClick = {})
            }
        }

        composeTestRule.onNodeWithText("Test Ürün").assertIsDisplayed()
        composeTestRule.onNodeWithText("₺100").assertIsDisplayed()
    }

    @Test
    fun `clicking product card calls onProductClick with correct id`() {
        var clickedId = ""
        val product = ProductUiModel(id = "42", name = "Test", price = "₺0")

        composeTestRule.setContent {
            ProductCard(product = product, onProductClick = { clickedId = it })
        }

        composeTestRule.onNodeWithText("Test").performClick()
        assertThat(clickedId).isEqualTo("42")
    }
}
```
