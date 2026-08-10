---
name: android-security
description: >
  Android güvenlik ve gizlilik uzmanlığı: güvenli veri saklama (EncryptedSharedPreferences,
  Keystore), network güvenliği (TLS, certificate pinning), kimlik doğrulama ve token yönetimi,
  biyometrik auth, obfuscation, root/tamper tespiti, izin (permission) hijyeni,
  Play Data Safety ve KVKK/GDPR uyumu.

  Şu isteklerde tetiklen: "güvenlik", "token nerede saklanır", "şifreleme", "keystore",
  "certificate pinning", "biyometrik", "parmak izi ile giriş", "root detection",
  "obfuscation", "API key gizle", "izin isteme", "KVKK", "GDPR", "data safety",
  "güvenlik açığı", "pentest bulgusu".
---

# Android Security Skill

Sen mobil güvenlik uzmanısın. Temel varsayımın: **cihaz düşmanca bir ortamdır.**
Kullanıcı cihazı root'lu olabilir, trafik dinleniyor olabilir, APK decompile edilecektir.

## Tehdit Modeli — Önce Bunu Sor

Kod yazmadan önce netleştir:
1. Ne korunuyor? (auth token / kişisel veri / ödeme bilgisi / iş mantığı)
2. Saldırgan kim? (aynı cihazdaki başka uygulama / ağdaki MITM / cihazı ele geçiren kişi / APK'yı tersine mühendislik yapan)
3. Kayıp maliyeti nedir?

Ödeme uygulaması ile haber uygulaması aynı kontrolleri hak etmez. Aşırı güvenlik = kullanılmayan uygulama.

---

## 1. Veri Saklama

| Veri | Nerede | Neden |
|---|---|---|
| Auth token / refresh token | `EncryptedSharedPreferences` veya Keystore-korumalı DataStore | Keystore anahtarı donanımda, çıkarılamaz |
| Kullanıcı tercihleri | Normal DataStore | Hassas değil |
| Önbellek verisi | Room (gerekirse SQLCipher) | Kişisel veri varsa şifrele |
| API key (backend'e ait) | **Uygulamada saklanmaz** | APK'dan her zaman çıkarılabilir → backend proxy kullan |

```kotlin
private val masterKey = MasterKey.Builder(context)
    .setKeyScheme(MasterKey.KeyScheme.AES256_GCM)
    .setUserAuthenticationRequired(false)
    .build()

val securePrefs = EncryptedSharedPreferences.create(
    context,
    "secure_prefs",
    masterKey,
    EncryptedSharedPreferences.PrefKeyEncryptionScheme.AES256_SIV,
    EncryptedSharedPreferences.PrefValueEncryptionScheme.AES256_GCM,
)
```

> **Gerçekçi ol:** `BuildConfig` alanı, `strings.xml`, NDK içindeki `.so` dosyası —
> hiçbiri sır saklamaz. Sadece *zorlaştırır*. Gerçek sır backend'de kalır.

### Keystore ile kendi anahtarın

```kotlin
private fun getOrCreateKey(alias: String): SecretKey {
    val ks = KeyStore.getInstance("AndroidKeyStore").apply { load(null) }
    (ks.getEntry(alias, null) as? KeyStore.SecretKeyEntry)?.let { return it.secretKey }

    return KeyGenerator.getInstance(KeyProperties.KEY_ALGORITHM_AES, "AndroidKeyStore").apply {
        init(
            KeyGenParameterSpec.Builder(
                alias,
                KeyProperties.PURPOSE_ENCRYPT or KeyProperties.PURPOSE_DECRYPT,
            )
                .setBlockModes(KeyProperties.BLOCK_MODE_GCM)
                .setEncryptionPaddings(KeyProperties.ENCRYPTION_PADDING_NONE)
                .setUserAuthenticationRequired(true)   // biyometrik/PIN şart
                .setInvalidatedByBiometricEnrollment(true)
                .build()
        )
    }.generateKey()
}
```

---

## 2. Network Güvenliği

`res/xml/network_security_config.xml`:
```xml
<network-security-config>
    <base-config cleartextTrafficPermitted="false">
        <trust-anchors>
            <certificates src="system" />
        </trust-anchors>
    </base-config>
    <debug-overrides>
        <trust-anchors>
            <certificates src="system" />
            <certificates src="user" />   <!-- sadece debug'da Charles/Proxyman -->
        </trust-anchors>
    </debug-overrides>
</network-security-config>
```

`user` CA'sını **release'de asla** güvenilir yapma — MITM kapısı açılır.

### Certificate Pinning

```kotlin
val pinner = CertificatePinner.Builder()
    .add("api.example.com", "sha256/AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA=")
    .add("api.example.com", "sha256/BBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBB=") // yedek
    .build()

val client = OkHttpClient.Builder().certificatePinner(pinner).build()
```

**Kritik:** Her zaman en az 2 pin (mevcut + yedek). Tek pin ile sertifika yenilenince
tüm kullanıcılar erişimini kaybeder ve bunu uygulama güncellemesi olmadan düzeltemezsin.
Pin'lerin sertifikadan önce sona ermeyeceğinden emin ol; takvime yenileme hatırlatması koy.

---

## 3. Token Yönetimi

```kotlin
class AuthInterceptor @Inject constructor(
    private val tokenStore: TokenStore,
) : Interceptor {
    override fun intercept(chain: Interceptor.Chain): Response {
        val token = runBlocking { tokenStore.accessToken() }
        val request = chain.request().newBuilder()
            .header("Authorization", "Bearer $token")
            .build()
        return chain.proceed(request)
    }
}

class TokenAuthenticator @Inject constructor(
    private val tokenStore: TokenStore,
    private val refreshApi: Provider<RefreshApi>,
) : Authenticator {
    private val mutex = Mutex()

    override fun authenticate(route: Route?, response: Response): Request? {
        if (response.retryCount() >= 2) return null      // sonsuz döngü koruması
        return runBlocking {
            mutex.withLock {                              // eşzamanlı refresh'i tekilleştir
                val current = tokenStore.accessToken()
                val used = response.request.header("Authorization")?.removePrefix("Bearer ")
                if (current != used) return@withLock rebuild(response, current)

                val new = refreshApi.get().refresh(tokenStore.refreshToken()).getOrNull()
                    ?: run { tokenStore.clear(); return@withLock null }
                tokenStore.save(new)
                rebuild(response, new.accessToken)
            }
        }
    }
}
```

Kurallar: access token kısa ömürlü, refresh token rotasyonlu, logout'ta ikisi de silinir,
401 döngüsü sayaçla kesilir.

---

## 4. Biyometrik Kimlik Doğrulama

```kotlin
val promptInfo = BiometricPrompt.PromptInfo.Builder()
    .setTitle("Kimliğinizi doğrulayın")
    .setSubtitle("Hesabınıza erişmek için")
    .setAllowedAuthenticators(BIOMETRIC_STRONG or DEVICE_CREDENTIAL)
    .build()

BiometricPrompt(activity, executor, callback).authenticate(promptInfo, cryptoObject)
```

Sadece `BIOMETRIC_STRONG` kullan (Class 3). `BIOMETRIC_WEAK` yüz tanıma spoof'una açıktır.
Gerçek koruma için `CryptoObject` ile bir Keystore anahtarını kilitle — yoksa biyometrik
sadece bir UI kontrolüdür ve hook'lanarak atlatılabilir.

---

## 5. Kod Koruma

```proguard
# Model sınıflarını koru ama isimlerini gizle
-keepclassmembers class com.example.data.model.** { <fields>; }

# Log çağrılarını release'de tamamen sil
-assumenosideeffects class android.util.Log {
    public static *** d(...);
    public static *** v(...);
}
```

- R8 full mode + `isMinifyEnabled = true`
- `Timber`/`Log` çağrıları release'de temizlensin — stack trace ve token log'lanmasın
- Debug menüleri, mock login gibi arka kapılar `BuildConfig.DEBUG` ile değil,
  **ayrı source set** (`src/debug/`) ile ayrılsın — release APK'ya hiç girmesin

---

## 6. Root / Tamper Tespiti

Play Integrity API kullan; kendi root kontrolünü yazma (kolay bypass edilir).

```kotlin
val response = IntegrityManagerFactory.create(context)
    .requestIntegrityToken(IntegrityTokenRequest.builder().setNonce(nonce).build())
```

Token'ı **backend'de** doğrula. İstemcide doğrularsan kontrol anlamsızdır.
Root tespitinde uygulamayı kapatma; riski backend'e bildir ve hassas işlemi (para transferi) kısıtla.

---

## 7. İzin ve Gizlilik Hijyeni

- Her izni **kullanıldığı anda** iste, açılışta toplu isteme
- `READ_EXTERNAL_STORAGE` yerine Photo Picker; `ACCESS_FINE_LOCATION` yerine mümkünse `COARSE`
- `android:exported` her component'te açıkça belirtilmiş olmalı
- `WebView`'da `setJavaScriptEnabled(true)` sadece gerekliyse; `addJavascriptInterface`'ten kaçın
- Deep link'lerde gelen parametreyi **doğrulanmamış girdi** kabul et
- `FLAG_SECURE`: hassas ekranlarda screenshot/recent apps önizlemesini engelle
- Play Console **Data Safety** formu gerçek veri akışıyla uyumlu olmalı — uyumsuzluk yayın reddi sebebidir

---

## Güvenlik Checklist

- [ ] Release'de cleartext trafik kapalı, user CA güvenilmiyor
- [ ] Certificate pinning var ve en az 2 pin tanımlı
- [ ] Token'lar `EncryptedSharedPreferences`/Keystore'da, düz metin değil
- [ ] Backend API key'i uygulamada gömülü değil
- [ ] R8 açık, release'de log çağrıları siliniyor
- [ ] `exported` tüm component'lerde açık şekilde tanımlı
- [ ] Deep link parametreleri valide ediliyor
- [ ] Biyometrik `BIOMETRIC_STRONG` + `CryptoObject` ile
- [ ] Play Integrity backend'de doğrulanıyor
- [ ] Debug arka kapıları `src/debug/` altında, release'de yok
- [ ] Hassas ekranlarda `FLAG_SECURE` set
- [ ] Data Safety formu güncel
