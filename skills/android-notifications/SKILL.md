---
name: android-notifications
last_reviewed: 2026-08
description: >
  Bildirim mimarisi: FCM entegrasyonu ve token yaşam döngüsü, POST_NOTIFICATIONS izin akışı,
  kanal (channel) tasarımı, data vs notification payload kararı, deep link ile açılış,
  gruplama, sessiz saatler, foreground service bildirimleri ve teslimat oranı sorunları.

  Şu isteklerde tetiklen: "push notification", "bildirim gönder", "FCM", "Firebase Messaging",
  "bildirim izni", "notification channel", "bildirim gelmiyor", "bildirime tıklayınca aç",
  "sessiz bildirim", "bildirim grupla", "rozet/badge", "OneSignal", "bildirim testi".
---

# Android Notifications Skill

Sen bildirim mimarisini kuran kişisin. İki gerçeği baştan kabul et:
**bildirim izni artık verilmiş değil, kazanılmış bir şeydir** ve **teslimat garantisi yoktur.**

Bildirim kritik iş akışının tek taşıyıcısı olamaz. Kullanıcı bildirimi görmese de
bilgiye uygulama içinden ulaşabilmeli.

## İzin Akışı (Android 13+)

```kotlin
val permissionLauncher = rememberLauncherForActivityResult(
    ActivityResultContracts.RequestPermission()
) { granted -> viewModel.onNotificationPermissionResult(granted) }

// Uygulama açılışında DEĞİL — kullanıcı değeri anladığı anda iste
fun requestWhenRelevant() {
    if (Build.VERSION.SDK_INT < Build.VERSION_CODES.TIRAMISU) return
    when {
        hasPermission() -> Unit
        shouldShowRationale() -> showRationaleDialog()   // neden gerektiğini anlat
        else -> permissionLauncher.launch(Manifest.permission.POST_NOTIFICATIONS)
    }
}
```

**İzni açılışta isteme.** İlk ekranda gelen izin diyaloğu çoğunlukla reddedilir ve
Android 13+'ta iki kez reddedilen izin bir daha sorulamaz — kalıcı kayıp.
Doğru an: kullanıcı bir sipariş verdikten sonra "kargo durumu bildirilsin mi?".

Reddedilmişse: uygulama içi bir bildirim merkezi sun ve ayarlara giden bir yol bırak
(`Settings.ACTION_APP_NOTIFICATION_SETTINGS`). Diyaloğu tekrar tekrar gösterme.

---

## Kanal Tasarımı

Kanallar Android 8+'ta zorunlu ve **oluşturulduktan sonra önem seviyesi değiştirilemez**
(kullanıcı kontrolündedir). Bu yüzden kanal yapısını baştan doğru kur.

```kotlin
enum class NotificationChannelSpec(
    val id: String,
    @StringRes val nameRes: Int,
    val importance: Int,
) {
    ORDERS("orders", R.string.channel_orders, NotificationManager.IMPORTANCE_HIGH),
    PROMOTIONS("promotions", R.string.channel_promotions, NotificationManager.IMPORTANCE_LOW),
    SYNC("sync", R.string.channel_sync, NotificationManager.IMPORTANCE_MIN),
}
```

Kural: **kullanıcının ayrı ayrı kapatmak isteyebileceği her tür ayrı kanal olur.**
Tek kanalda toplarsan, pazarlama bildirimini kapatmak isteyen kullanıcı sipariş
bildirimini de kapatır — ve geri açmaz.

Kanal adları kullanıcıya görünür; `stringResource` kullan, lokalize et.
Yanlış kurgulanmış bir kanalı düzeltmenin tek yolu yeni id ile yeni kanal açıp
eskisini silmektir — bu da kullanıcının ayarını sıfırlar, dikkatli ol.

---

## FCM: Data vs Notification Payload

| | `notification` payload | `data` payload |
|---|---|---|
| Uygulama ön planda | `onMessageReceived` çağrılır | `onMessageReceived` çağrılır |
| Uygulama arka planda | **Sistem gösterir**, kod çalışmaz | `onMessageReceived` çağrılır |
| Özelleştirme | Sınırlı | Tam kontrol |
| Uygulama kapalı (force stop) | Gelmez | Gelmez |

**Öneri: yalnızca `data` payload kullan.** `notification` payload'da arka planda kodun
hiç çalışmaz — analytics, yerelleştirme, deep link kararı, kullanıcı ayarı kontrolü
hiçbiri uygulanamaz.

```kotlin
@AndroidEntryPoint
class AppMessagingService : FirebaseMessagingService() {

    @Inject lateinit var notifier: AppNotifier
    @Inject lateinit var tokenSync: PushTokenSync

    override fun onMessageReceived(message: RemoteMessage) {
        val payload = PushPayload.from(message.data) ?: return
        if (!notifier.isEnabled(payload.channel)) return       // kullanıcı ayarı
        notifier.show(payload)
    }

    override fun onNewToken(token: String) {
        tokenSync.enqueueUpload(token)                          // WorkManager ile, retry'lı
    }
}
```

`onNewToken` içinde doğrudan ağ çağrısı yapma — cihaz offline olabilir.
WorkManager'a kuyrukla; token sunucuya ulaşmazsa kullanıcı hiçbir bildirim almaz
ve bu sessizce olur.

### Token yaşam döngüsü

- Token uygulama yeniden yüklenince, veri silinince veya periyodik olarak **değişir**
- Sunucuda token → kullanıcı eşlemesi tutulur; logout'ta silinir
  (yoksa cihazı devralan kişi eski kullanıcının bildirimlerini alır)
- Sunucu `UNREGISTERED`/`INVALID_ARGUMENT` yanıtı aldığında token'ı kayıttan düşürmeli

---

## Bildirim Oluşturma

```kotlin
class AppNotifier @Inject constructor(
    @ApplicationContext private val context: Context,
    private val manager: NotificationManagerCompat,
) {
    fun show(payload: PushPayload) {
        val intent = Intent(Intent.ACTION_VIEW, payload.deepLink.toUri(), context, MainActivity::class.java)

        val pendingIntent = TaskStackBuilder.create(context)
            .addNextIntentWithParentStack(intent)               // geri tuşu ana ekrana düşsün
            .getPendingIntent(payload.id.hashCode(), PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT)

        val notification = NotificationCompat.Builder(context, payload.channel.id)
            .setSmallIcon(R.drawable.ic_notification)           // tek renkli, alfa kanallı
            .setContentTitle(payload.title)
            .setContentText(payload.body)
            .setStyle(NotificationCompat.BigTextStyle().bigText(payload.body))
            .setContentIntent(pendingIntent)
            .setAutoCancel(true)
            .setGroup(payload.channel.id)                       // aynı türdekiler gruplansın
            .build()

        if (ActivityCompat.checkSelfPermission(context, POST_NOTIFICATIONS) == PERMISSION_GRANTED) {
            manager.notify(payload.id.hashCode(), notification)
        }
    }
}
```

Sık yapılan hatalar:
- `FLAG_IMMUTABLE` verilmemiş → Android 12+ crash
- Tüm bildirimlerde aynı id → her yeni bildirim öncekini ezer
- Her bildirimde farklı rastgele id → 20 bildirim birikir, kullanıcı sinirlenir
  (doğrusu: mantıksal varlık başına sabit id, örn. sipariş id'si)
- Renkli/detaylı `smallIcon` → sistem beyaz kareye çevirir; tek renk + alfa kullan
- `TaskStackBuilder` kullanılmaması → bildirimden açılan ekranda geri tuşu uygulamayı kapatır

---

## Teslimat Sorunları

"Bildirim gelmiyor" şikâyetinin gerçek sebepleri, sıklık sırasıyla:

1. **Kullanıcı izin vermemiş** veya kanalı kapatmış → uygulama içinden durumu kontrol et ve göster
2. **Token sunucuya ulaşmamış** → `onNewToken` kuyruğunu ve sunucu kaydını doğrula
3. **Uygulama force stop edilmiş** → hiçbir push gelmez, çözüm yok (kullanıcı açmalı)
4. **Üretici pil optimizasyonu** (Xiaomi, Huawei, Samsung, Oppo agresif) → kullanıcıyı
   pil optimizasyonundan çıkarma ekranına yönlendir; bu cihazlarda gecikme normaldir
5. **FCM önceliği düşük** → zaman kritik bildirimlerde `priority: high` gönder (aşırı kullanma,
   kota ve itibar cezası var)
6. **Doze modu** → cihaz uzun süre hareketsizse teslimat ertelenir

Teslimat oranını ölç: gönderilen (sunucu) vs alınan (`onMessageReceived`) vs
açılan (deep link) sayıları. Ölçmüyorsan sorunu göremezsin.

---

## Foreground Service Bildirimleri

Android 14+ tür beyanı zorunlu, Android 15+ `dataSync` için günlük kota var.
Detay: `android-platform-upgrade`.

Kullanıcıya gösterilen bildirim işin gerçek durumunu yansıtmalı ("Yükleniyor 3/10"),
"Çalışıyor" gibi içi boş bir metin değil — kullanıcı ne olduğunu anlamazsa uygulamayı kapatır.

---

## Test

```kotlin
@Test
fun `kullanici kanali kapattiysa bildirim gosterilmez`() {
    every { notifier.isEnabled(NotificationChannelSpec.PROMOTIONS) } returns false

    service.onMessageReceived(remoteMessage(channel = "promotions"))

    verify(exactly = 0) { manager.notify(any(), any()) }
}
```

Manuel test komutları:
```bash
# Yerel bildirim tetikleme
adb shell am broadcast -a com.example.DEBUG_PUSH --es payload '{"type":"order"}'

# Deep link doğrulama
adb shell am start -a android.intent.action.VIEW -d "https://example.com/orders/123"

# İzni sıfırla
adb shell pm revoke com.example.app android.permission.POST_NOTIFICATIONS
```

---

## Checklist

- [ ] `POST_NOTIFICATIONS` bağlamsal anda isteniyor, açılışta değil
- [ ] Reddedilme durumunda uygulama içi alternatif var, diyalog tekrarlanmıyor
- [ ] Kanallar kullanıcının ayrı kapatmak isteyeceği türlere göre bölünmüş ve lokalize
- [ ] Yalnızca `data` payload kullanılıyor
- [ ] `onNewToken` WorkManager ile kuyruklanıyor, logout'ta token siliniyor
- [ ] `PendingIntent` `FLAG_IMMUTABLE` ile oluşturuluyor
- [ ] Bildirim id'si mantıksal varlığa bağlı (ezme/birikme yok)
- [ ] `TaskStackBuilder` ile geri yığını doğru
- [ ] `smallIcon` tek renkli ve alfa kanallı
- [ ] Gönderilen/alınan/açılan metrikleri ölçülüyor
- [ ] Kullanıcı ayarı kontrolü bildirim gösterilmeden önce yapılıyor
