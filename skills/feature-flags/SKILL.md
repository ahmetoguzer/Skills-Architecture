---
name: feature-flags
description: >
  Feature flag ve deneme (experimentation) mimarisi: flag türleri ve yaşam süreleri,
  Remote Config / kendi sunucun ile dağıtım, varsayılan değer ve offline davranışı,
  kill switch tasarımı, A/B testi ve metrik seçimi, kademeli açılış, flag borcu temizliği,
  test edilebilirlik.

  Şu isteklerde tetiklen: "feature flag", "remote config", "A/B testi", "deney",
  "kademeli açalım", "kill switch", "özelliği kapatabilelim", "canary", "rollout",
  "flag ekle", "experiment", "bu özelliği sadece bazı kullanıcılara".
---

# Feature Flags & Experimentation Skill

Sen flag mimarisini kuran kişisin. Flag'ler güçlüdür ve **temizlenmezse teknik borca dönüşür**:
her flag kod yollarını ikiye katlar, test matrisini büyütür ve altı ay sonra kimse
hangi kombinasyonun canlıda olduğunu bilemez.

Kural: **her flag bir son kullanma tarihiyle doğar.**

## Flag Türleri

| Tür | Ömür | Sahibi | Örnek |
|---|---|---|---|
| **Release toggle** | Günler–haftalar | Geliştirici | Yarım kalan feature'ı gizle |
| **Kill switch** | Kalıcı | Operasyon | Bozulan entegrasyonu anında kapat |
| **Experiment** | Deney süresi | Ürün/analitik | A/B testi varyantı |
| **Permission / entitlement** | Kalıcı | Ürün | Premium özellik erişimi |
| **Ops flag** | Kalıcı | Operasyon | Cache süresi, sayfa boyutu, timeout |

Karıştırma: release toggle **silinmek üzere** yazılır, kill switch **kalıcıdır**.
Aynı mekanizmayı kullanırlar ama biri teknik borç, diğeri altyapıdır.

---

## Flag Tanımı — Tek Kaynak

String literal dağıtma; flag'leri tek yerde, tipli ve **son kullanma tarihiyle** tanımla:

```kotlin
enum class FeatureFlag(
    val key: String,
    val default: Boolean,
    val owner: String,
    val expiresAt: String,          // release toggle'lar için; kalıcılarda "permanent"
) {
    OFFLINE_ORDERS("offline_orders_enabled", default = false, owner = "@ahmet", expiresAt = "2026-10-01"),
    NEW_CHECKOUT("new_checkout_enabled", default = false, owner = "@ahmet", expiresAt = "2026-09-15"),
    PAYMENT_KILL_SWITCH("payment_enabled", default = true, owner = "@ops", expiresAt = "permanent"),
}
```

`expiresAt` sadece dokümantasyon değil — CI'da kontrol et:

```bash
# Süresi geçmiş flag'leri raporla (build'i kırmadan uyar)
./gradlew checkExpiredFlags
```

Süresi geçen flag için otomatik issue açılsın. Bu olmadan flag'ler asla temizlenmez;
her ekip "sonra bakarız" der ve iki yıl sonra 40 ölü flag'le kalırsınız.

---

## Varsayılan Değer Kararı

En kritik tasarım kararı: **flag okunamadığında ne olacak?**

```kotlin
// Release toggle: varsayılan KAPALI
// Sunucuya ulaşılamazsa yeni, test edilmemiş kod yolu çalışmasın
OFFLINE_ORDERS(default = false)

// Kill switch: varsayılan AÇIK
// Sunucuya ulaşılamazsa ödeme çalışmaya devam etsin —
// aksi halde Remote Config kesintisi tüm ödemeleri durdurur
PAYMENT_KILL_SWITCH(default = true)
```

Kill switch'i `default = false` yapmak klasik bir felakettir: config servisi düşünce
uygulama kendini kapatır. Kill switch **açıkça kapatılana kadar açık** olmalıdır.

---

## Sağlayıcı Soyutlaması

```kotlin
interface FeatureFlagProvider {
    fun isEnabled(flag: FeatureFlag): Boolean
    fun observe(flag: FeatureFlag): Flow<Boolean>
    fun <T> value(key: String, default: T): T
}

@Singleton
class RemoteConfigFlagProvider @Inject constructor(
    private val remoteConfig: FirebaseRemoteConfig,
    private val overrides: DebugFlagOverrides,          // sadece debug source set
) : FeatureFlagProvider {

    override fun isEnabled(flag: FeatureFlag): Boolean {
        overrides.get(flag)?.let { return it }          // QA/geliştirici override'ı
        return runCatching { remoteConfig.getBoolean(flag.key) }
            .getOrDefault(flag.default)                  // hata → varsayılan
    }
}
```

Debug override'ı **`src/debug/` içinde** tut — release APK'ya hiç girmesin.
QA'in cihazda flag'i elle açabilmesi test süresini kısaltır; aynı ekranın
production'da bulunması güvenlik açığıdır.

### Fetch stratejisi

```kotlin
remoteConfig.setConfigSettingsAsync(
    remoteConfigSettings {
        minimumFetchIntervalInSeconds = if (BuildConfig.DEBUG) 0 else 3600
    }
)
remoteConfig.setDefaultsAsync(FeatureFlag.entries.associate { it.key to it.default })
remoteConfig.fetchAndActivate()
```

- Varsayılanları **kodda** ver — ilk açılışta ağ yokken de doğru davranış olsun
- Uygulama açılışında `fetchAndActivate`'i bekleme; bloklarsan startup'ı yavaşlatırsın
- Flag değeri **oturum ortasında değişmesin** — kullanıcı bir akışın ortasındayken
  UI'ın altı kaymasın. Değeri ekran/oturum başında oku, sonra sabitle.

---

## Kod İçinde Kullanım

```kotlin
// Flag okuma UI'da değil, ViewModel/Repository'de
class CheckoutViewModel @Inject constructor(
    private val flags: FeatureFlagProvider,
    private val newCheckout: NewCheckoutUseCase,
    private val legacyCheckout: LegacyCheckoutUseCase,
) : ViewModel() {

    private val useNewFlow = flags.isEnabled(FeatureFlag.NEW_CHECKOUT)   // bir kez oku

    fun onSubmit() = viewModelScope.launch {
        if (useNewFlow) newCheckout() else legacyCheckout()
    }
}
```

Anti-pattern'ler:
- Composable içinde flag okuma → recomposition sırasında değişirse UI zıplar
- İç içe flag'ler (`if (A && !B || C)`) → test edilemez kombinasyon patlaması.
  İkiden fazla flag'in kesiştiği kod yolu varsa tasarım yanlış
- Flag'i derin katmanlara yaymak → tek bir karar noktasında oku, aşağıya boolean değil
  **davranış** (farklı implementasyon) geçir

---

## A/B Testi

Flag ≠ deney. Deney için ek olarak gerekenler:

1. **Hipotez**: "Yeni checkout akışı dönüşümü artırır"
2. **Birincil metrik** (tek): sipariş tamamlama oranı
3. **Karşı metrik**: crash oranı, ortalama süre — kazanırken başka bir şeyi bozmadığından emin ol
4. **Örneklem büyüklüğü**: önceden hesapla; "yeterli göründü" diye erken bitirme
5. **Süre**: en az bir tam hafta (hafta içi/sonu davranışı farklıdır)
6. **Atama**: kullanıcı bazlı ve **kalıcı** — aynı kullanıcı her açılışta aynı varyantı görmeli

```kotlin
val variant = flags.value("checkout_experiment", default = "control")
analytics.setUserProperty("checkout_variant", variant)     // her event'e iliştirilsin
```

Varyantı analytics'e **kullanıcı özelliği** olarak yaz; yoksa hangi grubun ne yaptığını
sonradan ayıramazsın.

Deney bittiğinde: kazananı varsayılan yap, flag'i ve kaybeden kod yolunu **sil**.
"Belki geri döneriz" diye bırakılan varyant kodu asla geri gelmez, sadece okunur.

---

## Kademeli Açılış

```
%1  → 24 saat izle (crash, ANR, hata oranı)
%10 → 24 saat izle + birincil metrik
%50 → 48 saat
%100
```

Her adımda **geri dönüş kriteri** önceden yazılı olmalı: "crash oranı %0.5'i geçerse kapat".
Kriter yoksa karar duygusal olur ve genelde "biraz daha bekleyelim" denir.

Flag ile rollout'un Play staged rollout'a göre avantajı: geri almak **anlıktır**,
yeni sürüm yayınlamak gerekmez. Riskli değişiklikleri flag arkasında gönder.

---

## Test

```kotlin
class FakeFlagProvider(private val values: Map<FeatureFlag, Boolean> = emptyMap()) : FeatureFlagProvider {
    override fun isEnabled(flag: FeatureFlag) = values[flag] ?: flag.default
}

@Test
fun `yeni checkout acikken yeni akis calisir`() = runTest {
    val vm = CheckoutViewModel(FakeFlagProvider(mapOf(NEW_CHECKOUT to true)), newCheckout, legacy)
    vm.onSubmit()
    coVerify { newCheckout() }
}
```

**Her iki yolu da test et.** Flag'li kodun en sık bug'ı: yeni yol test edilir,
eski yol (hâlâ %90 kullanıcıda çalışan) bozulur ve kimse fark etmez.

CI'da en azından "tüm flag'ler varsayılan" ve "tüm release toggle'lar açık"
konfigürasyonlarıyla test koş.

---

## Flag Borcu Temizliği

Çeyrek dönemde bir tarama yap:

```bash
# Kodda geçen ama enum'da olmayan (ölü string) flag'ler
grep -rn "isEnabled(\"" --include=*.kt .

# Enum'da olan ama kodda kullanılmayan flag'ler
for f in $(grep -oP '^\s+\K[A-Z_]+(?=\()' FeatureFlag.kt); do
  grep -q "FeatureFlag.$f" --include=*.kt -r src || echo "kullanılmıyor: $f"
done
```

Temizleme sırası: flag'i %100'e al → bir sürüm bekle → kod yolunu sil →
flag tanımını sil → Remote Config'den kaldır. Sondan başlarsan eski sürümdeki
kullanıcılar varsayılana düşer ve beklenmedik davranış alır.

---

## Checklist

- [ ] Flag'ler tek yerde tipli tanımlı; string literal dağıtılmıyor
- [ ] Her flag'in sahibi ve son kullanma tarihi var
- [ ] Release toggle varsayılanı kapalı, kill switch varsayılanı **açık**
- [ ] Varsayılanlar kodda tanımlı; ağ yokken doğru davranış
- [ ] Flag oturum/ekran başında okunuyor, ortada değişmiyor
- [ ] Composable içinde flag okunmuyor
- [ ] Debug override ekranı `src/debug/` altında, release'de yok
- [ ] İkiden fazla flag'in kesiştiği kod yolu yok
- [ ] Deney varsa: hipotez, birincil metrik, karşı metrik, süre önceden belirlenmiş
- [ ] Varyant analytics'e kullanıcı özelliği olarak yazılıyor
- [ ] Rollout adımları ve geri dönüş kriteri yazılı
- [ ] Her iki kod yolu da test ediliyor
- [ ] Süresi geçmiş flag'ler için CI kontrolü ve temizlik planı var
