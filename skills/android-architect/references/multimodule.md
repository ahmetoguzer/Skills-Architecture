# Multi-Module Android Project Setup

## Neden Multi-Module?

- **Build süresi**: Değişmeyen modüller tekrar build edilmez (incremental builds)
- **Separation of concerns**: Feature'lar birbirinden izole
- **Ölçeklenebilirlik**: Büyük takımlarda paralel geliştirme
- **Test edilebilirlik**: Her modül bağımsız test edilir

---

## Modül Bağımlılık Grafiği

```
:app
 ├── :feature:home
 ├── :feature:product-detail
 ├── :feature:checkout
 │    └── :domain (tüm feature'lar domain'e bağlıdır)
 ├── :data
 │    └── :domain (data, domain interface'lerini implement eder)
 ├── :core:ui
 ├── :core:network
 ├── :core:database
 ├── :core:navigation
 └── :core:common
```

Yasak bağımlılıklar:
- `:feature:*` → `:data` (asla!)
- `:domain` → herhangi bir Android modülü
- `:core:*` → `:feature:*` veya `:data`

---

## Gradle Version Catalog (libs.versions.toml)

```toml
# gradle/libs.versions.toml
[versions]
kotlin = "2.0.0"
agp = "8.5.0"
compose-bom = "2024.06.00"
hilt = "2.51.1"
room = "2.6.1"
retrofit = "2.11.0"
coroutines = "1.8.1"
lifecycle = "2.8.3"

[libraries]
# Compose
compose-bom = { group = "androidx.compose", name = "compose-bom", version.ref = "compose-bom" }
compose-ui = { group = "androidx.compose.ui", name = "ui" }
compose-material3 = { group = "androidx.compose.material3", name = "material3" }
compose-lifecycle = { group = "androidx.lifecycle", name = "lifecycle-runtime-compose", version.ref = "lifecycle" }

# Hilt
hilt-android = { group = "com.google.dagger", name = "hilt-android", version.ref = "hilt" }
hilt-compiler = { group = "com.google.dagger", name = "hilt-android-compiler", version.ref = "hilt" }
hilt-navigation-compose = { group = "androidx.hilt", name = "hilt-navigation-compose", version = "1.2.0" }

# Room
room-runtime = { group = "androidx.room", name = "room-runtime", version.ref = "room" }
room-ktx = { group = "androidx.room", name = "room-ktx", version.ref = "room" }
room-compiler = { group = "androidx.room", name = "room-compiler", version.ref = "room" }

# Network
retrofit-core = { group = "com.squareup.retrofit2", name = "retrofit", version.ref = "retrofit" }
retrofit-moshi = { group = "com.squareup.retrofit2", name = "converter-moshi", version.ref = "retrofit" }
okhttp-logging = { group = "com.squareup.okhttp3", name = "logging-interceptor", version = "4.12.0" }

# Coroutines
coroutines-android = { group = "org.jetbrains.kotlinx", name = "kotlinx-coroutines-android", version.ref = "coroutines" }

# Testing
junit5 = { group = "org.junit.jupiter", name = "junit-jupiter", version = "5.10.3" }
mockk = { group = "io.mockk", name = "mockk", version = "1.13.12" }
turbine = { group = "app.cash.turbine", name = "turbine", version = "1.1.0" }
coroutines-test = { group = "org.jetbrains.kotlinx", name = "kotlinx-coroutines-test", version.ref = "coroutines" }

[plugins]
android-application = { id = "com.android.application", version.ref = "agp" }
android-library = { id = "com.android.library", version.ref = "agp" }
kotlin-android = { id = "org.jetbrains.kotlin.android", version.ref = "kotlin" }
kotlin-compose = { id = "org.jetbrains.kotlin.plugin.compose", version.ref = "kotlin" }
hilt = { id = "com.google.dagger.hilt.android", version.ref = "hilt" }
ksp = { id = "com.google.devtools.ksp", version = "2.0.0-1.0.23" }
room = { id = "androidx.room", version.ref = "room" }

[bundles]
compose = ["compose-ui", "compose-material3", "compose-lifecycle"]
testing = ["junit5", "mockk", "turbine", "coroutines-test"]
```

---

## Convention Plugins (Build Logic)

Tüm modüllerde tekrar eden Gradle konfigürasyonunu `build-logic` modülüne taşı:

```
build-logic/
└── convention/
    └── src/main/kotlin/
        ├── AndroidLibraryConventionPlugin.kt
        ├── AndroidFeatureConventionPlugin.kt
        ├── HiltConventionPlugin.kt
        └── ComposeConventionPlugin.kt
```

### AndroidFeatureConventionPlugin.kt

```kotlin
class AndroidFeatureConventionPlugin : Plugin<Project> {
    override fun apply(target: Project) {
        with(target) {
            with(pluginManager) {
                apply("myapp.android.library")
                apply("myapp.android.hilt")
            }
            extensions.configure<LibraryExtension> {
                // Feature'lara özgü config
            }
            dependencies {
                add("implementation", project(":domain"))
                add("implementation", project(":core:common"))
                add("implementation", project(":core:ui"))
                add("implementation", project(":core:navigation"))
            }
        }
    }
}
```

### Feature modülü build.gradle.kts

```kotlin
plugins {
    alias(libs.plugins.myapp.android.feature)    // convention plugin
    alias(libs.plugins.myapp.android.compose)   // convention plugin
}

android {
    namespace = "com.myapp.feature.checkout"
}

dependencies {
    // Sadece feature-specific ek bağımlılıklar buraya
}
```

---

## Navigation Multi-Module

### :core:navigation

```kotlin
sealed class Screen(val route: String) {
    data object Home : Screen("home")
    data class ProductDetail(val productId: String) : Screen("product/{productId}") {
        fun createRoute() = "product/$productId"
    }
    data object Checkout : Screen("checkout")
}
```

### :app modülünde NavGraph

```kotlin
@Composable
fun AppNavGraph(
    navController: NavHostController = rememberNavController()
) {
    NavHost(navController, startDestination = Screen.Home.route) {
        homeGraph(
            onProductClick = { id ->
                navController.navigate(Screen.ProductDetail(id).createRoute())
            }
        )
        productDetailGraph(
            onAddToCart = { navController.navigate(Screen.Checkout.route) }
        )
        checkoutGraph(
            onOrderPlaced = { orderId ->
                navController.navigate("confirmation/$orderId") {
                    popUpTo(Screen.Home.route)
                }
            }
        )
    }
}
```

### Feature-level navigation extension

```kotlin
// feature:home modülünde
fun NavGraphBuilder.homeGraph(onProductClick: (String) -> Unit) {
    navigation(startDestination = "home_list", route = Screen.Home.route) {
        composable("home_list") {
            HomeScreen(onProductClick = onProductClick)
        }
    }
}
```

Bu pattern sayesinde her feature kendi navigation'ını tanımlar, `:app` sadece birleştirir.
