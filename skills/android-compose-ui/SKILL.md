---
name: android-compose-ui
description: >
  Jetpack Compose UI uzmanlığı: ekran yazma, design system kurma, Material 3 theming,
  animasyon, custom layout, accessibility, adaptive/responsive tasarım ve preview stratejisi.

  Şu isteklerde tetiklen: "compose ekranı yaz", "design system kur", "theme/tema oluştur",
  "Material 3", "dark mode", "animasyon ekle", "custom layout", "LazyColumn performansı",
  "bottom sheet", "accessibility / erişilebilirlik", "tablet / foldable desteği",
  "preview yaz", "component library", "shimmer/skeleton", "custom Modifier".
  Genel mimari sorusu ise android-architect skill'ine devret.
---

# Android Compose UI Skill

Sen Compose konusunda uzman bir UI engineer'sın. Ürettiğin her ekran; tema token'larını kullanan,
state'i yukarı taşıyan (state hoisting), preview'ı olan ve erişilebilir kod olmalı.

## Değişmez Kurallar

1. **Hardcoded değer yok.** Renk `MaterialTheme.colorScheme.*`, tipografi `MaterialTheme.typography.*`,
   boşluk `MaterialTheme.spacing.*` (custom token) üzerinden gelir.
2. **Stateful / stateless ayrımı.** `XScreen` (ViewModel alır) + `XContent` (sadece state + lambda alır).
   Preview ve test her zaman `XContent`'e yazılır.
3. **State hoisting.** Composable kendi iş state'ini tutmaz; sadece geçici UI state'i (`rememberScrollState`,
   `rememberTextFieldState`) içeride kalabilir.
4. **Modifier her zaman ilk opsiyonel parametre** ve `modifier: Modifier = Modifier` olarak adlandırılır.
5. **Lambda parametreleri son sırada**, `onXClick` isimlendirmesiyle.

---

## Design System Kurulumu

`:core:designsystem` modülü şu yapıda olur:

```
core/designsystem/
├── theme/
│   ├── Color.kt          → renk paletleri (light/dark)
│   ├── Type.kt           → Typography
│   ├── Shape.kt          → Shapes
│   ├── Spacing.kt        → custom spacing token'ları
│   └── Theme.kt          → AppTheme composable
├── component/
│   ├── AppButton.kt
│   ├── AppTextField.kt
│   ├── AppCard.kt
│   ├── LoadingIndicator.kt
│   └── EmptyState.kt
└── icon/AppIcons.kt
```

### Spacing token'ı (Material 3'te yok, kendin ekle)

```kotlin
@Immutable
data class Spacing(
    val none: Dp = 0.dp,
    val xs: Dp = 4.dp,
    val sm: Dp = 8.dp,
    val md: Dp = 16.dp,
    val lg: Dp = 24.dp,
    val xl: Dp = 32.dp,
)

val LocalSpacing = staticCompositionLocalOf { Spacing() }

val MaterialTheme.spacing: Spacing
    @Composable @ReadOnlyComposable get() = LocalSpacing.current
```

### Theme

```kotlin
@Composable
fun AppTheme(
    darkTheme: Boolean = isSystemInDarkTheme(),
    dynamicColor: Boolean = true,
    content: @Composable () -> Unit,
) {
    val colorScheme = when {
        dynamicColor && Build.VERSION.SDK_INT >= Build.VERSION_CODES.S -> {
            val ctx = LocalContext.current
            if (darkTheme) dynamicDarkColorScheme(ctx) else dynamicLightColorScheme(ctx)
        }
        darkTheme -> DarkColorScheme
        else -> LightColorScheme
    }

    CompositionLocalProvider(LocalSpacing provides Spacing()) {
        MaterialTheme(
            colorScheme = colorScheme,
            typography = AppTypography,
            shapes = AppShapes,
            content = content,
        )
    }
}
```

> **Tradeoff:** `dynamicColor` marka kimliğini bozar. Kurumsal uygulamada `false` yap,
> tüketici uygulamasında `true` bırak.

---

## Ekran Şablonu

```kotlin
@Composable
fun ProfileScreen(
    onBack: () -> Unit,
    viewModel: ProfileViewModel = hiltViewModel(),
) {
    val uiState by viewModel.uiState.collectAsStateWithLifecycle()

    LaunchedEffect(Unit) {
        viewModel.effect.collect { effect ->
            when (effect) {
                is ProfileEffect.NavigateBack -> onBack()
            }
        }
    }

    ProfileContent(
        uiState = uiState,
        onRetry = viewModel::onRetry,
        onBack = onBack,
    )
}

@Composable
internal fun ProfileContent(
    uiState: ProfileUiState,
    onRetry: () -> Unit,
    onBack: () -> Unit,
    modifier: Modifier = Modifier,
) {
    Scaffold(
        modifier = modifier,
        topBar = { AppTopBar(title = stringResource(R.string.profile), onBack = onBack) },
    ) { padding ->
        Box(Modifier.padding(padding).fillMaxSize()) {
            when {
                uiState.isLoading -> LoadingIndicator(Modifier.align(Alignment.Center))
                uiState.error != null -> ErrorState(uiState.error, onRetry)
                else -> ProfileDetails(uiState.profile)
            }
        }
    }
}

@PreviewLightDark
@Composable
private fun ProfileContentPreview(
    @PreviewParameter(ProfileStateProvider::class) state: ProfileUiState,
) {
    AppTheme { ProfileContent(state, onRetry = {}, onBack = {}) }
}
```

`@PreviewParameter` ile loading / error / success state'lerinin üçünü de tek preview'da göster.

---

## Liste Performansı

```kotlin
LazyColumn(
    contentPadding = PaddingValues(MaterialTheme.spacing.md),
    verticalArrangement = Arrangement.spacedBy(MaterialTheme.spacing.sm),
) {
    items(
        items = products,
        key = { it.id },                 // ZORUNLU — yoksa scroll pozisyonu ve animasyon bozulur
        contentType = { "product" },     // heterojen listede reuse'u iyileştirir
    ) { product ->
        ProductRow(
            product = product,
            onClick = remember(product.id) { { onProductClick(product.id) } },
        )
    }
}
```

Detaylı recomposition ve stability konuları için `references/compose-best-practices.md`.

---

## Adaptive / Responsive

```kotlin
@Composable
fun HomeRoute(windowSizeClass: WindowSizeClass) {
    when (windowSizeClass.widthSizeClass) {
        WindowWidthSizeClass.Compact -> HomeListPane()
        else -> Row {
            HomeListPane(Modifier.weight(1f))
            HomeDetailPane(Modifier.weight(2f))
        }
    }
}
```

Navigasyon barı da genişliğe göre değişir: Compact → `NavigationBar`,
Medium → `NavigationRail`, Expanded → `PermanentNavigationDrawer`.

---

## Accessibility Checklist

- [ ] Her ikon butonunda `contentDescription` var (dekoratifse açıkça `null`)
- [ ] Dokunma hedefi min `48.dp` (`Modifier.minimumInteractiveComponentSize()`)
- [ ] Metin `sp` birimiyle, sistem font ölçeğine saygılı (fixed `dp` metin yok)
- [ ] Renk kontrastı ≥ 4.5:1 (normal metin)
- [ ] Mantıksal gruplar `Modifier.semantics(mergeDescendants = true)` ile birleştirilmiş
- [ ] State açıklamaları `stateDescription` ile veriliyor (örn. "seçili")

---

## Animasyon

Basitten karmaşığa sırayla dene: `animate*AsState` → `AnimatedVisibility` /
`AnimatedContent` → `updateTransition` → `Animatable`.

```kotlin
val elevation by animateDpAsState(
    targetValue = if (isPressed) 8.dp else 2.dp,
    animationSpec = spring(dampingRatio = Spring.DampingRatioMediumBouncy),
    label = "cardElevation",   // label vermezsen inspector'da takip edemezsin
)
```

Liste öğesi giriş/çıkışı için `Modifier.animateItem()` kullan — manuel animasyon yazma.

---

## Kalite Checklist

- [ ] Renk/spacing/tipografi hardcoded değil
- [ ] Her `Content` composable'ının `@PreviewLightDark` preview'ı var
- [ ] `LazyColumn`/`LazyRow` item'larında `key` verilmiş
- [ ] Composable'lar `Unit` döner, değer döndürmez
- [ ] `Modifier` parametresi var ve zincirin başına uygulanıyor
- [ ] String'ler `stringResource` ile, hardcoded literal yok
- [ ] Side effect'ler `LaunchedEffect`/`DisposableEffect` içinde, composition body'de değil
