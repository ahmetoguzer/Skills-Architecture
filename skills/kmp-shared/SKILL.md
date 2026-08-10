---
name: kmp-shared
description: >
  Kotlin Multiplatform (KMP) uzmanlığı: Android + iOS ortak modül tasarımı, expect/actual,
  source set hiyerarşisi, Ktor/SQLDelight/koin ile multiplatform data katmanı,
  coroutines-Swift köprüsü (SKIE / suspend fonksiyon export), Compose Multiplatform kararı,
  mevcut Android projesine kademeli KMP entegrasyonu.

  Şu isteklerde tetiklen: "Kotlin Multiplatform", "KMP", "iOS ile kod paylaş",
  "expect actual", "shared module", "commonMain", "Compose Multiplatform", "CMP",
  "SQLDelight", "Ktor client", "cocoapods entegrasyonu", "XCFramework", "SKIE",
  "iOS'ta da çalışsın", "tek kod tabanı".
---

# Kotlin Multiplatform Shared Skill

Sen KMP mimarısın. En önemli katkın **ne paylaşılmalı, ne paylaşılmamalı** kararını doğru vermek.
Her şeyi paylaşmaya çalışan KMP projeleri, iki ayrı native projeden daha pahalı hale gelir.

## Paylaşım Sınırı

| Katman | Paylaş? | Gerekçe |
|---|---|---|
| Domain (model, use case, business rule) | **Evet, her zaman** | Platformdan tamamen bağımsız, en yüksek getiri |
| Data (API client, cache, mapper) | **Evet** | Ktor + SQLDelight olgun; tekrar eden kodun çoğu burada |
| Presentation (ViewModel/state) | Duruma göre | Paylaşılabilir ama iOS ekibinin SwiftUI alışkanlığını bozar |
| UI | Genelde hayır | Compose Multiplatform iOS'ta artık stable, ama platform hissi ve ekip yetkinliği belirleyici |
| Platform API (kamera, bildirim, biyometrik) | Hayır | `expect/actual` ile ince arayüz, implementasyon native |

**Önerim:** Domain + data ile başla. Bu bile tipik olarak kodun %40-60'ını paylaşır ve
iOS ekibini rahatsız etmez. Presentation'ı ancak ekip istekliyse ekle.

---

## 1. Modül Yapısı

```
shared/
├── build.gradle.kts
└── src/
    ├── commonMain/kotlin/      → domain + data, platformdan bağımsız
    ├── commonTest/kotlin/
    ├── androidMain/kotlin/     → actual implementasyonlar (Context gerektirenler)
    ├── iosMain/kotlin/         → actual implementasyonlar (NSUserDefaults, Keychain)
    └── iosTest/kotlin/
androidApp/                     → Compose UI
iosApp/                         → SwiftUI UI
```

### build.gradle.kts

```kotlin
plugins {
    alias(libs.plugins.kotlinMultiplatform)
    alias(libs.plugins.androidLibrary)
    alias(libs.plugins.kotlinSerialization)
    alias(libs.plugins.sqldelight)
}

kotlin {
    androidTarget {
        compilerOptions.jvmTarget.set(JvmTarget.JVM_17)
    }

    listOf(iosX64(), iosArm64(), iosSimulatorArm64()).forEach { target ->
        target.binaries.framework {
            baseName = "Shared"
            isStatic = true          // dynamic'e göre daha hızlı başlangıç
        }
    }

    sourceSets {
        commonMain.dependencies {
            implementation(libs.kotlinx.coroutines.core)
            implementation(libs.kotlinx.serialization.json)
            implementation(libs.ktor.client.core)
            implementation(libs.ktor.client.content.negotiation)
            implementation(libs.sqldelight.runtime)
            implementation(libs.koin.core)
        }
        androidMain.dependencies {
            implementation(libs.ktor.client.okhttp)
            implementation(libs.sqldelight.android.driver)
        }
        iosMain.dependencies {
            implementation(libs.ktor.client.darwin)
            implementation(libs.sqldelight.native.driver)
        }
        commonTest.dependencies {
            implementation(libs.kotlin.test)
            implementation(libs.turbine)
            implementation(libs.ktor.client.mock)
        }
    }
}
```

---

## 2. expect / actual — Dar Tut

Kural: `expect` bildirimleri **mümkün olduğunca az ve küçük** olmalı.
Büyük expect yüzeyi = iki kez yazılan kod.

```kotlin
// commonMain
expect class KeyValueStore {
    fun putString(key: String, value: String)
    fun getString(key: String): String?
}

// androidMain
actual class KeyValueStore(private val prefs: SharedPreferences) {
    actual fun putString(key: String, value: String) = prefs.edit { putString(key, value) }
    actual fun getString(key: String): String? = prefs.getString(key, null)
}

// iosMain
actual class KeyValueStore(private val defaults: NSUserDefaults = NSUserDefaults.standardUserDefaults) {
    actual fun putString(key: String, value: String) = defaults.setObject(value, key)
    actual fun getString(key: String): String? = defaults.stringForKey(key)
}
```

**Alternatif (çoğu zaman daha iyi):** `expect class` yerine `commonMain`'de bir **interface**
tanımla, implementasyonu DI ile platform tarafından enjekte et. Test etmesi çok daha kolaydır.

---

## 3. Ktor Client

```kotlin
// commonMain
class ApiClient(engine: HttpClientEngine, private val baseUrl: String) {
    private val client = HttpClient(engine) {
        install(ContentNegotiation) {
            json(Json { ignoreUnknownKeys = true; isLenient = true })
        }
        install(HttpTimeout) { requestTimeoutMillis = 30_000 }
        install(Logging) { level = LogLevel.HEADERS }
    }

    suspend fun getProducts(): List<ProductDto> =
        client.get("$baseUrl/products").body()
}
```

Engine'i inject et — testte `MockEngine`, Android'de `OkHttp`, iOS'ta `Darwin`.

---

## 4. Suspend / Flow'u Swift'e Açmak

Ham KMP çıktısı Swift'te completion handler'a dönüşür ve `Flow` doğrudan kullanılamaz.
İki seçenek:

**A) SKIE plugin (önerilen)** — `suspend` fonksiyonlar Swift `async`'e, `Flow` `AsyncSequence`'a dönüşür:

```kotlin
plugins { id("co.touchlab.skie") version "0.10.1" }
```

```swift
let products = try await repository.getProducts()
for await state in viewModel.state {  }
```

**B) Elle wrapper** — `CFlow`/`Cancellable` sınıfı yazıp Flow'u callback'e çevir.
SKIE yokken kabul edilebilir ama bakım maliyeti yüksek.

Ayrıca: `sealed class`'lar Swift'te exhaustive `switch` olarak gelmez (SKIE bunu da düzeltir),
`Int?` gibi nullable primitive'ler `KotlinInt?` olarak export edilir — public API'de bundan kaçın.

---

## 5. Paylaşılan ViewModel (opsiyonel)

```kotlin
// commonMain — androidx.lifecycle:lifecycle-viewmodel 2.8+ KMP destekli
class ProductListViewModel(
    private val getProducts: GetProductsUseCase,
) : ViewModel() {
    private val _state = MutableStateFlow(ProductListState())
    val state: StateFlow<ProductListState> = _state.asStateFlow()

    fun load() = viewModelScope.launch {
        _state.update { it.copy(isLoading = true) }
        getProducts().fold(
            onSuccess = { items -> _state.update { it.copy(isLoading = false, products = items) } },
            onFailure = { e -> _state.update { it.copy(isLoading = false, error = e.message) } },
        )
    }
}
```

iOS tarafında `@Observable` bir wrapper ile SwiftUI'ye bağla — `state`'i `AsyncSequence` olarak dinle.

---

## 6. Mevcut Android Projesine Kademeli Geçiş

1. `:shared` modülünü ekle, sadece `androidTarget` ile başlat (iOS target yok)
2. Domain modellerini ve use case'leri `commonMain`'e taşı — Android uygulaması bozulmamalı
3. Data katmanını Retrofit → Ktor, Room → SQLDelight olarak taşı (en emek isteyen adım)
4. iOS target'larını ekle, derlenmeyenleri `expect/actual` ile çöz
5. iOS uygulamasını XCFramework'ü tüketecek şekilde bağla

Her adımda Android uygulaması çalışır durumda kalmalı. "Big bang" KMP migrasyonu yapma.

---

## Checklist

- [ ] `commonMain`'de platform API'si yok (`java.*`, `platform.*` import'u yok)
- [ ] `expect` yüzeyi minimum; mümkün olan yerde interface + DI kullanılmış
- [ ] Framework `isStatic = true` (özel bir sebep yoksa)
- [ ] SKIE veya eşdeğeri ile suspend/Flow Swift'e düzgün export ediliyor
- [ ] Public API'de nullable primitive ve derin sealed hiyerarşi yok
- [ ] `commonTest` gerçek testler içeriyor; test sadece Android'de koşmuyor
- [ ] iOS build CI'da doğrulanıyor (macOS runner)
- [ ] iOS ekibi Swift API'nin şeklini gözden geçirmiş
