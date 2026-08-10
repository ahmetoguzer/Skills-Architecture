---
name: android-testing
last_reviewed: 2026-08
description: >
  Android test stratejisi ve test kodu yazma: ViewModel/UseCase/Repository unit testleri,
  Flow testi (Turbine), coroutine testi (runTest, TestDispatcher), Compose UI testi,
  Room ve Retrofit (MockWebServer) testleri, fake vs mock kararı, test coverage stratejisi.

  Şu isteklerde tetiklen: "test yaz", "unit test", "UI test", "ViewModel testi",
  "flow nasıl test edilir", "MockK", "Turbine", "MockWebServer", "test coverage",
  "fake repository", "espresso", "instrumented test", "testler flaky", "TestDispatcher".
---

# Android Testing Skill

Sen test konusunda titiz bir Android engineer'sın. Test yazarken önce **neyin test edilmeye
değer olduğuna** karar ver, sonra kodu yaz. Getter test etmek coverage yükseltir, güven vermez.

## Test Piramidi (Android'e uyarlanmış)

| Katman | Oran | Araç | Ne test edilir |
|---|---|---|---|
| Unit | ~70% | JUnit + MockK + Turbine | UseCase, ViewModel, Mapper, Repository |
| Integration | ~20% | Robolectric, Room in-memory, MockWebServer | DAO, API client, DataStore |
| UI / E2E | ~10% | Compose Test, Espresso | Kritik kullanıcı akışları (login, checkout) |

**Kural:** Bir davranış unit seviyede test edilebiliyorsa UI testine taşıma. UI testleri yavaş ve kırılgandır.

---

## Zorunlu Test Altyapısı

### MainDispatcherRule

```kotlin
@OptIn(ExperimentalCoroutinesApi::class)
class MainDispatcherRule(
    private val dispatcher: TestDispatcher = UnconfinedTestDispatcher(),
) : TestWatcher() {
    override fun starting(description: Description) = Dispatchers.setMain(dispatcher)
    override fun finished(description: Description) = Dispatchers.resetMain()
}
```

`viewModelScope` `Dispatchers.Main` kullanır — bu rule olmadan her ViewModel testi patlar.

### Dispatcher injection

```kotlin
class GetProductsUseCase @Inject constructor(
    private val repository: ProductRepository,
    @IoDispatcher private val ioDispatcher: CoroutineDispatcher,
) {
    suspend operator fun invoke(): Result<List<Product>> =
        withContext(ioDispatcher) { repository.getProducts() }
}
```

Dispatcher'ı **asla** sınıf içinde `Dispatchers.IO` diye sabitleme — test edilemez hale gelir.

---

## ViewModel Testi

```kotlin
class ProductListViewModelTest {

    @get:Rule val mainDispatcherRule = MainDispatcherRule()

    private val getProducts = mockk<GetProductsUseCase>()
    private lateinit var viewModel: ProductListViewModel

    @Test
    fun `başarılı yüklemede state products ile dolar`() = runTest {
        val products = listOf(fakeProduct(id = "1"))
        coEvery { getProducts() } returns Result.success(products)

        viewModel = ProductListViewModel(getProducts)

        viewModel.uiState.test {
            val state = awaitItem()
            assertThat(state.isLoading).isFalse()
            assertThat(state.products).isEqualTo(products)
            cancelAndIgnoreRemainingEvents()
        }
    }

    @Test
    fun `hata durumunda kullanıcıya mesaj gösterilir`() = runTest {
        coEvery { getProducts() } returns Result.failure(NetworkException())

        viewModel = ProductListViewModel(getProducts)

        viewModel.uiState.test {
            assertThat(awaitItem().error).isEqualTo("İnternet bağlantısı yok")
            cancelAndIgnoreRemainingEvents()
        }
    }
}
```

Test isimleri backtick içinde ve **davranışı** anlatır: `when X then Y`, "X olduğunda Y olur".

---

## Flow Testi — Turbine

```kotlin
@Test
fun `arama debounce sonrası tek istek atar`() = runTest {
    viewModel.state.test {
        awaitItem()                       // initial
        viewModel.onQueryChange("a")
        viewModel.onQueryChange("ab")
        viewModel.onQueryChange("abc")

        advanceTimeBy(300)                // debounce süresi
        runCurrent()

        val loaded = expectMostRecentItem()
        assertThat(loaded.results).hasSize(3)
        coVerify(exactly = 1) { searchUseCase("abc") }
    }
}
```

- `awaitItem()` — sıradaki emisyonu bekler
- `expectMostRecentItem()` — ara state'leri atlar, sonuncuyu alır
- `cancelAndIgnoreRemainingEvents()` — test sonunda **her zaman** çağır, yoksa "unconsumed events" hatası
- `turbineScope { }` — birden fazla Flow'u paralel dinlemek için

---

## Fake mi Mock mu?

| Durum | Tercih |
|---|---|
| Repository (state tutar, birden çok testte kullanılır) | **Fake** |
| UseCase (tek çağrı, dönüş değeri önemli) | Mock |
| DataSource (davranışı basit) | Fake |
| Analytics / Logger (sadece çağrıldı mı bakılır) | Mock (`verify`) |

```kotlin
class FakeProductRepository : ProductRepository {
    private val products = MutableStateFlow<List<Product>>(emptyList())
    var shouldFail = false

    fun seed(items: List<Product>) { products.value = items }

    override suspend fun getProducts(): Result<List<Product>> =
        if (shouldFail) Result.failure(NetworkException()) else Result.success(products.value)

    override fun observeProduct(id: String): Flow<Product> =
        products.map { list -> list.first { it.id == id } }
}
```

Fake'ler `:core:testing` modülünde durur, tüm feature modülleri `testImplementation(projects.core.testing)` ile alır.

---

## Room Testi

```kotlin
@RunWith(AndroidJUnit4::class)
class ProductDaoTest {
    private lateinit var db: AppDatabase
    private lateinit var dao: ProductDao

    @Before fun setup() {
        db = Room.inMemoryDatabaseBuilder(
            ApplicationProvider.getApplicationContext(), AppDatabase::class.java
        ).allowMainThreadQueries().build()
        dao = db.productDao()
    }

    @After fun teardown() = db.close()

    @Test fun `insert edilen ürün observe ile gelir`() = runTest {
        dao.insertAll(listOf(productEntity(id = "1")))
        assertThat(dao.observeAll().first()).hasSize(1)
    }
}
```

**Migration testlerini atlama.** `MigrationTestHelper` ile her şema versiyonu arası geçişi test et —
production'da veri kaybı buradan çıkar.

---

## API Testi — MockWebServer

```kotlin
@Test
fun `500 dönerse ServerException fırlatır`() = runTest {
    server.enqueue(MockResponse().setResponseCode(500))

    val result = dataSource.fetchProducts()

    assertThat(result.exceptionOrNull()).isInstanceOf(ServerException::class.java)
}
```

Response JSON'larını `src/test/resources/` altında dosya olarak tut, string literal olarak gömme.

---

## Compose UI Testi

```kotlin
@Test
fun `hata state'inde retry butonu görünür ve tıklanabilir`() {
    var retried = false
    composeRule.setContent {
        AppTheme {
            ProductListContent(
                uiState = ProductListUiState(error = "Hata"),
                onRetry = { retried = true },
                onProductClick = {},
            )
        }
    }

    composeRule.onNodeWithText("Tekrar dene").performClick()
    assertThat(retried).isTrue()
}
```

Her zaman **stateless `Content`** composable'ını test et — ViewModel'li `Screen`'i değil.
Node bulurken metin yerine `testTag` tercih et (lokalizasyon testi kırmaz):
`Modifier.testTag("product_list")` + `onNodeWithTag("product_list")`.

---

## Flaky Test Sebepleri

1. `Dispatchers.IO` hardcode edilmiş → inject et
2. `delay()` gerçek zamanlı çalışıyor → `runTest` + `advanceTimeBy` kullan
3. Turbine'de `cancelAndIgnoreRemainingEvents()` yok
4. Testler arası paylaşılan singleton state → `@Before`'da sıfırla
5. UI testinde `Thread.sleep` → `waitUntil { }` veya idling resource kullan

---

## Checklist

- [ ] Her ViewModel'in en az 3 testi var: success, error, loading
- [ ] Her UseCase'in business rule'ları test edilmiş (happy path + edge case)
- [ ] Dispatcher'lar inject ediliyor, hardcoded değil
- [ ] Fake'ler `:core:testing`'de paylaşılıyor
- [ ] Room migration testleri yazılmış
- [ ] Kritik akışlar (login, ödeme) için 1 adet E2E testi var
- [ ] Test isimleri davranışı anlatıyor, metod adını tekrarlamıyor
