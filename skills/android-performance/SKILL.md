---
name: android-performance
last_reviewed: 2026-08
description: >
  Android performans ve kararlılık uzmanlığı: startup süresi, jank/frame drop, recomposition
  optimizasyonu, bellek sızıntısı (LeakCanary), APK/AAB boyutu, baseline profile, R8/ProGuard,
  ANR analizi, battery ve network verimliliği, Macrobenchmark ölçümü.

  Şu isteklerde tetiklen: "uygulama yavaş", "açılış süresi", "jank", "takılma", "frame drop",
  "memory leak", "OOM", "APK boyutu küçült", "baseline profile", "R8", "ANR", "profiler",
  "benchmark", "pil tüketimi", "recomposition çok fazla", "scroll akıcı değil".
---

# Android Performance Skill

Sen performans mühendisisin. Temel ilken: **önce ölç, sonra optimize et.**
Ölçüm olmadan yapılan optimizasyon önerisini asla kod olarak sunma — önce hangi aracın
hangi metriği vereceğini söyle.

## Teşhis Akışı

Kullanıcı "yavaş" dediğinde önce hangi kategoride olduğunu belirle:

| Belirti | Ölçüm aracı | Hedef metrik |
|---|---|---|
| Açılış yavaş | Macrobenchmark `StartupTimingMetric`, Play Vitals | TTID < 500ms, TTFD < 1s |
| Scroll takılıyor | Macrobenchmark `FrameTimingMetric`, Layout Inspector | P99 frame < 16.6ms |
| Uygulama donuyor | ANR raporları, Perfetto trace | main thread'de blocking yok |
| Bellek şişiyor | Memory Profiler, LeakCanary | leak yok, heap stabil |
| APK büyük | `bundletool`, APK Analyzer | download size takibi |
| Pil bitiyor | Battery Historian, Play Vitals | wakelock/alarm minimum |

---

## 1. Startup Süresi

**Aşamalar:** Process başlatma → `Application.onCreate` → `Activity.onCreate` →
ilk frame (TTID) → içerik dolu ilk frame (TTFD).

Yaygın hatalar ve düzeltmeleri:

```kotlin
// YANLIŞ — Application.onCreate'te senkron ağır iş
class MyApp : Application() {
    override fun onCreate() {
        super.onCreate()
        Analytics.init(this)      // 200ms
        ImageLoader.warmUp()      // 150ms
        Database.prepopulate()    // 400ms  → 750ms startup'a eklendi
    }
}

// DOĞRU — kritik olmayan işi arka plana / lazy'e al
class MyApp : Application() {
    @Inject lateinit var appScope: CoroutineScope

    override fun onCreate() {
        super.onCreate()
        Analytics.init(this)                       // gerçekten kritikse burada kalsın
        appScope.launch(Dispatchers.Default) {
            ImageLoader.warmUp()
            Database.prepopulate()
        }
    }
}
```

- **App Startup kütüphanesi** (`androidx.startup`) ile ContentProvider bazlı init'leri tek yere topla.
- Hilt graph'ı büyükse `@Lazy<T>` inject ederek nesne oluşturmayı ertele.
- Splash için `SplashScreen` API kullan; kendi splash Activity'ni yazma (ekstra bir Activity geçişi = ekstra gecikme).

### Baseline Profile (en yüksek getirili tek optimizasyon)

```kotlin
@RunWith(AndroidJUnit4::class)
class BaselineProfileGenerator {
    @get:Rule val rule = BaselineProfileRule()

    @Test fun generate() = rule.collect(packageName = "com.example.app") {
        pressHome()
        startActivityAndWait()
        device.findObject(By.res("product_list")).fling(Direction.DOWN)
        device.waitForIdle()
    }
}
```

Tipik kazanç: startup %20-30, ilk scroll jank'i belirgin azalma. CI'da her release öncesi yeniden üret.

---

## 2. Jank / Frame Drop

Bütçe: 60Hz'de **16.6ms**, 120Hz'de **8.3ms**. Bu sürede layout + draw + compose bitmeli.

Compose'da en sık 4 sebep:

1. **Unstable parametre** → gereksiz recomposition
   ```kotlin
   // List<T> unstable → ImmutableList veya @Immutable data class kullan
   @Composable fun Rows(items: ImmutableList<Row>)
   ```
2. **Composition'da hesaplama** → `remember` ile cache'le
   ```kotlin
   val sorted = remember(items) { items.sortedBy { it.name } }
   ```
3. **Sık değişen state'i yukarıda okumak** → okumayı lambda'ya ertele
   ```kotlin
   // YANLIŞ: her scroll frame'inde tüm parent recompose olur
   Box(Modifier.offset(y = scrollOffset.dp))
   // DOĞRU: sadece layout fazı çalışır
   Box(Modifier.offset { IntOffset(0, scrollOffset) })
   ```
4. **`key` verilmemiş lazy list** → tüm item'lar yeniden oluşur

Ölçüm için Compose Compiler metrics'i aç:

```kotlin
composeCompiler {
    reportsDestination = layout.buildDirectory.dir("compose_compiler")
    metricsDestination = layout.buildDirectory.dir("compose_compiler")
}
```

Rapordaki `restartable skippable` olmayan composable'lar öncelikli hedeftir.

---

## 3. Bellek

```kotlin
dependencies { debugImplementation(libs.leakcanary.android) }
```

En sık sızıntı kaynakları:
- Activity/Fragment context'i singleton'a verilmiş → `applicationContext` kullan
- `LifecycleOwner`'a bağlanmayan listener/callback → `DisposableEffect` veya `onDestroy`'da temizle
- Static `Handler`/`Runnable` → `WeakReference` veya lifecycle-aware yapı
- Composable içinde `remember` ile tutulan büyük bitmap → `Coil`/`Glide`'a bırak

`OutOfMemoryError` genelde bitmap kaynaklıdır: resim yüklerken hedef boyutu belirt
(`.size(Size(width, height))`), tam çözünürlük yükleme.

---

## 4. APK / AAB Boyutu

```kotlin
android {
    buildTypes {
        release {
            isMinifyEnabled = true
            isShrinkResources = true
            proguardFiles(getDefaultProguardFile("proguard-android-optimize.txt"), "proguard-rules.pro")
        }
    }
    bundle {
        language.enableSplit = true
        density.enableSplit = true
        abi.enableSplit = true
    }
}
```

- R8 full mode açık olsun (`android.enableR8.fullMode=true`)
- Vector drawable kullan, PNG setleri değil
- Kullanılmayan lokalizasyonları `resourceConfigurations` ile kırp
- Büyük asset'leri Play Asset Delivery'ye taşı
- Reflection kullanan kütüphaneler için `-keep` kuralları **dar** yaz; `-keep class **` yazmak R8'i etkisizleştirir

---

## 5. ANR

ANR eşiği: input için 5s, broadcast için 10s (foreground). Sebepler:
- Main thread'de disk I/O (SharedPreferences `commit()`, dosya okuma) → `apply()` / DataStore
- Main thread'de ağ çağrısı → asla
- Deadlock veya uzun süren `synchronized` blok
- `Binder` çağrısı (ContentProvider, IPC) main thread'de

`StrictMode`'u debug build'de aç, ihlalleri erken yakala:

```kotlin
if (BuildConfig.DEBUG) {
    StrictMode.setThreadPolicy(
        StrictMode.ThreadPolicy.Builder().detectAll().penaltyLog().build()
    )
}
```

---

## 6. Macrobenchmark ile Doğrulama

```kotlin
@Test
fun startup() = benchmarkRule.measureRepeated(
    packageName = "com.example.app",
    metrics = listOf(StartupTimingMetric()),
    iterations = 10,
    startupMode = StartupMode.COLD,
) {
    pressHome()
    startActivityAndWait()
}
```

Optimizasyon öncesi ve sonrası aynı benchmark'ı çalıştır, sayıyı raporla.
"Daha hızlı oldu" değil, "TTID 820ms → 540ms" de.

---

## Checklist

- [ ] Baseline Profile üretiliyor ve release'e dahil
- [ ] `Application.onCreate` içinde bloklayan iş yok
- [ ] R8 + resource shrinking release'de açık
- [ ] LeakCanary debug build'de kurulu, bilinen sızıntı yok
- [ ] Compose compiler metrics'te kritik ekranlar skippable
- [ ] Lazy list'lerde `key` verilmiş
- [ ] StrictMode debug'da açık, ihlal yok
- [ ] Play Vitals'ta ANR oranı < %0.47, crash oranı < %1.09 (bad behavior eşikleri)
