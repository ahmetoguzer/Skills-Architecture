# Clean Architecture — Layer Detayları

## Katman Kuralları

Clean Architecture'ın temel prensibi: **bağımlılıklar içe doğru akar**.
Dış katmanlar iç katmanlara bağımlıdır, tersi asla olmaz.

```
UI (Compose) → ViewModel → UseCase → Repository Interface ← Repository Impl ← DataSource
                                         ↑
                                    domain katmanı
```

---

## :domain Katmanı

**Ne içerir:**
- Repository interface'leri (sadece arayüz, implementasyon yok)
- UseCase sınıfları
- Domain model sınıfları (data class, sealed class)
- Business rule validasyonları

**Ne içermez:**
- Android import'ları (`android.*`, `androidx.*` yasak)
- Retrofit/Room anotasyonları
- Context bağımlılıkları

**Neden önemli:** Domain katmanı tamamen test edilebilir pure Kotlin'dir.
Unit testleri için emülatör ya da Android framework'ü gerekmez.

### Domain Model Örneği

```kotlin
data class User(
    val id: UserId,
    val email: Email,
    val displayName: String,
    val isPremium: Boolean
)

@JvmInline
value class UserId(val value: String)

@JvmInline
value class Email(val value: String) {
    init {
        require(value.contains("@")) { "Geçersiz email formatı" }
    }
}
```

Value class kullanmak type-safety sağlar: `UserId` ile `String` karıştırılamaz.

---

## :data Katmanı

**Ne içerir:**
- Repository implementasyonları
- Remote data source (Retrofit API çağrıları)
- Local data source (Room DAO çağrıları)
- API model → Domain model mapper'lar
- Room entity → Domain model mapper'lar

**Veri akışı:**

```
Repository → Remote/Local DataSource → Mapper → Domain Model
```

### Mapper Örneği

```kotlin
class UserMapper @Inject constructor() {
    fun toDomain(dto: UserDto): User = User(
        id = UserId(dto.id),
        email = Email(dto.email),
        displayName = dto.name,
        isPremium = dto.subscriptionTier != "free"
    )

    fun toDto(domain: User): UserDto = UserDto(
        id = domain.id.value,
        email = domain.email.value,
        name = domain.displayName,
        subscriptionTier = if (domain.isPremium) "premium" else "free"
    )
}
```

Mapper'ları ayrı sınıf yap — Repository'yi şişirme.

### Offline-First Repository Pattern

```kotlin
class UserRepositoryImpl @Inject constructor(
    private val api: UserApi,
    private val dao: UserDao,
    private val mapper: UserMapper,
    private val dispatcher: CoroutineDispatcher = Dispatchers.IO
) : UserRepository {

    override fun observeUser(id: UserId): Flow<User> =
        dao.observeUser(id.value)
            .map(mapper::toDomain)
            .onStart { refreshUser(id) }

    override suspend fun refreshUser(id: UserId): Result<Unit> =
        withContext(dispatcher) {
            runCatching {
                val dto = api.getUser(id.value)
                dao.upsertUser(mapper.toEntity(dto))
            }
        }
}
```

`onStart` ile Flow başladığında remote refresh tetiklenir, ama UI anında local cache'i gösterir.

---

## :feature:* Katmanı (UI Layer)

**Ne içerir:**
- Compose screen'ler
- ViewModel'lar
- Feature-specific UI state'leri
- Navigation entry point'ler

**Ne içermez:**
- Business logic (bu UseCase'e ait)
- Direct Repository erişimi
- Network/Database kodu

### Screen Organizasyonu

Her feature için:
```
feature/login/
├── LoginScreen.kt         # Stateful (ViewModel bağlantısı)
├── LoginContent.kt        # Stateless (preview + test için)
├── LoginViewModel.kt
├── LoginUiState.kt
└── di/
    └── LoginModule.kt     # Feature-specific DI (gerekirse)
```

---

## :core:* Katmanları

### :core:common
Hiçbir Android bağımlılığı olmayan utils:
```kotlin
// Result extension'ları
suspend fun <T> Result<T>.onSuccessOrNull(block: suspend (T) -> Unit): T? =
    getOrNull()?.also { block(it) }

// Flow utilities
fun <T> Flow<T>.throttleFirst(windowDuration: Long): Flow<T> = ...
```

### :core:network
```kotlin
@Module
@InstallIn(SingletonComponent::class)
object NetworkModule {
    @Provides
    @Singleton
    fun provideOkHttp(
        authInterceptor: AuthInterceptor,
        loggingInterceptor: HttpLoggingInterceptor
    ): OkHttpClient = OkHttpClient.Builder()
        .addInterceptor(authInterceptor)
        .addInterceptor(loggingInterceptor)
        .connectTimeout(30, TimeUnit.SECONDS)
        .build()
}
```

### :core:database
```kotlin
@Database(
    entities = [UserEntity::class, ProductEntity::class],
    version = 1,
    exportSchema = true  // migration testleri için şart
)
abstract class AppDatabase : RoomDatabase() {
    abstract fun userDao(): UserDao
    abstract fun productDao(): ProductDao
}
```
