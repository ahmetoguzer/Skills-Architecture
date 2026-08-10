---
name: on-device-ai
last_reviewed: 2026-08
description: >
  Cihaz üstü ve hibrit yapay zekâ: ML Kit hazır API'leri, Gemini Nano / ML Kit GenAI ile
  cihazda üretken görevler, bulut LLM'e ne zaman gidileceği, TensorFlow Lite (LiteRT) ve
  MediaPipe ile özel model çalıştırma, model boyutu/gecikme/pil dengesi, gizlilik ve
  belirsiz çıktıların UX'i.

  Şu isteklerde tetiklen: "yapay zekâ ekle", "AI özelliği", "ML Kit", "Gemini Nano",
  "cihazda model çalıştır", "on-device", "TensorFlow Lite", "LiteRT", "MediaPipe",
  "metin özetleme", "OCR", "yüz tanıma", "görüntü sınıflandırma", "çeviri",
  "LLM entegrasyonu", "akıllı öneri", "model boyutu".
---

# On-Device AI Skill

Sen cihaz üstü AI mimarısın. En değerli katkın **modeli hiç kullanmamaya karar vermek**:
bir kural motoru veya basit bir heuristik işi görüyorsa model ekleme — boyut, gecikme,
pil ve belirsizlik maliyeti getirir.

## Karar Sırası

```
1. Deterministik kural yeterli mi?        → Evet: model kullanma
2. ML Kit'te hazır API var mı?            → Evet: onu kullan (barkod, OCR, çeviri, yüz)
3. Cihazda üretken görev mi?              → Gemini Nano / ML Kit GenAI (özet, yeniden yazma)
4. Özel model gerekiyor mu?               → LiteRT / MediaPipe
5. Büyük bağlam veya güncel bilgi mi?     → Bulut LLM (gizlilik ve maliyet değerlendir)
```

Adım adım aşağı in. Doğrudan 5'e atlamak en yaygın hata: "AI ekleyelim" isteği
çoğu zaman ML Kit'in hazır bir API'siyle, ağ çağrısı olmadan, ücretsiz çözülür.

---

## Cihazda mı, Bulutta mı?

| | Cihaz üstü | Bulut |
|---|---|---|
| Gecikme | 10–500 ms, sabit | 300 ms–5 s, ağa bağlı |
| Offline | Çalışır | Çalışmaz |
| Gizlilik | Veri cihazdan çıkmaz | Veri üçüncü tarafa gider |
| Maliyet | Sıfır (marjinal) | İstek başına ücret |
| Yetenek | Sınırlı (küçük model) | Yüksek |
| Uygulama boyutu | +2–100 MB (veya indirilebilir) | +0 |
| Cihaz desteği | Sınırlı (Nano yalnızca üst segment) | Her cihaz |

**Hibrit desen** çoğu ürün için doğru cevaptır: cihazda dene, yetmezse buluta düş.

```kotlin
class SummarizationService @Inject constructor(
    private val onDevice: OnDeviceSummarizer,
    private val cloud: CloudSummarizer,
    private val settings: PrivacySettings,
) {
    suspend fun summarize(text: String): Result<String> {
        if (onDevice.isAvailable() && text.length <= onDevice.maxInputLength) {
            onDevice.summarize(text).onSuccess { return Result.success(it) }
        }
        if (!settings.allowCloudProcessing) {
            return Result.failure(CloudProcessingNotAllowed)   // sessizce buluta gitme
        }
        return cloud.summarize(text)
    }
}
```

Kritik: kullanıcı verisi buluta gidiyorsa bu **kullanıcının bildiği ve onayladığı** bir şey
olmalı. "Cihazda çalışıyor" izlenimi verip arka planda buluta göndermek gizlilik ihlalidir
ve Play Data Safety beyanını geçersiz kılar.

---

## ML Kit — Hazır API'ler

Barkod, metin tanıma (OCR), yüz algılama, dil tanıma, çeviri, poz tahmini,
akıllı yanıt, konu sınıflandırma. Çoğu ücretsiz ve tamamen cihazda.

```kotlin
class TextRecognizerWrapper @Inject constructor() : Closeable {
    private val recognizer = TextRecognition.getClient(TextRecognizerOptions.DEFAULT_OPTIONS)

    suspend fun recognize(image: InputImage): Result<String> = suspendCancellableCoroutine { cont ->
        recognizer.process(image)
            .addOnSuccessListener { cont.resume(Result.success(it.text)) }
            .addOnFailureListener { cont.resume(Result.failure(it)) }
        cont.invokeOnCancellation { /* ML Kit task'ı iptal edilemez, sonuç yok sayılır */ }
    }

    override fun close() = recognizer.close()     // ZORUNLU — native kaynak tutar
}
```

Model dağıtımı iki seçenek:
- **Bundled**: APK'ya gömülü, ilk kullanımda hazır, +2–20 MB
- **Unbundled** (Play Services): APK küçük kalır, ilk kullanımda indirilir —
  indirme sırasındaki durumu UI'da ele al, sessizce başarısız olma

```kotlin
val moduleInstall = ModuleInstall.getClient(context)
moduleInstall.areModulesAvailable(recognizer)
    .addOnSuccessListener { if (!it.areModulesAvailable) requestInstall() }
```

Her ML Kit istemcisi `close()` ister — Composable içinde tutuyorsan `DisposableEffect`.

---

## Gemini Nano / Cihaz Üstü GenAI

Özetleme, yeniden yazma, kısa yanıt üretme, sınıflandırma gibi görevler için
cihazda çalışan küçük model. Kısıtları baştan bil:

- **Sınırlı cihaz desteği** — yalnızca belirli üst segment cihazlar. Her zaman
  `isAvailable()` kontrolü yap ve desteklenmeyen cihaz için bir yol tanımla
- **Kısa bağlam penceresi** — uzun metni parçala veya buluta düş
- **Model indirmesi** — ilk kullanımda gecikme olabilir, kullanıcıya göster
- **Deterministik değil** — aynı girdi farklı çıktı verebilir; UX'i buna göre kur

```kotlin
suspend fun isReady(): Boolean = when (summarizer.checkFeatureStatus()) {
    FeatureStatus.AVAILABLE -> true
    FeatureStatus.DOWNLOADABLE -> { summarizer.downloadFeature(); false }
    FeatureStatus.DOWNLOADING -> false
    FeatureStatus.UNAVAILABLE -> false
}
```

Cihaz üstü GenAI'yi **kritik iş akışının tek yolu yapma**. Kullanıcıların çoğunun
cihazı desteklemiyor olabilir; özellik yoksa uygulama kullanılamaz hale gelmemeli.

---

## Özel Model (LiteRT / MediaPipe)

```kotlin
class ImageClassifier @Inject constructor(
    @ApplicationContext context: Context,
) : Closeable {
    private val interpreter = Interpreter(
        FileUtil.loadMappedFile(context, "model.tflite"),
        Interpreter.Options().apply {
            numThreads = 4
            // GPU/NNAPI delegate cihaza göre değişir; başarısız olursa CPU'ya düş
        },
    )

    suspend fun classify(bitmap: Bitmap): List<Label> = withContext(Dispatchers.Default) {
        val input = preprocess(bitmap)
        val output = Array(1) { FloatArray(NUM_CLASSES) }
        interpreter.run(input, output)
        postprocess(output[0])
    }

    override fun close() = interpreter.close()
}
```

Kurallar:
- İnference **asla** main thread'de — `Dispatchers.Default` (CPU-bound)
- Interpreter oluşturmak pahalıdır: bir kez oluştur (`@Singleton`), tekrar tekrar değil
- Delegate (GPU/NNAPI) her cihazda çalışmaz; try/catch ile CPU'ya geri düş
- Model dosyasını `assets/` içinde tutuyorsan APK boyutuna eklenir —
  20 MB üstü modelleri Play Feature Delivery veya kendi CDN'inden indir
- Modeli quantize et (float32 → int8): boyut ~4x küçülür, hız artar, doğruluk biraz düşer.
  Neredeyse her zaman doğru takas.

Ölçüm yapmadan "hızlı" deme: hedef cihazlarda p50/p95 inference süresini ölç
(`android-performance` Macrobenchmark).

---

## Belirsiz Çıktının UX'i

Model çıktısı deterministik değildir. Arayüz bunu yansıtmalı:

- **Kesinmiş gibi sunma.** "Özet" yerine "AI özeti" etiketi; kullanıcı kaynağı bilsin
- **Düzenlenebilir yap.** Üretilen metin doğrudan gönderilmemeli, kullanıcı düzeltebilmeli
- **Güven eşiği koy.** Sınıflandırmada düşük skorlu sonucu göstermektense hiç gösterme
- **Geri bildirim topla.** Beğendi/beğenmedi sinyali modelin gerçek performansını gösterir
- **Yükleniyor durumu gerçekçi olsun.** 2 saniyelik inference'ta spinner yetmez,
  ne yapıldığını yaz
- **Hata yolu net olsun.** Model yoksa/başarısızsa özellik sessizce kaybolmamalı

Yanlış AI çıktısının maliyeti yüksekse (tıbbi, finansal, hukuki) **insan onayı olmadan
uygulama** — öneri olarak sun, karar kullanıcının olsun.

---

## Gizlilik ve Uyum

- Cihazda işlenen veri de **işlenmiş veridir** — ama cihazdan çıkmıyorsa
  Data Safety'de "veri toplanmıyor" diyebilirsin. Buluta gidiyorsa **beyan et**
- Kullanıcı içeriğini (fotoğraf, mesaj, ses) buluta göndermeden önce açık onay al
- Modelin eğitim verisi ve lisansı: bazı açık modeller ticari kullanıma kapalı — kontrol et
- Kişisel veri üzerinde model çalıştırıyorsan KVKK/GDPR açısından "otomatik karar verme"
  kapsamına girebilir; hukuk ekibiyle konuş
- Model çıktısını log'lama — girdi ve çıktı PII içerebilir

---

## Checklist

- [ ] Karar sırası izlendi; basit çözüm varken model eklenmedi
- [ ] ML Kit hazır API'si varsa özel model yazılmadı
- [ ] Cihaz desteği kontrol ediliyor, desteklenmeyen cihaz için yol tanımlı
- [ ] Buluta düşüş kullanıcının bildiği ve onayladığı bir davranış
- [ ] Inference main thread'de değil, `Closeable` kaynaklar kapatılıyor
- [ ] Interpreter/istemci tek örnek, tekrar tekrar oluşturulmuyor
- [ ] Delegate başarısızlığında CPU'ya geri düşülüyor
- [ ] Model boyutu APK'ya etkisi ölçüldü; büyükse indirilebilir yapıldı
- [ ] Hedef cihazlarda p50/p95 inference süresi ölçüldü
- [ ] Çıktı "AI üretimi" olarak etiketli ve düzenlenebilir
- [ ] Düşük güvenli sonuçlar gösterilmiyor, geri bildirim toplanıyor
- [ ] Data Safety beyanı gerçek veri akışıyla uyumlu; model çıktısı log'lanmıyor
