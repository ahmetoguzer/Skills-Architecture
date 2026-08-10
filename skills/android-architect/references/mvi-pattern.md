# MVI Pattern — Tam Implementasyon

MVI (Model-View-Intent), MVVM'in üzerine katı unidirectional data flow ekler.
Karmaşık, event-driven feature'lar için idealdir.

## Üç Bileşen

| Bileşen | Görevi |
|---------|--------|
| **Intent** | Kullanıcı aksiyonu veya sistem eventi (sealed class) |
| **State** | Tüm UI state'i tek bir immutable data class |
| **Effect** | Tek seferlik yan etkiler (navigation, snackbar) |

---

## Base Sınıflar

```kotlin
// core:common modülünde tanımla
abstract class MviViewModel<Intent, State, Effect>(
    initialState: State
) : ViewModel() {

    private val _state = MutableStateFlow(initialState)
    val state: StateFlow<State> = _state.asStateFlow()

    private val _effects = MutableSharedFlow<Effect>(extraBufferCapacity = 8)
    val effects: SharedFlow<Effect> = _effects.asSharedFlow()

    protected val currentState: State get() = _state.value

    fun sendIntent(intent: Intent) {
        viewModelScope.launch { handleIntent(intent) }
    }

    protected abstract suspend fun handleIntent(intent: Intent)

    protected fun updateState(reducer: State.() -> State) {
        _state.update(reducer)
    }

    protected suspend fun sendEffect(effect: Effect) {
        _effects.emit(effect)
    }
}
```

---

## Feature Örneği: Checkout

### Intent

```kotlin
sealed interface CheckoutIntent {
    data object LoadCart : CheckoutIntent
    data class UpdateQuantity(val itemId: String, val delta: Int) : CheckoutIntent
    data class ApplyCoupon(val code: String) : CheckoutIntent
    data object PlaceOrder : CheckoutIntent
}
```

### State

```kotlin
data class CheckoutState(
    val isLoading: Boolean = false,
    val items: List<CartItem> = emptyList(),
    val subtotal: Money = Money.ZERO,
    val discount: Money = Money.ZERO,
    val total: Money = Money.ZERO,
    val couponError: String? = null,
    val isPlacingOrder: Boolean = false
)
```

### Effect

```kotlin
sealed interface CheckoutEffect {
    data class NavigateToConfirmation(val orderId: String) : CheckoutEffect
    data class ShowError(val message: String) : CheckoutEffect
    data object ShowCouponSuccess : CheckoutEffect
}
```

### ViewModel

```kotlin
@HiltViewModel
class CheckoutViewModel @Inject constructor(
    private val getCartUseCase: GetCartUseCase,
    private val updateQuantityUseCase: UpdateQuantityUseCase,
    private val applyCouponUseCase: ApplyCouponUseCase,
    private val placeOrderUseCase: PlaceOrderUseCase
) : MviViewModel<CheckoutIntent, CheckoutState, CheckoutEffect>(CheckoutState()) {

    init {
        sendIntent(CheckoutIntent.LoadCart)
    }

    override suspend fun handleIntent(intent: CheckoutIntent) {
        when (intent) {
            is CheckoutIntent.LoadCart -> loadCart()
            is CheckoutIntent.UpdateQuantity -> updateQuantity(intent.itemId, intent.delta)
            is CheckoutIntent.ApplyCoupon -> applyCoupon(intent.code)
            is CheckoutIntent.PlaceOrder -> placeOrder()
        }
    }

    private suspend fun loadCart() {
        updateState { copy(isLoading = true) }
        getCartUseCase().fold(
            onSuccess = { cart ->
                updateState {
                    copy(
                        isLoading = false,
                        items = cart.items,
                        subtotal = cart.subtotal,
                        total = cart.total
                    )
                }
            },
            onFailure = {
                updateState { copy(isLoading = false) }
                sendEffect(CheckoutEffect.ShowError("Sepet yüklenemedi"))
            }
        )
    }

    private suspend fun applyCoupon(code: String) {
        applyCouponUseCase(code).fold(
            onSuccess = { discount ->
                updateState { copy(discount = discount, total = subtotal - discount, couponError = null) }
                sendEffect(CheckoutEffect.ShowCouponSuccess)
            },
            onFailure = {
                updateState { copy(couponError = "Geçersiz kupon kodu") }
            }
        )
    }

    private suspend fun placeOrder() {
        updateState { copy(isPlacingOrder = true) }
        placeOrderUseCase(currentState.items).fold(
            onSuccess = { orderId ->
                sendEffect(CheckoutEffect.NavigateToConfirmation(orderId))
            },
            onFailure = {
                updateState { copy(isPlacingOrder = false) }
                sendEffect(CheckoutEffect.ShowError("Sipariş verilemedi, tekrar deneyin"))
            }
        )
    }
}
```

### Compose Screen

```kotlin
@Composable
fun CheckoutScreen(
    viewModel: CheckoutViewModel = hiltViewModel(),
    onNavigateToConfirmation: (String) -> Unit
) {
    val state by viewModel.state.collectAsStateWithLifecycle()
    val snackbarHostState = remember { SnackbarHostState() }

    // Effect'leri handle et
    LaunchedEffect(Unit) {
        viewModel.effects.collect { effect ->
            when (effect) {
                is CheckoutEffect.NavigateToConfirmation ->
                    onNavigateToConfirmation(effect.orderId)
                is CheckoutEffect.ShowError ->
                    snackbarHostState.showSnackbar(effect.message)
                CheckoutEffect.ShowCouponSuccess ->
                    snackbarHostState.showSnackbar("Kupon uygulandı!")
            }
        }
    }

    CheckoutContent(
        state = state,
        onIntent = viewModel::sendIntent,
        snackbarHostState = snackbarHostState
    )
}

@Composable
private fun CheckoutContent(
    state: CheckoutState,
    onIntent: (CheckoutIntent) -> Unit,
    snackbarHostState: SnackbarHostState
) {
    Scaffold(snackbarHost = { SnackbarHost(snackbarHostState) }) { padding ->
        // UI implementation
    }
}
```

---

## MVVM vs MVI Karar Ağacı

```
Feature karmaşık mı?
├─ Hayır (basit list/detail) → MVVM yeterli
└─ Evet
   ├─ Events chain'li mi? (A → B → C sırası önemli) → MVI
   ├─ Multiple async ops aynı anda olabilir mi? → MVI
   └─ Debugging/replay önemli mi? → MVI
```
