---
name: android-data-layer
last_reviewed: 2026-08
description: >
  Android veri katmanı uzmanlığı: offline-first mimari, Room, Retrofit/Ktor, DataStore,
  Paging 3, WorkManager ile senkronizasyon, cache invalidation, çakışma çözümü,
  NetworkBoundResource pattern, DTO/Entity/Domain mapping ve migration stratejisi.

  Şu isteklerde tetiklen: "offline çalışsın", "cache", "Room", "veritabanı", "Retrofit",
  "API bağla", "paging", "sonsuz liste", "WorkManager", "senkronizasyon", "sync",
  "DataStore", "SharedPreferences'tan geçiş", "single source of truth", "migration",
  "DTO mapping", "pull to refresh", "veri katmanı".
---

# Android Data Layer Skill

Sen veri katmanı mimarısın. Tek bir kuralın var ve her tasarımı ona göre değerlendirirsin:
**Single Source of Truth (SSOT).** UI, ağdan değil yerel veritabanından okur; ağ sadece
veritabanını günceller.

## Neden Offline-First?

Kullanıcı asansörde, metroda, kötü kapsamada. Ağ isteğine bağımlı UI o anlarda boş ekran gösterir.
Offline-first'te ekran her zaman **son bilinen veriyi** gösterir, arka planda tazelenir.

```
UI ← Flow ← Room (SSOT) ← Sync ← Remote API
```

Ağ hatası bir "boş ekran" değil, "veri biraz eski" durumudur.

---

## 1. Repository — NetworkBoundResource

```kotlin
class ProductRepositoryImpl @Inject constructor(
    private val dao: ProductDao,
    private val api: ProductApi,
    private val mapper: ProductMapper,
    @IoDispatcher private val io: CoroutineDispatcher,
) : ProductRepository {

    // UI her zaman buradan okur — asla doğrudan api'den değil
    override fun observeProducts(): Flow<List<Product>> =
        dao.observeAll()
            .map { entities -> entities.map(mapper::toDomain) }
            .flowOn(io)

    // Tazeleme ayrı bir işlem; başarısız olursa UI'daki veri kaybolmaz
    override suspend fun refreshProducts(): Result<Unit> = withContext(io) {
        runCatching {
            val remote = api.getProducts()
            dao.upsertAll(remote.map(mapper::toEntity))
        }.recoverCatching { e -> throw e.toDomainError() }
    }
}
```

ViewModel'de:
```kotlin
val uiState = repository.observeProducts()
    .map { ProductListUiState(products = it) }
    .stateIn(viewModelScope, SharingStarted.WhileSubscribed(5_000), ProductListUiState())

fun onRefresh() = viewModelScope.launch {
    _isRefreshing.value = true
    repository.refreshProducts().onFailure { showError(it) }
    _isRefreshing.value = false
}
```

`WhileSubscribed(5_000)` — ekran arka plana gidince 5 sn sonra upstream durur,
config change'de yeniden başlamaz. Bu değer neredeyse her zaman doğrudur.

---

## 2. Üç Model Katmanı

| Model | Nerede | Amaç |
|---|---|---|
| `ProductDto` | `:data/remote` | API şekli. `@Serializable`, nullable alanlar |
| `ProductEntity` | `:data/local` | DB şekli. `@Entity`, index'ler |
| `Product` | `:domain` | İş modeli. Non-null, doğrulanmış |

Üçünü birleştirme isteğine diren. Backend bir alanı nullable yaparsa domain modelin bozulmasın;
mapper o kararı tek yerde verir:

```kotlin
class ProductMapper @Inject constructor() {
    fun toDomain(entity: ProductEntity) = Product(
        id = entity.id,
        name = entity.name,
        price = Money(entity.priceCents, Currency.valueOf(entity.currency)),
        imageUrl = entity.imageUrl.orEmpty(),      // null → boş, domain non-null kalır
    )

    fun toEntity(dto: ProductDto) = ProductEntity(
        id = dto.id ?: error("Ürün id'si null gelemez"),
        name = dto.name.orEmpty(),
        priceCents = dto.price?.times(100)?.toLong() ?: 0L,
        currency = dto.currency ?: "TRY",
        imageUrl = dto.imageUrl,
        updatedAt = System.currentTimeMillis(),
    )
}
```

---

## 3. Room

```kotlin
@Entity(
    tableName = "products",
    indices = [Index("categoryId"), Index(value = ["name"])],
)
data class ProductEntity(
    @PrimaryKey val id: String,
    val name: String,
    val priceCents: Long,
    val currency: String,
    val categoryId: String?,
    val imageUrl: String?,
    val updatedAt: Long,
)

@Dao
interface ProductDao {
    @Query("SELECT * FROM products ORDER BY name")
    fun observeAll(): Flow<List<ProductEntity>>

    @Upsert
    suspend fun upsertAll(items: List<ProductEntity>)

    @Query("DELETE FROM products WHERE updatedAt < :threshold")
    suspend fun deleteStale(threshold: Long)

    @Transaction
    suspend fun replaceAll(items: List<ProductEntity>) {
        deleteAll()
        upsertAll(items)
    }
}
```

**Migration:** `fallbackToDestructiveMigration()` production'da **kullanılmaz** — kullanıcı verisi silinir.
Her şema değişikliğinde migration yaz ve `MigrationTestHelper` ile test et:

```kotlin
val MIGRATION_3_4 = object : Migration(3, 4) {
    override fun migrate(db: SupportSQLiteDatabase) {
        db.execSQL("ALTER TABLE products ADD COLUMN categoryId TEXT")
    }
}
```

`exportSchema = true` bırak ve `schemas/` klasörünü **repoya commit et** — migration testleri buna bağlıdır.

---

## 4. Paging 3 + RemoteMediator

```kotlin
@OptIn(ExperimentalPagingApi::class)
class ProductRemoteMediator(
    private val db: AppDatabase,
    private val api: ProductApi,
) : RemoteMediator<Int, ProductEntity>() {

    override suspend fun load(
        loadType: LoadType,
        state: PagingState<Int, ProductEntity>,
    ): MediatorResult = try {
        val page = when (loadType) {
            LoadType.REFRESH -> 1
            LoadType.PREPEND -> return MediatorResult.Success(endOfPaginationReached = true)
            LoadType.APPEND -> {
                val last = state.lastItemOrNull()
                    ?: return MediatorResult.Success(endOfPaginationReached = true)
                db.remoteKeyDao().keyFor(last.id)?.nextPage
                    ?: return MediatorResult.Success(endOfPaginationReached = true)
            }
        }

        val response = api.getProducts(page = page)

        db.withTransaction {
            if (loadType == LoadType.REFRESH) {
                db.productDao().deleteAll()
                db.remoteKeyDao().deleteAll()
            }
            db.remoteKeyDao().insertAll(response.items.map { RemoteKey(it.id, page + 1) })
            db.productDao().upsertAll(response.items.map(::toEntity))
        }

        MediatorResult.Success(endOfPaginationReached = response.items.isEmpty())
    } catch (e: IOException) {
        MediatorResult.Error(e)
    } catch (e: HttpException) {
        MediatorResult.Error(e)
    }
}
```

Paging'i **sadece gerçekten uzun listelerde** kullan (yüzlerce+ öğe). 50 öğelik bir liste için
karmaşıklığı taşımaya değmez.

---

## 5. WorkManager ile Senkronizasyon

```kotlin
@HiltWorker
class SyncWorker @AssistedInject constructor(
    @Assisted context: Context,
    @Assisted params: WorkerParameters,
    private val repository: ProductRepository,
) : CoroutineWorker(context, params) {

    override suspend fun doWork(): Result = repository.refreshProducts().fold(
        onSuccess = { Result.success() },
        onFailure = { e ->
            if (runAttemptCount < 3 && e is IOException) Result.retry() else Result.failure()
        },
    )
}

val request = PeriodicWorkRequestBuilder<SyncWorker>(6, TimeUnit.HOURS)
    .setConstraints(
        Constraints.Builder()
            .setRequiredNetworkType(NetworkType.CONNECTED)
            .setRequiresBatteryNotLow(true)
            .build()
    )
    .setBackoffCriteria(BackoffPolicy.EXPONENTIAL, 30, TimeUnit.SECONDS)
    .build()

WorkManager.getInstance(context).enqueueUniquePeriodicWork(
    "product_sync", ExistingPeriodicWorkPolicy.KEEP, request,
)
```

`enqueueUniquePeriodicWork` + `KEEP` — her uygulama açılışında yeni iş kuyruğa girmesin.
Minimum periyodik aralık 15 dakikadır; daha sık istiyorsan tasarımını gözden geçir.

---

## 6. DataStore (SharedPreferences yerine)

```kotlin
private val Context.dataStore by preferencesDataStore("settings")

class SettingsRepository @Inject constructor(@ApplicationContext private val context: Context) {
    private object Keys {
        val DARK_MODE = booleanPreferencesKey("dark_mode")
    }

    val darkMode: Flow<Boolean> = context.dataStore.data
        .catch { e -> if (e is IOException) emit(emptyPreferences()) else throw e }
        .map { it[Keys.DARK_MODE] ?: false }

    suspend fun setDarkMode(enabled: Boolean) {
        context.dataStore.edit { it[Keys.DARK_MODE] = enabled }
    }
}
```

`catch` bloğu şart — bozuk dosya durumunda uygulama açılışta çökmesin.
Yapısal veri için `Preferences DataStore` yerine **Proto DataStore** kullan (tip güvenli).

---

## 7. Çakışma Çözümü (offline yazma)

Kullanıcı offline'ken yazma yapabiliyorsa bir kuyruk gerekir:

```kotlin
@Entity(tableName = "pending_operations")
data class PendingOperation(
    @PrimaryKey(autoGenerate = true) val id: Long = 0,
    val type: String,          // CREATE / UPDATE / DELETE
    val payloadJson: String,
    val createdAt: Long,
    val attemptCount: Int = 0,
)
```

Strateji seçimi:
- **Last-write-wins**: basit, çoğu uygulama için yeterli. Sunucu timestamp'i kazanır.
- **Server-wins**: kritik veri (fiyat, stok) için — yerel değişiklik reddedilir, kullanıcı bilgilendirilir.
- **Merge**: alan bazlı birleştirme. Sadece gerçekten gerekliyse; test maliyeti yüksektir.

Hangisini seçersen seç, **kullanıcıya durum göster**: "3 değişiklik gönderilmeyi bekliyor".
Sessizce kaybolan veri en kötü senaryodur.

---

## Checklist

- [ ] UI verisi tek kaynaktan (Room) okunuyor, ağdan değil
- [ ] Ağ hatası mevcut veriyi silmiyor, sadece hata state'i ekliyor
- [ ] DTO / Entity / Domain modelleri ayrı, mapper'lar test edilmiş
- [ ] `fallbackToDestructiveMigration` yok; migration'lar yazılı ve testli
- [ ] Room `schemas/` klasörü repoda
- [ ] `stateIn` ile `WhileSubscribed(5_000)` kullanılıyor
- [ ] Arka plan senkronizasyonu WorkManager ile, constraint'li
- [ ] `SharedPreferences` yerine DataStore
- [ ] Offline yazma varsa kuyruk + çakışma stratejisi tanımlı ve kullanıcıya görünür
