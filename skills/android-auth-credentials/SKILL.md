---
name: android-auth-credentials
description: >
  Modern kimlik doğrulama: Credential Manager API, passkey (WebAuthn/FIDO2), parola ve
  federated sign-in (Sign in with Google), biyometrik ile yerel kilit, oturum ve token
  yaşam döngüsü, çoklu cihaz oturumu, logout ve hesap silme akışları.

  Şu isteklerde tetiklen: "login ekranı", "giriş yap", "passkey", "Credential Manager",
  "Google ile giriş", "şifre yöneticisi", "biyometrik giriş", "oturum yönetimi",
  "otomatik giriş", "logout", "hesap silme", "SMS OTP", "2FA", "auth akışı".
  Token saklama/pinning gibi güvenlik detayı android-security ile birlikte okunur.
---

# Android Auth & Credentials Skill

Sen kimlik doğrulama akışlarını kuran kişisin. Modern Android'de artık **her giriş yöntemi
için ayrı API yok** — Credential Manager passkey, parola ve federated girişi tek arayüzde
toplar. Eski `SmartLock`, `GoogleSignInClient` ve `FingerprintManager` yollarını kullanma.

## Yöntem Seçimi

| Yöntem | Ne zaman | Güvenlik |
|---|---|---|
| **Passkey** | Yeni uygulamada varsayılan olmalı | En yüksek — phishing'e dayanıklı, sunucuda parola yok |
| Federated (Google vb.) | Hızlı onboarding isteniyorsa | Yüksek — sağlayıcıya bağımlılık |
| Parola | Mevcut kullanıcı tabanı varsa geçiş süresince | Düşük — sızıntı ve tekrar kullanım riski |
| SMS OTP | Yalnızca yasal zorunluluk varsa | Düşük — SIM swap ve yönlendirme saldırıları |
| Biyometrik | **Giriş yöntemi değil** — yerel kilit açma | Cihaz sahipliği doğrular, kimlik değil |

Son satır önemli: biyometrik doğrulama kullanıcının **kim olduğunu** kanıtlamaz,
sadece cihazın sahibinin orada olduğunu gösterir. Sunucu oturumunun yerine geçmez.

---

## Credential Manager — Giriş

```kotlin
class AuthRepository @Inject constructor(
    private val credentialManager: CredentialManager,
    private val api: AuthApi,
) {
    suspend fun signIn(activityContext: Context): AuthResult {
        val request = GetCredentialRequest(
            listOf(
                GetPublicKeyCredentialOption(requestJson = api.beginPasskeyLogin()),
                GetPasswordOption(),
                GetGoogleIdOption.Builder()
                    .setFilterByAuthorizedAccounts(true)     // önce bilinen hesaplar
                    .setServerClientId(BuildConfig.GOOGLE_SERVER_CLIENT_ID)
                    .build(),
            )
        )

        return try {
            val response = credentialManager.getCredential(activityContext, request)
            when (val cred = response.credential) {
                is PublicKeyCredential -> api.finishPasskeyLogin(cred.authenticationResponseJson)
                is PasswordCredential  -> api.loginWithPassword(cred.id, cred.password)
                is CustomCredential    -> handleGoogleId(cred)
                else -> AuthResult.Unsupported
            }
        } catch (e: GetCredentialCancellationException) {
            AuthResult.Cancelled                              // kullanıcı vazgeçti — hata değil
        } catch (e: NoCredentialException) {
            AuthResult.NoCredential                           // kayıtlı kimlik yok → kayıt akışına
        } catch (e: GetCredentialException) {
            AuthResult.Error(e.type)
        }
    }
}
```

`GetCredentialCancellationException`'ı hata olarak gösterme — kullanıcı bilinçli olarak
vazgeçti, ekrana kırmızı bir uyarı basmak can sıkıcıdır.

`setFilterByAuthorizedAccounts(true)` ile başla; `NoCredentialException` alırsan
`false` ile tekrar dene (yeni kullanıcı akışı). İki adımlı bu desen "hesabı olan hızlı girer,
olmayan kayıt olur" davranışını verir.

---

## Passkey Kaydı

```kotlin
suspend fun registerPasskey(activityContext: Context, userId: String): Boolean {
    val requestJson = api.beginPasskeyRegistration(userId)   // challenge sunucudan gelir

    return try {
        val response = credentialManager.createCredential(
            activityContext,
            CreatePublicKeyCredentialRequest(requestJson),
        ) as CreatePublicKeyCredentialResponse

        api.finishPasskeyRegistration(response.registrationResponseJson)
        true
    } catch (e: CreateCredentialException) {
        false
    }
}
```

Sunucu tarafı gereksinimleri:
- `challenge` **her istekte yeni** ve tek kullanımlık olmalı (replay koruması)
- `rpId` uygulamanın domain'i olmalı ve Digital Asset Links ile eşleşmeli
- `assetlinks.json` içinde `get_login_creds` ilişkisi ve imza SHA-256'sı bulunmalı
- Doğrulama sunucuda yapılır — istemcinin döndürdüğü JSON'a güvenilmez

Passkey'i **tek kimlik yöntemi yapma**. Cihaz kaybı senaryosu için bir kurtarma yolu
(e-posta bağlantısı, yedek kod) bulunmalı; yoksa kullanıcı hesabına erişimini kalıcı kaybeder.

---

## Biyometrik Yerel Kilit

Giriş yapmış kullanıcının uygulamayı yeniden açarken doğrulanması:

```kotlin
val canAuthenticate = BiometricManager.from(context)
    .canAuthenticate(BIOMETRIC_STRONG or DEVICE_CREDENTIAL)

when (canAuthenticate) {
    BiometricManager.BIOMETRIC_SUCCESS -> showPrompt()
    BiometricManager.BIOMETRIC_ERROR_NONE_ENROLLED -> promptEnrollment()
    else -> fallbackToPassword()            // her zaman bir yedek yol olmalı
}
```

```kotlin
val promptInfo = BiometricPrompt.PromptInfo.Builder()
    .setTitle("Kimliğinizi doğrulayın")
    .setAllowedAuthenticators(BIOMETRIC_STRONG or DEVICE_CREDENTIAL)
    .build()

BiometricPrompt(activity, executor, callback).authenticate(promptInfo, cryptoObject)
```

`CryptoObject` olmadan biyometrik yalnızca bir UI kapısıdır. Anahtar üretimi ve
kriptografik bağlama kuralları `android-security` skill'inde — orada tanımlı
`getOrCreateKey` desenini kullan, burada yeniden kurma.

`setInvalidatedByBiometricEnrollment(true)`: yeni parmak izi eklendiğinde anahtar geçersiz
olsun — başkası kendi parmağını ekleyip hesaba erişemesin.

---

## Oturum Yaşam Döngüsü

```kotlin
sealed interface AuthState {
    data object Loading : AuthState
    data object SignedOut : AuthState
    data class SignedIn(val userId: String, val requiresUnlock: Boolean) : AuthState
}

@Singleton
class AuthStateHolder @Inject constructor(private val tokenStore: TokenStore) {
    val state: StateFlow<AuthState> = tokenStore.observeSession()
        .map { session ->
            when {
                session == null -> AuthState.SignedOut
                session.isExpired -> AuthState.SignedOut
                else -> AuthState.SignedIn(session.userId, session.needsBiometricUnlock)
            }
        }
        .stateIn(appScope, SharingStarted.Eagerly, AuthState.Loading)
}
```

Navigasyon bu tek state'e bakar; her ekranda ayrı auth kontrolü yapma —
biri unutulur ve yetkisiz erişim açığı doğar.

Kurallar:
- Access token kısa ömürlü (dakikalar), refresh token rotasyonlu
- 401 yanıtında tek bir yerde refresh dene (mutex ile tekilleştir), başarısızsa oturumu kapat —
  `Interceptor`/`Authenticator` implementasyonu `android-security` skill'inde
- Sunucu tarafı oturum iptali desteklenmeli — istemci token'ı silmek yetmez

---

## Logout ve Hesap Silme

```kotlin
suspend fun signOut() {
    runCatching { api.revokeSession() }                       // sunucu tarafı iptal
    tokenStore.clear()
    credentialManager.clearCredentialState(ClearCredentialStateRequest())  // otomatik giriş kapansın
    database.clearAllTables()                                 // yerel kişisel veri
    workManager.cancelAllWorkByTag(SYNC_TAG)                  // arka plan senkronu dursun
    analytics.reset()
}
```

`clearCredentialState` çağrılmazsa kullanıcı çıkış yaptıktan hemen sonra
otomatik giriş tetiklenir ve "çıkış yapamıyorum" şikâyeti gelir.

**Hesap silme:** Play Store politikası gereği, uygulama içinde hesap oluşturulabiliyorsa
uygulama içinden **ve web üzerinden** silme yolu sunulmalı. Silme akışı:
onay → sunucuda silme → yerel temizlik → çıkış. Silinen veriyi ve saklama süresini
kullanıcıya açıkça belirt.

---

## Test

```kotlin
@Test
fun `kullanici vazgectiginde hata gosterilmez`() = runTest {
    coEvery { credentialManager.getCredential(any(), any<GetCredentialRequest>()) } throws
        GetCredentialCancellationException()

    viewModel.onSignInClick(context)

    assertThat(viewModel.state.value.error).isNull()
    assertThat(viewModel.state.value.isLoading).isFalse()
}
```

Test edilmesi gereken yollar: iptal, kayıtlı kimlik yok, ağ hatası, token süresi dolmuş,
refresh başarısız, biyometrik yok/kayıtsız, hesap kilitli.
Auth kodunda **hata yolları mutlu yoldan daha sık çalışır.**

---

## Checklist

- [ ] Credential Manager kullanılıyor; eski `GoogleSignInClient`/`FingerprintManager` yok
- [ ] Passkey destekleniyor ve kurtarma yolu var
- [ ] `assetlinks.json` yayınlanmış, `rpId` eşleşiyor
- [ ] Challenge sunucuda üretiliyor, tek kullanımlık; doğrulama sunucuda
- [ ] İptal (`Cancellation`) hata olarak gösterilmiyor
- [ ] Biyometrik `BIOMETRIC_STRONG` + `CryptoObject`, yedek yol mevcut
- [ ] Auth state tek kaynaktan okunuyor, ekran başına kontrol yok
- [ ] 401 refresh akışı mutex ile tekilleştirilmiş, döngü koruması var
- [ ] Logout: sunucu iptali + token + `clearCredentialState` + yerel veri + arka plan işleri
- [ ] Uygulama içi hesap silme akışı mevcut (Play politikası)
- [ ] Hata yolları test edilmiş
