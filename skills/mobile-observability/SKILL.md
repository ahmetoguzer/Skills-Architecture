---
name: mobile-observability
last_reviewed: 2026-08
description: >
  Üretim gözlemlenebilirliği: crash raporlama (Crashlytics/Sentry), yapılandırılmış loglama,
  custom trace ve performans izleme, non-fatal hata kaydı, breadcrumb ve kullanıcı bağlamı,
  sürüm sağlığı metrikleri (crash-free rate, ANR), alarm eşikleri ve olay müdahalesi.

  Şu isteklerde tetiklen: "crash raporlama", "Crashlytics", "Sentry", "log stratejisi",
  "üretimde ne oluyor", "crash arttı", "hata izleme", "monitoring", "alarm kur",
  "custom trace", "Firebase Performance", "non-fatal", "breadcrumb", "sürüm sağlığı",
  "kullanıcı şikayet ediyor ama tekrarlayamıyorum".
---

# Mobile Observability Skill

Sen üretim gözlemlenebilirliği kuran kişisin. Temel ilken:
**cihazda ne olduğunu göremiyorsan, kullanıcının şikâyeti tek verin demektir — bu yetersizdir.**

Mobilde debugger yok, sunucu log'u yok, canlı erişim yok. Ne ölçtüysen onu bilirsin.

## Üç Katman

| Katman | Ne yakalar | Araç |
|---|---|---|
| **Crash** | Uygulamayı öldüren hatalar | Crashlytics / Sentry |
| **Non-fatal** | Yakalanmış ama beklenmeyen durumlar | Aynı araç, `recordException` |
| **Trace** | Yavaşlık ve akış tamamlanma oranı | Firebase Performance / özel trace |

Çoğu ekip yalnızca birinciyi kurar. Asıl değer ikincidedir: **crash olmadan bozulan**
akışlar (ödeme başarısız, senkron sessizce çalışmıyor) hiçbir crash raporunda görünmez.

---

## Crash Raporlama Kurulumu

```kotlin
class CrashReporter @Inject constructor() {

    fun setUser(userId: String?) {
        // Pseudonim id — gerçek kullanıcı adı/e-posta ASLA
        FirebaseCrashlytics.getInstance().setUserId(userId?.let(::hashUserId) ?: "")
    }

    fun setContext(key: String, value: String) {
        FirebaseCrashlytics.getInstance().setCustomKey(key, value)
    }

    fun breadcrumb(message: String) {
        FirebaseCrashlytics.getInstance().log(message)
    }

    fun recordNonFatal(throwable: Throwable, context: Map<String, String> = emptyMap()) {
        FirebaseCrashlytics.getInstance().apply {
            context.forEach { (k, v) -> setCustomKey(k, v) }
            recordException(throwable)
        }
    }
}
```

Faydalı custom key'ler: ekran adı, aktif feature flag'ler, ağ durumu, oturum durumu,
son API çağrısı, deneysel varyant. Bunlar olmadan bir stack trace "nerede" der ama
"neden" demez.

**NDK crash'leri için ayrıca sembol yükleme gerekir** (`android-native-ndk`) —
yoksa native crash'ler okunamaz hex adresler olarak gelir.

---

## Non-Fatal Kaydı — Asıl Değer

```kotlin
suspend fun refreshOrders(): Result<Unit> = runCatching {
    api.getOrders().also { dao.upsertAll(it.map(::toEntity)) }
}.onFailure { e ->
    when (e) {
        is IOException -> Unit                          // ağ yok — beklenen, kaydetme
        is HttpException -> if (e.code() >= 500) {
            crashReporter.recordNonFatal(e, mapOf(
                "endpoint" to "GET /orders",
                "status" to e.code().toString(),
            ))
        }
        else -> crashReporter.recordNonFatal(e)         // beklenmeyen — mutlaka kaydet
    }
}

Unit
```

Kural: **beklenen hatayı kaydetme, beklenmeyeni kaydet.** Offline kullanıcının
`IOException`'ını raporlarsan panoyu gürültüyle doldurursun ve gerçek sinyali kaçırırsın.

Kaydedilmesi gerekenler: 5xx yanıtlar, JSON parse hataları, migration başarısızlıkları,
`IllegalStateException` benzeri "olmamalıydı" durumları, ödeme/auth akışındaki her hata.

---

## Yapılandırılmış Loglama

```kotlin
interface AppLogger {
    fun d(tag: String, message: String)
    fun w(tag: String, message: String, throwable: Throwable? = null)
    fun e(tag: String, message: String, throwable: Throwable? = null)
}

class ReleaseLogger @Inject constructor(
    private val crashReporter: CrashReporter,
) : AppLogger {
    override fun d(tag: String, message: String) = Unit          // release'de sessiz
    override fun w(tag: String, message: String, throwable: Throwable?) {
        crashReporter.breadcrumb("[$tag] $message")              // crash raporuna iliştirilir
    }
    override fun e(tag: String, message: String, throwable: Throwable?) {
        crashReporter.breadcrumb("[$tag] $message")
        throwable?.let { crashReporter.recordNonFatal(it) }
    }
}
```

Kurallar:
- **Log'a asla PII, token, tam istek/yanıt gövdesi yazma.** Log'lar crash raporuyla
  birlikte üçüncü taraf sunucusuna gider
- Release build'de `Log.d`/`Log.v` R8 ile tamamen silinsin (`android-security`)
- Breadcrumb'lar crash öncesi son ~64 olayı gösterir — ekran geçişleri, kullanıcı
  aksiyonları ve API çağrıları için ideal
- Log seviyesi tutarlı olsun: `w` = düzeltilebilir anomali, `e` = yanlış giden bir şey

---

## Custom Trace

```kotlin
suspend fun <T> traced(name: String, block: suspend () -> T): T {
    val trace = FirebasePerformance.getInstance().newTrace(name)
    trace.start()
    return try {
        block()
    } finally {
        trace.stop()
    }
}

// Kullanım — kullanıcının hissettiği akışı ölç, tek tek fonksiyonları değil
suspend fun loadOrderScreen(id: String) = traced("order_detail_load") {
    val order = getOrder(id)
    trace.putMetric("item_count", order.items.size.toLong())
    order
}
```

Neyi trace edeceğine karar verirken sor: **kullanıcı bunun yavaşladığını fark eder mi?**
Ekran açılışı, arama sonucu, ödeme tamamlama — evet. Bir mapper fonksiyonu — hayır.

Trace'e boyut (`putAttribute`) ekle: cihaz sınıfı, ağ türü, cache hit/miss.
Ortalama süre bir şey söylemez; "3G'de cache miss durumunda p95 4.2 sn" bir şey söyler.

---

## Sürüm Sağlığı Metrikleri

| Metrik | Sağlıklı | Aksiyon eşiği |
|---|---|---|
| Crash-free users | > %99.5 | < %99 → rollout durdur |
| Crash-free sessions | > %99.9 | < %99.5 → incele |
| ANR oranı (Play Vitals) | < %0.47 | üstü → Play sıralaması cezası |
| Kullanıcı algılı crash oranı | < %1.09 | üstü → Play sıralaması cezası |
| Kritik akış başarı oranı | > %98 | akışa özel |

Son satır en önemlisi ve en az izlenenidir: **ödeme tamamlama oranı** düşerse crash
olmasa bile bir şey bozulmuştur. Teknik metrikler değil, iş metrikleri erken uyarı verir.

Sürüm karşılaştırmalı izle — mutlak sayı değil, **önceki sürüme göre değişim** anlamlıdır.

---

## Alarm Kurulumu

```
Kritik (anında bildirim):
  - Yeni crash cluster'ı > 100 kullanıcı/saat
  - Crash-free users son 1 saatte %1'den fazla düştü
  - Ödeme akışı başarı oranı < %95

Uyarı (günlük özet):
  - Yeni sürümde ilk kez görülen crash
  - Non-fatal oranı %20 arttı
  - p95 ekran açılış süresi %30 arttı
```

Alarm kurarken tek kural: **eyleme geçilemeyen alarm kurma.** Kimsenin bakmadığı
alarm, gürültüdür ve gerçek alarmın da göz ardı edilmesine yol açar.
Her alarmın bir sahibi ve bir müdahale adımı olmalı.

---

## Olay Müdahalesi

Crash artışında sıra:

1. **Etkiyi ölç** — kaç kullanıcı, hangi sürüm, hangi cihaz/OS, ne zamandan beri
2. **Rollout'u durdur** — yayılmayı kes (staged rollout'un asıl faydası budur)
3. **Kill switch varsa kapat** — sürüm çıkarmadan durdurulabiliyor mu (`feature-flags`)
4. **Kök nedeni bul** — stack trace + breadcrumb + custom key'ler
5. **Karar ver** — hotfix mi, geri alma mı, beklenebilir mi
6. **Doğrula** — düzeltmeden sonra aynı cluster'ın kapandığını gör
7. **Yaz** — `change-docs` fix-doc: kök neden + tekrar önleme

Adım 1'i atlayıp doğrudan koda dalmak en yaygın hatadır. %0.01 kullanıcıyı etkileyen
egzotik bir cihaz crash'i için gece hotfix çıkarmak, riski azaltmaz artırır.

---

## Gizlilik

- Kullanıcı id'si pseudonim olmalı; e-posta/telefon/ad **asla**
- Crash raporlamayı kullanıcı onayına bağlaman gerekebilir (GDPR/KVKK) —
  hukuk ekibine sor; gerekiyorsa `setCrashlyticsCollectionEnabled(false)` ile başlat
- Custom key ve breadcrumb'ları PII taramasından geçir — en sık sızıntı buradan olur
- Data Safety formunda "crash log'ları" ve "teşhis verisi" beyan edilmeli
- Ekran görüntüsü/session replay araçları kullanıyorsan hassas alanları maskele

---

## Checklist

- [ ] Crash raporlama kurulu; NDK sembolleri yükleniyor
- [ ] Non-fatal kaydı var; beklenen hatalar (offline) gürültü yapmıyor
- [ ] Custom key'ler ekran, flag, ağ durumu gibi bağlamı taşıyor
- [ ] Breadcrumb'lar kullanıcı akışını izlenebilir kılıyor
- [ ] Log'larda PII/token yok; debug log'ları release'de siliniyor
- [ ] Kullanıcının hissettiği akışlar için custom trace var, boyutlarıyla
- [ ] Kritik iş akışlarının başarı oranı izleniyor (sadece crash değil)
- [ ] Alarmlar eyleme geçilebilir, sahibi ve müdahale adımı tanımlı
- [ ] Sürüm karşılaştırmalı pano mevcut
- [ ] Olay müdahale sırası yazılı ve ekip biliyor
- [ ] Gizlilik: pseudonim id, onay durumu, Data Safety beyanı uyumlu
