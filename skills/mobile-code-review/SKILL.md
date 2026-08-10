---
name: mobile-code-review
last_reviewed: 2026-08
description: >
  Android/iOS kod incelemesi: PR review, mimari uyum kontrolü, katman ihlali tespiti,
  coroutine/concurrency hataları, bellek sızıntısı riskleri, Compose anti-pattern'leri,
  güvenlik açıkları ve test eksikliği tespiti. Bulguları önem sırasına göre raporlar.

  Şu isteklerde tetiklen: "kodu incele", "review yap", "PR'a bak", "bu kod doğru mu",
  "code review", "refactor önerisi", "anti-pattern var mı", "mimariye uygun mu",
  "bu ViewModel'de sorun var mı", "PR review checklist".
---

# Mobile Code Review Skill

Sen deneyimli bir reviewer'sın. İşin hata bulmak değil, **kodun bakımını kolaylaştırmak.**
Her yorumun bir gerekçesi ve mümkünse bir alternatifi olmalı.

## Bulguları Sınıflandır

| Seviye | Anlamı | Örnek |
|---|---|---|
| 🔴 **Blocker** | Merge edilmemeli | Veri kaybı, güvenlik açığı, crash, ana thread'de I/O |
| 🟠 **Major** | Bu PR'da düzeltilmeli | Katman ihlali, sızdırılan coroutine, test edilemez tasarım |
| 🟡 **Minor** | Düzeltilse iyi olur | İsimlendirme, ölü kod, eksik `key` |
| 🔵 **Nit / Öneri** | Yazarın takdiri | Stil tercihi, alternatif yaklaşım |

Nit'leri açıkça "nit:" diye işaretle — yazar neyin zorunlu neyin tercih olduğunu bilsin.
Yorum sayısı 20'yi geçiyorsa yorum yazmayı bırak, sohbet iste: PR muhtemelen fazla büyük.

---

## İnceleme Sırası

1. **PR açıklaması ve kapsam** — tek bir şey mi yapıyor? 400+ satırsa bölünmeli mi?
2. **Mimari uyum** — katman kuralları çiğnenmiş mi?
3. **Doğruluk** — edge case, null, boş liste, hata yolu
4. **Concurrency** — scope, dispatcher, iptal, race
5. **Kaynak yönetimi** — leak, close, unregister
6. **Test** — davranış test edilmiş mi, yoksa sadece coverage mi?
7. **Okunabilirlik** — isim, fonksiyon boyu, gereksiz soyutlama

---

## Android — Sık Yakalanan Hatalar

### Katman ihlalleri (🟠)

```kotlin
// ViewModel'de data katmanı import'u
import com.example.data.remote.ProductDto      // ihlal: UI, DTO görmemeli

// domain'de Android import'u
import android.content.Context                 // ihlal: domain saf Kotlin olmalı

// Compose'da doğrudan repository çağrısı
val products = repository.getProducts()        // ihlal: composable'da iş mantığı
```

### Coroutine hataları (🔴/🟠)

```kotlin
// 🔴 GlobalScope — iptal edilemez, sızar
GlobalScope.launch { syncData() }

// 🟠 Hardcoded dispatcher — test edilemez
withContext(Dispatchers.IO) { }                // inject et

// 🔴 İptali yutan catch — CancellationException yakalanmamalı
try { work() } catch (e: Exception) { log(e) } // → catch (e: CancellationException) { throw e }

// 🟠 lifecycleScope.launch içinde collect — arka planda çalışmaya devam eder
lifecycleScope.launch { flow.collect { } }     // → repeatOnLifecycle(STARTED) { }

// 🟠 runBlocking main thread'de — ANR riski
runBlocking { repository.load() }
```

### Compose anti-pattern'leri (🟡/🟠)

```kotlin
// 🟡 key verilmemiş lazy list
items(products) { }                            // → items(products, key = { it.id })

// 🟠 composition'da yan etki
@Composable fun Screen() {
    analytics.track("screen_view")             // → LaunchedEffect(Unit) { }
}

// 🟠 collectAsState (lifecycle-aware değil)
val state by viewModel.state.collectAsState()  // → collectAsStateWithLifecycle()

// 🟡 Modifier parametresi yok veya zincire uygulanmamış
@Composable fun Card(title: String)            // → modifier: Modifier = Modifier

// 🟠 composition'da ağır hesaplama
val sorted = items.sortedBy { it.name }        // → remember(items) { ... }
```

### Kaynak sızıntısı (🔴/🟠)

- Singleton'a Activity `Context` verilmiş → `applicationContext`
- `BroadcastReceiver` register edilmiş ama unregister yok
- `Cursor` / `InputStream` `use { }` bloğunda değil
- Native handle `close()` edilmiyor
- Listener/callback lifecycle'a bağlı değil

### Güvenlik (🔴)

- API key/secret kaynak kodunda
- Token `SharedPreferences`'ta düz metin
- `WebView`'da `setJavaScriptEnabled(true)` + `addJavascriptInterface`
- Log'da PII veya token
- Deep link parametresi valide edilmeden kullanılıyor
- `exported="true"` gereksiz yere

---

## iOS — Sık Yakalanan Hatalar

```swift
// 🔴 Force unwrap
let user = users.first!                        // → guard let / if let

// 🟠 UI güncellemesi MainActor dışında
DispatchQueue.global().async { self.label.text = "x" }

// 🟠 Retain cycle
Task { self.load() }                           // uzun ömürlüyse [weak self]

// 🟠 @unchecked Sendable gerekçesiz
// 🟡 Yeni kodda ObservableObject/Combine — @Observable + async/await tercih edilmeli
// 🔴 Keychain yerine UserDefaults'ta token
```

---

## Test İncelemesi

Şunları sor:
- Yeni davranışın **hata yolu** test edilmiş mi, yoksa sadece happy path mi?
- Test, implementasyonu değil **davranışı** mı doğruluyor? (Aşırı `verify` kırılganlık üretir)
- Test adı ne yaptığını anlatıyor mu?
- Assert var mı? (Sadece çağırıp assert etmeyen "smoke" testleri coverage şişirir)
- Flaky riski: gerçek `delay`, `Thread.sleep`, paylaşılan state?

---

## Yorum Yazma Biçimi

**Kötü:** "Bu yanlış."

**İyi:**
> 🟠 `Dispatchers.IO` burada sabitlenmiş, bu yüzden bu UseCase test edilirken gerçek thread
> havuzu kullanılıyor ve test yavaşlıyor. `@IoDispatcher` ile inject edersek testte
> `UnconfinedTestDispatcher` verebiliriz — `GetProductsUseCase` bunu zaten yapıyor, aynı deseni
> takip edebiliriz.

Formül: **ne** + **neden sorun** + **öneri (mümkünse projeden örnekle)**.

Beğendiğin bir şeyi de söyle. Sadece hata listeleyen review, insanları review'dan kaçırır.

---

## Skill / Doküman PR'ları

PR bir SKILL.md veya standart dokümanı değiştiriyorsa, kod maddelerine ek olarak
**tutarlılık çürümesini** ara — iki skill'in aynı konuyu farklı anlatması, koddaki
çelişkiden daha sinsi bozulur çünkü derleyici yakalamaz:

- Değişen kural, komşu skill'lerde de geçiyor mu? (`grep` ile anahtar terimi tüm
  `skills/` altında ara) — geçiyorsa ya oradan sil ya devretme notuna çevir;
  aynı kural iki yerde **yazılmaz**, referanslanır
- Değişiklik bir sınırı kaydırıyorsa sınır tabloları (`skills/README.md`,
  `docs/ARCHITECTURE.md`) ve iki tarafın `description` devretme cümleleri güncellendi mi?
- Yeni tetikleyici ifadeler başka bir skill'in tetikleyicileriyle çakışıyor mu?
- Kod örneği güncellendiyse, aynı deseni gösteren diğer skill'lerdeki örneklerle
  çelişiyor mu? (örn. biri `runCatching`, diğeri try/catch öneriyorsa)

---

## Review Checklist

- [ ] PR tek bir amaca hizmet ediyor ve makul boyutta
- [ ] Katman kuralları çiğnenmemiş
- [ ] Hata yolları ele alınmış, `Result`/`throws` tutarlı
- [ ] Coroutine scope/dispatcher doğru, `CancellationException` yutulmuyor
- [ ] Compose: `key`, `remember`, `collectAsStateWithLifecycle`, `Modifier` doğru
- [ ] Kaynaklar kapatılıyor, listener'lar temizleniyor
- [ ] Sır/PII log'lanmıyor, saklanmıyor
- [ ] Yeni davranış için anlamlı test var (happy + error)
- [ ] Public API'de KDoc, karmaşık mantıkta "neden" yorumu
- [ ] Ölü kod, yorum satırına alınmış kod, gereksiz TODO yok
- [ ] Skill/doküman PR'ıysa: değişen kural komşu skill'lerle çelişmiyor, sınır tabloları güncel
