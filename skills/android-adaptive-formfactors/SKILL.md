---
name: android-adaptive-formfactors
description: >
  Farklı form faktörlerine uyum: tablet ve büyük ekran düzenleri, katlanabilir (foldable)
  cihaz duruşları, list-detail ve supporting-pane kalıpları, pencere boyutu sınıfları,
  Glance app widget'ları, Wear OS / TV / Automotive'e açılma kararı, klavye-fare-stylus desteği.

  Şu isteklerde tetiklen: "tablet desteği", "büyük ekran", "foldable", "katlanabilir",
  "iki panel", "list detail", "responsive layout", "window size class", "widget yaz",
  "Glance", "Wear OS", "saat uygulaması", "Android TV", "Automotive", "ChromeBook",
  "yatay modda bozuluyor", "klavye kısayolu".
---

# Adaptive & Form Factors Skill

Sen çoklu form faktörü uzmanısın. Temel kuralın: **cihaz türünü değil, pencere boyutunu sor.**
"Tablet mi?" yanlış sorudur — katlanabilir telefon açıkken tablet genişliğindedir,
tablet bölünmüş ekranda telefon genişliğindedir, ChromeBook'ta pencere serbestçe yeniden boyutlanır.

## Pencere Boyutu Sınıfları

| Sınıf | Genişlik | Tipik | Düzen |
|---|---|---|---|
| Compact | < 600dp | Telefon dikey | Tek panel, alt navigasyon |
| Medium | 600–840dp | Tablet dikey, foldable açık | Tek/çift panel, navigation rail |
| Expanded | > 840dp | Tablet yatay, masaüstü | Çift panel, kalıcı drawer |

```kotlin
@Composable
fun AppRoot() {
    val windowSize = currentWindowAdaptiveInfo().windowSizeClass

    NavigationSuiteScaffold(
        navigationSuiteItems = {
            TopLevelDestination.entries.forEach { dest ->
                item(
                    selected = dest == current,
                    onClick = { navigate(dest) },
                    icon = { Icon(dest.icon, null) },
                    label = { Text(stringResource(dest.labelRes)) },
                )
            }
        },
    ) {
        AppNavHost()
    }
}
```

`NavigationSuiteScaffold` navigasyon bileşenini genişliğe göre otomatik seçer:
Compact → `NavigationBar`, Medium → `NavigationRail`, Expanded → `PermanentDrawer`.
Bunu elle `when` ile yazma; sistem varsayılanları cihaz sınıflarıyla birlikte güncellenir.

**Asla `Configuration.smallestScreenWidthDp` ile "tablet mi" kararı verme** ve
ekran boyutunu `LocalContext.resources.displayMetrics`'ten okuma — çoklu pencerede yanlış sonuç verir.

---

## Canonical Layout: List-Detail

En yaygın adaptive kalıp. Telefonda iki ekran, tablette yan yana:

```kotlin
@Composable
fun OrdersRoute() {
    val navigator = rememberListDetailPaneScaffoldNavigator<String>()

    NavigableListDetailPaneScaffold(
        navigator = navigator,
        listPane = {
            AnimatedPane {
                OrderListScreen(
                    selectedId = navigator.currentDestination?.contentKey,
                    onOrderClick = { id ->
                        navigator.navigateTo(ListDetailPaneScaffoldRole.Detail, id)
                    },
                )
            }
        },
        detailPane = {
            AnimatedPane {
                navigator.currentDestination?.contentKey
                    ?.let { OrderDetailScreen(orderId = it) }
                    ?: EmptyDetailPlaceholder()      // geniş ekranda boş panel çirkin durur
            }
        },
    )
}
```

Dikkat edilecekler:
- **Boş detay paneli** için anlamlı bir yer tutucu koy ("Bir sipariş seçin"), boş beyaz bırakma
- Geniş ekranda listede **seçili öğe vurgulanmalı** — hangi detayın gösterildiği belli olsun
- Geri tuşu davranışı `NavigableListDetailPaneScaffold` tarafından yönetilir; elle `BackHandler` ekleme
- Diğer kalıplar: `SupportingPaneScaffold` (ana içerik + yardımcı panel),
  feed (çok sütunlu grid — `GridCells.Adaptive(minSize = 180.dp)`)

---

## Katlanabilir Cihazlar

```kotlin
val posture = currentWindowAdaptiveInfo().windowPosture

if (posture.isTabletop) {
    // Cihaz masada yarı açık: üst yarı içerik, alt yarı kontrol
    Column {
        VideoPlayer(Modifier.weight(1f))
        PlaybackControls(Modifier.weight(1f))
    }
}
```

`hingeBounds` ile menteşenin ekranı böldüğü bölgeyi al ve **oraya etkileşimli bir şey koyma** —
kullanıcı menteşe üzerindeki butona basamaz.

En sık kaçırılan foldable bug'ı: **katlama/açma bir konfigürasyon değişikliğidir.**
Activity yeniden oluşur; kaydedilmemiş form verisi, scroll pozisyonu ve oynatma konumu kaybolur.
`rememberSaveable` ve `SavedStateHandle` kullan.

Test: `adb shell cmd device_state state 1` (katlı) / `state 0` (açık),
emülatörde 7.6" Fold ve 8" Pixel Tablet profilleri.

---

## Konfigürasyon Değişikliği Dayanıklılığı

Adaptive uygulamada konfigürasyon değişikliği **istisna değil normaldir**:
döndürme, katlama, bölünmüş ekran, pencere yeniden boyutlandırma, klavye takma.

```kotlin
// Kaybolmaması gereken UI state
var query by rememberSaveable { mutableStateOf("") }

// Karmaşık state için Saver
val state = rememberSaveable(saver = FormState.Saver) { FormState() }
```

`android:configChanges` ile değişiklikleri yakalayıp yeniden oluşumu engellemeye çalışma —
sorunu gizler, çözmez ve yeni cihaz sınıflarında bozulur.

Doğrulama: Geliştirici Seçenekleri → "Etkinlikleri tutma" açıkken tüm akışları gez.
Process death'i simüle eder ve state kaybını anında gösterir.

---

## Klavye, Fare, Stylus

Tablet ve ChromeBook kullanıcıları harici giriş cihazı kullanır:

```kotlin
Modifier
    .onKeyEvent { event ->
        if (event.type == KeyEventType.KeyDown && event.key == Key.Escape) {
            onDismiss(); true
        } else false
    }
    .hoverable(interactionSource)          // fare ile üzerine gelme durumu
    .focusable()                           // Tab ile gezinme
```

- Tab sırası mantıklı olmalı (`focusProperties { next = ... }`)
- Metin alanlarında Enter davranışı tanımlı olmalı
- Uzun listelerde Ctrl+F, kaydetmede Ctrl+S gibi beklenen kısayolları destekle
- Fare ile sağ tık → bağlam menüsü (`combinedClickable`)

---

## Glance App Widget'ları

```kotlin
class OrderStatusWidget : GlanceAppWidget() {
    override suspend fun provideGlance(context: Context, id: GlanceId) {
        val orders = loadRecentOrders(context)          // suspend, ana ekran çizilmeden önce

        provideContent {
            GlanceTheme {
                Column(GlanceModifier.fillMaxSize().padding(12.dp)) {
                    Text("Son siparişler", style = TextStyle(fontWeight = FontWeight.Bold))
                    orders.take(3).forEach { order ->
                        Text(
                            text = order.number,
                            modifier = GlanceModifier.clickable(
                                actionStartActivity<MainActivity>(
                                    actionParametersOf(orderIdKey to order.id)
                                )
                            ),
                        )
                    }
                }
            }
        }
    }
}
```

Widget kuralları:
- Glance, Compose **değildir** — `remember`, animasyon, `LazyColumn` yok. Sınırlı bir DSL.
- Güncelleme **pahalıdır**; her dakika yenileme pil yakar. WorkManager ile makul aralık kur
  veya veri değiştiğinde `update()` çağır.
- Boyut sınıfları için `SizeMode.Responsive` kullan; tek düzen her widget boyutunda çalışmaz
- Widget'tan açılan ekran deep link ile açılmalı, `MainActivity`'de manuel yönlendirme değil

---

## Yeni Form Faktörüne Açılma Kararı

| Form faktör | Ne zaman değer | Gerçek maliyet |
|---|---|---|
| **Tablet / foldable** | Neredeyse her uygulama — Play Store sıralamasını etkiler | Orta: adaptive düzenler + config dayanıklılığı |
| **Wear OS** | Kısa, bağlamsal etkileşim varsa (fitness, bildirim, kontrol) | Yüksek: ayrı UI, ayrı veri senkronu, pil kısıtları |
| **Android TV** | Uzun form içerik tüketimi | Yüksek: D-pad navigasyonu, 10-foot UI, ayrı mağaza girişi |
| **Automotive** | Sürüş sırasında güvenli kullanım | Çok yüksek: katı sürücü dikkat dağıtma kuralları, sertifikasyon |

Wear/TV/Automotive **ayrı bir uygulamadır**, mevcut UI'ı ölçeklemek değildir.
Ortak katman domain + data olur (`:core:domain` zaten saf Kotlin'se hazırsın);
UI baştan yazılır. Bu kararı vermeden önce `design-doc` yaz — maliyeti hafife alınıyor.

Büyük ekran desteği ise farklı: bu bir "yeni platform" değil, mevcut uygulamanın
**doğru çalışması** meselesidir. Play Store büyük ekran uyumsuz uygulamaları
tablet aramalarında geri sıralar.

---

## Checklist

- [ ] Karar `WindowSizeClass` ile veriliyor, cihaz türü tahmini yapılmıyor
- [ ] Navigasyon bileşeni genişliğe göre değişiyor (`NavigationSuiteScaffold`)
- [ ] List-detail kalıbı kullanılan yerlerde boş panel yer tutucusu ve seçili öğe vurgusu var
- [ ] Menteşe bölgesine etkileşimli öğe yerleştirilmemiş
- [ ] `rememberSaveable` ile konfigürasyon değişikliğinde state korunuyor
- [ ] "Etkinlikleri tutma" açıkken tüm akışlar test edildi
- [ ] Katlama/açma, bölünmüş ekran ve pencere yeniden boyutlandırma denendi
- [ ] Klavye ile gezinme (Tab, Esc) ve fare hover destekleniyor
- [ ] Widget varsa `SizeMode.Responsive` ve makul güncelleme aralığı ayarlı
- [ ] Yeni form faktörü kararı design doc ile alınmış, UI'ı ölçekleme varsayımı yok
