---
name: android-platform-upgrade
description: >
  targetSdk yükseltme ve platform uyum kapıları: edge-to-edge zorunluluğu, predictive back,
  foreground service türleri, 16 KB page size, bildirim/fotoğraf izin modeli değişiklikleri,
  arka plan kısıtları, Play Store targetSdk son tarihleri ve kademeli yükseltme stratejisi.

  Şu isteklerde tetiklen: "targetSdk yükselt", "compileSdk güncelle", "Android 15 uyumu",
  "Android 16", "edge-to-edge", "predictive back", "foreground service type",
  "16 KB page size", "Play Store uyarı verdi", "uygulama yeni sürümde bozuldu",
  "API level deadline", "deprecated API", "yeni Android'de çöküyor".
---

# Android Platform Upgrade Skill

Sen platform uyum sorumlususun. targetSdk yükseltmek bir sayı değiştirmek değildir:
**her yükseltme, o zamana kadar opt-in olan davranışları zorunlu hale getirir.**

Bu yüzden yükseltme bir refactor değil, **davranış değişikliği taramasıdır.**

## Yükseltme Süreci

```
1. Ne zorunlu hale geliyor? → değişiklik listesini çıkar
2. Hangileri bizi etkiliyor?  → kod tabanında ara
3. compileSdk'yi yükselt      → derleme uyarılarını topla (targetSdk henüz değil)
4. Her davranışı tek tek ele  → ayrı commit, ayrı doğrulama
5. targetSdk'yi yükselt       → asıl anahtar burada çevriliyor
6. Gerçek cihazlarda test et  → yeni sürüm + eski sürüm birlikte
7. Staged rollout             → %10'da Vitals izle
```

**compileSdk ve targetSdk'yi aynı commit'te yükseltme.** compileSdk yeni API'leri ve
deprecation uyarılarını getirir (davranış değiştirmez); targetSdk yeni davranışları
aktif eder. Ayırırsan hangi değişikliğin neyi bozduğunu bilirsin.

---

## 1. Edge-to-Edge (Android 15+ / API 35)

targetSdk 35'te **zorunlu**. `enableEdgeToEdge()` çağırmasan bile sistem uygular;
opt-out (`windowOptOutEdgeToEdgeEnforcement`) yalnızca geçici bir kaçış yoludur ve kaldırılacaktır.

```kotlin
class MainActivity : ComponentActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        enableEdgeToEdge()
        super.onCreate(savedInstanceState)
        setContent { AppTheme { AppRoot() } }
    }
}
```

Compose tarafında insets'i **elle** ele al:

```kotlin
Scaffold { padding ->
    // Scaffold sistem çubuklarını padding olarak verir
    Column(Modifier.padding(padding)) { ... }
}

// Klavye açıldığında içeriğin kaymaması için
Column(Modifier.imePadding()) { ... }

// Sadece alt sistem çubuğu için
Box(Modifier.navigationBarsPadding())

// Liste: içerik çubuğun altına scroll olsun ama son öğe kesilmesin
LazyColumn(contentPadding = WindowInsets.safeDrawing.asPaddingValues())
```

Yükseltmede en sık bozulanlar:
- Ekranın en altındaki buton navigasyon çubuğunun altında kalıyor → `navigationBarsPadding()`
- Klavye açılınca form alanı görünmüyor → `imePadding()` + `windowSoftInputMode` kontrolü
- Durum çubuğu ile başlık çakışıyor → `statusBarsPadding()` veya `Scaffold` padding'i
- `View` tabanlı ekranlarda `fitsSystemWindows` artık yeterli değil → `WindowInsetsCompat` dinle

**Doğrulama:** hem gesture navigation hem 3 düğmeli navigation ile, hem açık hem koyu temada,
hem de klavye açıkken her ekranı gez.

---

## 2. Predictive Back (Android 14+)

```xml
<application android:enableOnBackInvokedCallback="true">
```

Etkinleştirdiğinde `onBackPressed()` override'ları **çalışmaz**. Geçiş:

```kotlin
// Compose
BackHandler(enabled = hasUnsavedChanges) {
    showDiscardDialog = true
}

// Predictive geri jestinde ilerlemeyi göstermek istersen
PredictiveBackHandler(enabled = isDrawerOpen) { progress ->
    try {
        progress.collect { backEvent -> drawerOffset = backEvent.progress }
        closeDrawer()                 // jest tamamlandı
    } catch (e: CancellationException) {
        resetDrawer()                 // kullanıcı vazgeçti
    }
}
```

Tuzak: `BackHandler(enabled = true)`'ı koşulsuz bırakmak. Sistem, geri jestinin ekranı
kapatıp kapatmayacağını **önceden** bilmek zorundadır; sürekli etkin bir handler
predictive animasyonu devre dışı bırakır. `enabled`'ı gerçek koşula bağla.

---

## 3. Foreground Service Türleri (Android 14+)

Her foreground service **tür beyan etmek** ve o türe karşılık gelen izni almak zorunda:

```xml
<uses-permission android:name="android.permission.FOREGROUND_SERVICE" />
<uses-permission android:name="android.permission.FOREGROUND_SERVICE_DATA_SYNC" />

<service
    android:name=".SyncService"
    android:foregroundServiceType="dataSync"
    android:exported="false" />
```

```kotlin
ServiceCompat.startForeground(
    this, NOTIFICATION_ID, notification,
    ServiceInfo.FOREGROUND_SERVICE_TYPE_DATA_SYNC,
)
```

Kritik: `dataSync` ve `mediaProcessing` türleri Android 15'te **günlük süre kotasına** tabi
(yaklaşık 6 saat); kota dolunca sistem servisi durdurur. Uzun süreli arka plan işi için
foreground service değil **WorkManager** kullan.

Beyan edilen tür yapılan işe uymuyorsa Play Store yayını reddeder — `dataSync` diye
beyan edip konum takibi yapamazsın.

---

## 4. 16 KB Page Size (Android 15+)

Native kütüphanesi olan **her** uygulama etkilenir; 16 KB sayfa boyutlu cihazlarda
uyumsuz `.so` yüklenmez ve uygulama açılışta çöker.

```cmake
target_link_options(mylib PRIVATE "-Wl,-z,max-page-size=16384")
```

Prebuilt (üçüncü parti) `.so` dosyaları için sağlayıcıdan güncel sürüm iste — kendi
başına yeniden linkleyemezsin. Kontrol:

```bash
llvm-objdump -p libfoo.so | grep LOAD    # align 2**14 (16384) olmalı
```

Detay için `android-native-ndk` skill'i. Native kodun yoksa bile bağımlılıklarını tara —
Realm, SQLCipher, video/görüntü SDK'ları native taşır.

---

## 5. İzin Modeli Değişiklikleri

| Sürüm | Değişiklik | Yapılacak |
|---|---|---|
| 13 (33) | `POST_NOTIFICATIONS` runtime izni | Bildirim göndermeden önce iste; reddedilirse sessizce düş |
| 13 (33) | `READ_EXTERNAL_STORAGE` bölündü | `READ_MEDIA_IMAGES/VIDEO/AUDIO` veya Photo Picker |
| 14 (34) | Kısmi fotoğraf erişimi | `READ_MEDIA_VISUAL_USER_SELECTED` — kullanıcı sadece bazı fotoğrafları seçebilir |
| 14 (34) | Tam ekran bildirim kısıtı | `USE_FULL_SCREEN_INTENT` yalnızca alarm/arama uygulamalarına |
| 15 (35) | Arka planda servis başlatma daralması | WorkManager'a geç |

**En iyi hamle: izni tamamen ortadan kaldırmak.** Photo Picker (`PickVisualMedia`) hiç izin
istemez ve tüm sürümlerde çalışır:

```kotlin
val picker = rememberLauncherForActivityResult(
    ActivityResultContracts.PickVisualMedia()
) { uri -> uri?.let(onImageSelected) }

picker.launch(PickVisualMediaRequest(ActivityResultContracts.PickVisualMedia.ImageOnly))
```

---

## 6. Etki Taraması

Yükseltmeden önce kod tabanını tara:

```bash
# Foreground service kullanımı
grep -rn "startForeground\|FOREGROUND_SERVICE" --include=*.kt --include=*.xml .

# Eski geri tuşu API'si
grep -rn "onBackPressed\|OnBackPressedCallback" --include=*.kt .

# Depolama izinleri
grep -rn "READ_EXTERNAL_STORAGE\|WRITE_EXTERNAL_STORAGE" --include=*.xml .

# Native kütüphaneler (16 KB kontrolü gerekenler)
find . -name "*.so" | head -20

# Tam ekran intent
grep -rn "FULL_SCREEN_INTENT\|setFullScreenIntent" --include=*.kt --include=*.xml .
```

Bağımlılıkları da tara: eski AGP, eski AndroidX sürümleri yeni platform davranışlarını
desteklemez. Önce kütüphaneleri güncelle, sonra targetSdk'yi.

---

## 7. Play Store Zorunlulukları

- Yeni uygulamalar ve güncellemeler, **son API sürümünden en fazla bir yıl geride**
  bir targetSdk ile yayınlanabilir; her yıl Ağustos civarı eşik yükselir
- Eşiği kaçıran uygulama **güncelleme yayınlayamaz**; mevcut sürüm mağazada kalır ama
  yeni cihazlarda görünmez hale gelir
- Yükseltmeyi son aya bırakma: davranış değişiklikleri gerçek bug üretir ve
  staged rollout için zaman gerekir

Takvime her yıl **Nisan'da** bir hatırlatma koy; Ağustos'ta panik yaşama.

---

## Yükseltme Checklist

- [ ] Resmî "behavior changes" listesi okundu, etkileyenler işaretlendi
- [ ] compileSdk ayrı commit'te yükseltildi, deprecation uyarıları temizlendi
- [ ] Bağımlılıklar yeni platformu destekleyen sürümlere çıkarıldı
- [ ] Edge-to-edge tüm ekranlarda doğrulandı (gesture + 3 düğme, açık + koyu, klavye açık)
- [ ] `onBackPressed` kullanımı kalmadı; `BackHandler.enabled` gerçek koşula bağlı
- [ ] Foreground service'ler tür beyan ediyor, kotaya takılacak işler WorkManager'a taşındı
- [ ] Native `.so`'lar 16 KB hizalı (üçüncü parti dahil)
- [ ] İzin akışları yeni modele uygun; mümkün olan yerde izin tamamen kaldırıldı
- [ ] targetSdk ayrı commit'te yükseltildi
- [ ] En yeni ve en eski desteklenen API seviyelerinde gerçek cihazda test edildi
- [ ] Staged rollout %10'da başlatıldı, Vitals (ANR/crash) izleniyor
