---
name: android-gradle-build
last_reviewed: 2026-09
description: >
  Gradle build sistemi uzmanlığı: version catalog (libs.versions.toml), convention plugin'ler
  (buildSrc / build-logic), multi-module Gradle setup, build variant ve flavor yönetimi,
  build süresi optimizasyonu, KSP/KAPT geçişi, dependency çakışması çözümü.

  Şu isteklerde tetiklen: "gradle", "build.gradle.kts", "version catalog", "libs.versions.toml",
  "convention plugin", "buildSrc", "build-logic", "flavor", "build type", "build yavaş",
  "modül ekle", "bağımlılık çakışması", "duplicate class", "KSP'ye geç", "signing config",
  "BuildConfig", "gradle.properties".
---

# Android Gradle Build Skill

Sen build engineer'sın. Gradle kodu da production kodudur: kopyala-yapıştır yerine
**convention plugin**, sabit sürüm string'i yerine **version catalog** kullanılır.

## Altın Kural

10 modüllü bir projede aynı `android { }` bloğunu 10 kez yazıyorsan, bu bir bug'dır.
Ortaklaştır.

---

## 1. Version Catalog — `gradle/libs.versions.toml`

```toml
[versions]
agp = "9.4.0"
kotlin = "2.4.20"
# KSP sürümleme şeması değişti: artık Kotlin ön ekli değil ("2.1.0-1.0.29" gibi),
# bağımsız semver ("2.3.x"). 2.3.10+ google/ksp#2964'ü (Kotlin 2.4.0 modül adı
# çakışması) düzeltiyor; 2.3.12 ayrıca AGP 9'un gömülü Kotlin'iyle R-class
# çözümleme hatasını da kapatıyor.
ksp = "2.3.12"
composeBom = "2026.08.00"
# BEKLEYEN: android/skills (Google, resmî) 2026-09'da Hilt 2.59.2+ öneriyor (AGP 9
# upgrade skill'lerinde). Bu turda doğrulanmadı, henüz uygulanmadı — bir sonraki
# bakım turu §2a (version catalog iç tutarlılığı) kapsamında doğrulayıp güncellesin.
hilt = "2.53.1"
coroutines = "1.9.0"
retrofit = "2.11.0"

[libraries]
androidx-core-ktx        = { module = "androidx.core:core-ktx", version = "1.15.0" }
androidx-lifecycle-vm    = { module = "androidx.lifecycle:lifecycle-viewmodel-compose", version = "2.8.7" }
compose-bom              = { module = "androidx.compose:compose-bom", version.ref = "composeBom" }
compose-ui               = { module = "androidx.compose.ui:ui" }
compose-material3        = { module = "androidx.compose.material3:material3" }
hilt-android             = { module = "com.google.dagger:hilt-android", version.ref = "hilt" }
hilt-compiler            = { module = "com.google.dagger:hilt-android-compiler", version.ref = "hilt" }
coroutines-core          = { module = "org.jetbrains.kotlinx:kotlinx-coroutines-core", version.ref = "coroutines" }
retrofit                 = { module = "com.squareup.retrofit2:retrofit", version.ref = "retrofit" }
turbine                  = { module = "app.cash.turbine:turbine", version = "1.2.0" }
mockk                    = { module = "io.mockk:mockk", version = "1.13.13" }

[bundles]
compose = ["compose-ui", "compose-material3"]
test-unit = ["turbine", "mockk"]

[plugins]
android-application = { id = "com.android.application", version.ref = "agp" }
android-library     = { id = "com.android.library", version.ref = "agp" }
kotlin-android      = { id = "org.jetbrains.kotlin.android", version.ref = "kotlin" }
kotlin-compose      = { id = "org.jetbrains.kotlin.plugin.compose", version.ref = "kotlin" }
ksp                 = { id = "com.google.devtools.ksp", version.ref = "ksp" }
hilt                = { id = "com.google.dagger.hilt.android", version.ref = "hilt" }
```

Kullanım: `implementation(libs.androidx.core.ktx)`, `implementation(libs.bundles.compose)`.
Toml'daki `-` Kotlin'de `.` olur.

---

## 2. Convention Plugin'ler — `build-logic/`

`buildSrc` yerine **`build-logic` included build** tercih et: `buildSrc`'de bir değişiklik
tüm projeyi invalidate eder, included build etmez.

```
build-logic/
├── settings.gradle.kts
└── convention/
    ├── build.gradle.kts
    └── src/main/kotlin/
        ├── AndroidLibraryConventionPlugin.kt
        ├── AndroidFeatureConventionPlugin.kt
        ├── AndroidComposeConventionPlugin.kt
        └── AndroidHiltConventionPlugin.kt
```

`settings.gradle.kts` (kök):
```kotlin
pluginManagement {
    includeBuild("build-logic")
    repositories { google(); mavenCentral(); gradlePluginPortal() }
}
```

`AndroidLibraryConventionPlugin.kt`:
```kotlin
class AndroidLibraryConventionPlugin : Plugin<Project> {
    override fun apply(target: Project) = with(target) {
        pluginManager.apply("com.android.library")
        pluginManager.apply("org.jetbrains.kotlin.android")

        extensions.configure<LibraryExtension> {
            compileSdk = 37
            defaultConfig {
                minSdk = 24
                testInstrumentationRunner = "androidx.test.runner.AndroidJUnitRunner"
            }
            compileOptions {
                sourceCompatibility = JavaVersion.VERSION_17
                targetCompatibility = JavaVersion.VERSION_17
            }
        }
        extensions.configure<KotlinAndroidProjectExtension> {
            compilerOptions.jvmTarget.set(JvmTarget.JVM_17)
        }
    }
}
```

`convention/build.gradle.kts` içinde kaydet:
```kotlin
gradlePlugin {
    plugins {
        register("androidLibrary") {
            id = "myapp.android.library"
            implementationClass = "AndroidLibraryConventionPlugin"
        }
        register("androidFeature") {
            id = "myapp.android.feature"
            implementationClass = "AndroidFeatureConventionPlugin"
        }
    }
}
```

Artık her feature modülünün `build.gradle.kts`'i 6 satır:
```kotlin
plugins {
    id("myapp.android.feature")
    id("myapp.android.compose")
    id("myapp.android.hilt")
}
android { namespace = "com.example.feature.product" }
dependencies { implementation(projects.domain) }
```

---

## 3. Type-safe Project Accessors

`settings.gradle.kts`:
```kotlin
enableFeaturePreview("TYPESAFE_PROJECT_ACCESSORS")

include(":app")
include(":domain", ":data")
include(":core:ui", ":core:network", ":core:database", ":core:common", ":core:testing")
include(":feature:home", ":feature:product", ":feature:checkout")
```

`project(":core:network")` yerine `projects.core.network` — yazım hatası compile-time'da yakalanır.

---

## 4. Build Variant ve Flavor

```kotlin
android {
    flavorDimensions += "environment"
    productFlavors {
        create("dev") {
            dimension = "environment"
            applicationIdSuffix = ".dev"
            versionNameSuffix = "-dev"
            buildConfigField("String", "BASE_URL", "\"https://api-dev.example.com/\"")
        }
        create("prod") {
            dimension = "environment"
            buildConfigField("String", "BASE_URL", "\"https://api.example.com/\"")
        }
    }
    buildFeatures { buildConfig = true }
}
```

Flavor sayısını düşük tut: her flavor × buildType kombinasyonu ayrı bir variant demek,
build ve test matrisi katlanarak büyür.

**Dynamic feature modülün varsa:** AGP 9.4.0'dan itibaren temel app ile dynamic feature
modülleri arasında flavor dimension'ların 1:1 eşleşmesi kontrol ediliyor (eksik/fazla/
uyumsuz dimension varsayılan olarak sadece uyarı verir). AGP 10.0'da bu kontrol **hataya**
dönüşecek — şimdiden `android.enforceDynamicFeatureVariantMatching=true` ile erken test et.

---

## 5. Build Süresi Optimizasyonu

`gradle.properties`:
```properties
org.gradle.jvmargs=-Xmx4g -XX:+UseParallelGC -Dfile.encoding=UTF-8
org.gradle.parallel=true
org.gradle.caching=true
org.gradle.configuration-cache=true
android.useAndroidX=true
android.nonTransitiveRClass=true
android.enableR8.fullMode=true
kotlin.incremental=true
```

- **KAPT → KSP geçişi**: en büyük tek kazanç. Hilt, Room, Moshi hepsi KSP destekliyor.
  KAPT Java stub üretir; KSP üretmez, tipik olarak 2x hızlıdır.
- **`api` yerine `implementation`**: `api` bağımlılığı transitif olarak yayar,
  değişiklikte tüketici modüller de yeniden derlenir.
- Ölçüm: `./gradlew assembleDebug --scan` veya
  `./gradlew --profile` → `build/reports/profile/` altındaki HTML raporu.

---

## 6. Sık Karşılaşılan Hatalar

| Hata | Sebep | Çözüm |
|---|---|---|
| `Duplicate class ... found in modules` | Aynı kütüphanenin iki sürümü | `./gradlew :app:dependencies` ile ağacı çıkar, `resolutionStrategy.force` veya exclude |
| `Unsupported class file major version` | JDK/AGP uyumsuzluğu | JDK 17 kullan, `compileOptions` hizala |
| `Configuration cache problems` | Task'ta build-time'da Project referansı | `providers.gradleProperty()` ile lazy oku |
| `Manifest merger failed` | minSdk/izin çakışması | `tools:replace` veya `tools:overrideLibrary` |
| Kotlin/KSP sürüm uyuşmazlığı | KSP artık bağımsız semver kullanıyor (Kotlin'e bağlı ön ek yok) | `github.com/google/ksp/releases`'ten hedef Kotlin sürümünü destekleyen en güncel KSP'yi seç |
| Companion object init sırası değişti (Kotlin 2.4.20+) | Companion object'ler artık JVM davranışıyla eşleşerek superclass→subclass sırayla başlatılıyor | Sınıf hiyerarşisinde companion object'ler arası bağımlılık varsa yükseltmeden önce test et |

---

## Checklist

- [ ] Tüm bağımlılıklar version catalog'da, hiçbir modülde string sürüm yok
- [ ] Ortak `android { }` konfigürasyonu convention plugin'de
- [ ] `build-logic` included build kullanılıyor (`buildSrc` değil)
- [ ] Type-safe project accessors açık
- [ ] Configuration cache + build cache açık ve çalışıyor
- [ ] KAPT kullanılmıyor (hepsi KSP)
- [ ] `api` sadece gerçekten gerekli yerlerde
- [ ] Release signing config `local.properties`/env'den okunuyor, repoda keystore yok
