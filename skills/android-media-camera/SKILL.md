---
name: android-media-camera
last_reviewed: 2026-08
description: >
  Kamera ve medya: CameraX (preview, capture, analysis, video), Media3/ExoPlayer ile
  video-ses oynatma, medya seçimi (Photo Picker), görüntü yükleme ve önbellekleme (Coil),
  ML Kit ile görüntü analizi, medya izinleri, bellek ve pil verimliliği.

  Şu isteklerde tetiklen: "kamera", "CameraX", "fotoğraf çek", "video kaydet", "QR okut",
  "barkod tara", "galeriden seç", "Photo Picker", "video oynat", "ExoPlayer", "Media3",
  "ses çal", "resim yükle", "Coil", "Glide", "görüntü işleme", "medya izni".
---

# Android Media & Camera Skill

Sen medya katmanı uzmanısın. İki kural: **lifecycle'a bağla** ve **kaynağı serbest bırak.**
Kamera ve oynatıcı, sızdırıldığında en pahalı kaynaklardır — cihazın kamerası kilitlenir,
pil erir, arka planda video oynamaya devam eder.

## Önce: Gerçekten Kamera mı Gerekiyor?

| İhtiyaç | Doğru çözüm | Neden |
|---|---|---|
| Kullanıcı bir fotoğraf seçsin | **Photo Picker** | İzin gerektirmez, sistem UI'ı, her sürümde çalışır |
| Tek bir fotoğraf çekilsin | `ActivityResultContracts.TakePicture()` | İzin gerektirmez, sistem kamerası |
| Canlı önizleme + özel UI | **CameraX** | Ancak burada `CAMERA` izni gerekir |
| QR/barkod okuma | CameraX + ML Kit | Canlı analiz gerekiyor |

En iyi kamera kodu **yazılmayan** kamera kodudur. Basit çekim için sistem kamerasını
çağır; izin isteme, cihaz uyumluluğu ve kaynak yönetimi derdinden kurtul.

```kotlin
val picker = rememberLauncherForActivityResult(ActivityResultContracts.PickVisualMedia()) { uri ->
    uri?.let(onSelected)
}
picker.launch(PickVisualMediaRequest(ActivityResultContracts.PickVisualMedia.ImageOnly))
```

---

## CameraX Kurulumu

```kotlin
@Composable
fun CameraPreview(
    onImageCaptured: (Uri) -> Unit,
    modifier: Modifier = Modifier,
) {
    val lifecycleOwner = LocalLifecycleOwner.current
    val context = LocalContext.current
    val imageCapture = remember { ImageCapture.Builder().build() }

    AndroidView(
        modifier = modifier,
        factory = { ctx ->
            PreviewView(ctx).apply {
                scaleType = PreviewView.ScaleType.FILL_CENTER
                implementationMode = PreviewView.ImplementationMode.PERFORMANCE
            }
        },
        update = { previewView ->
            val providerFuture = ProcessCameraProvider.getInstance(context)
            providerFuture.addListener({
                val provider = providerFuture.get()
                val preview = Preview.Builder().build()
                    .also { it.surfaceProvider = previewView.surfaceProvider }

                provider.unbindAll()                       // ZORUNLU — önce çöz
                provider.bindToLifecycle(
                    lifecycleOwner,
                    CameraSelector.DEFAULT_BACK_CAMERA,
                    preview,
                    imageCapture,
                )
            }, ContextCompat.getMainExecutor(context))
        },
    )
}
```

`bindToLifecycle` sayesinde kamera, lifecycle `STARTED` olduğunda açılır ve
`STOPPED` olduğunda kapanır — elle `open`/`close` yönetmezsin. CameraX'in asıl kazancı budur.

`unbindAll()` çağırmadan yeniden bind etmek "camera already in use" hatası üretir.

### Use case sınırı

Aynı anda en fazla **üç** use case bağlanabilir ve her cihaz hepsini desteklemez:
`Preview + ImageCapture + ImageAnalysis` yaygın olarak çalışır,
`Preview + VideoCapture + ImageAnalysis` birçok cihazda çalışmaz.
Bağlama başarısız olursa daha az use case ile geri düş — try/catch şart.

---

## Görüntü Analizi (QR / barkod / ML)

```kotlin
val analysis = ImageAnalysis.Builder()
    .setBackpressureStrategy(ImageAnalysis.STRATEGY_KEEP_ONLY_LATEST)
    .setResolutionSelector(
        ResolutionSelector.Builder()
            .setResolutionStrategy(ResolutionStrategy(Size(1280, 720), FALLBACK_RULE_CLOSEST_LOWER))
            .build()
    )
    .build()
    .apply {
        setAnalyzer(cameraExecutor) { imageProxy ->
            val mediaImage = imageProxy.image
            if (mediaImage == null) { imageProxy.close(); return@setAnalyzer }

            val input = InputImage.fromMediaImage(mediaImage, imageProxy.imageInfo.rotationDegrees)
            barcodeScanner.process(input)
                .addOnSuccessListener { barcodes -> barcodes.firstOrNull()?.rawValue?.let(onScanned) }
                .addOnCompleteListener { imageProxy.close() }   // HER yolda close
        }
    }
```

**`imageProxy.close()` çağrılmazsa analiz akışı ikinci karede donar.** Hata yolunda da,
başarı yolunda da kapat — `addOnCompleteListener` bunu garanti eder.

`STRATEGY_KEEP_ONLY_LATEST`: analiz yavaşsa kareler birikmez, en yenisi işlenir.
Varsayılan (`BLOCK_PRODUCER`) ile kamera akışı tıkanır ve önizleme takılır.

Analiz çözünürlüğünü düşük tut — barkod okumak için 4K gerekmez, sadece pil ve CPU yakar.

---

## Video Oynatma (Media3)

```kotlin
@Composable
fun VideoPlayer(uri: Uri, modifier: Modifier = Modifier) {
    val context = LocalContext.current
    val lifecycleOwner = LocalLifecycleOwner.current

    val player = remember {
        ExoPlayer.Builder(context).build().apply {
            setMediaItem(MediaItem.fromUri(uri))
            prepare()
        }
    }

    // Arka plana geçince duraklat, öne gelince devam et
    DisposableEffect(lifecycleOwner) {
        val observer = LifecycleEventObserver { _, event ->
            when (event) {
                Lifecycle.Event.ON_STOP -> player.pause()
                else -> Unit
            }
        }
        lifecycleOwner.lifecycle.addObserver(observer)
        onDispose {
            lifecycleOwner.lifecycle.removeObserver(observer)
            player.release()                  // ZORUNLU — yoksa arka planda ses devam eder
        }
    }

    AndroidView(
        factory = { PlayerView(it).apply { this.player = player; useController = true } },
        modifier = modifier,
    )
}
```

`player.release()` unutulduğunda: ses arka planda çalmaya devam eder, bellek sızar,
ikinci videoyu açınca iki oynatıcı aynı anda çalar. Bu, medya kodundaki bir numaralı bug'dır.

Arka planda oynatma **gerekiyorsa** (müzik/podcast) `MediaSessionService` kullan;
Composable içinde tutulan bir player arka plan oynatma için doğru araç değildir.

---

## Görüntü Yükleme (Coil)

```kotlin
AsyncImage(
    model = ImageRequest.Builder(LocalContext.current)
        .data(product.imageUrl)
        .size(Size(width = 400, height = 400))     // hedef boyut ver — tam çözünürlük yükleme
        .crossfade(true)
        .memoryCacheKey(product.id)
        .build(),
    contentDescription = product.name,
    contentScale = ContentScale.Crop,
    placeholder = painterResource(R.drawable.placeholder),
    error = painterResource(R.drawable.image_error),
    modifier = Modifier.size(120.dp),
)
```

- Hedef boyut verilmezse tam çözünürlükte bitmap yüklenir → `OutOfMemoryError`.
  Listede 100 ürün varsa fark megabaytlarla ölçülür.
- `contentDescription` dekoratif görselde açıkça `null`, aksi halde anlamlı metin
- Liste kaydırmasında görsel titriyorsa `memoryCacheKey` sabitlenmemiş demektir

---

## İzinler

| İhtiyaç | Android 13+ | Öncesi |
|---|---|---|
| Kamera önizleme | `CAMERA` | `CAMERA` |
| Galeriden seçim | **izin yok** (Photo Picker) | `READ_EXTERNAL_STORAGE` |
| Uygulamanın kendi medyası | izin yok (scoped storage) | izin yok |
| Tüm medyaya erişim | `READ_MEDIA_IMAGES/VIDEO` + kısmi erişim | `READ_EXTERNAL_STORAGE` |

Android 14+ **kısmi fotoğraf erişimi**: kullanıcı yalnızca bazı fotoğrafları seçebilir.
`READ_MEDIA_VISUAL_USER_SELECTED` durumunu ele al — "izin verildi/verilmedi" ikilisi yetmez,
üçüncü bir durum var.

---

## Bellek ve Pil

- Analiz ve encode işlerini ayrı bir `Executor`'da çalıştır, main thread'de asla
- `cameraExecutor.shutdown()` — ekran kapanınca thread havuzunu bırak
- Bitmap'i elle işliyorsan `recycle()` veya `use { }`; büyük bitmap'i `remember` içinde tutma
- Video encode/decode uzun sürecekse foreground service + tür beyanı gerekir
  (`android-platform-upgrade`)
- Kamera açıkken ekranı uyanık tutmak için `FLAG_KEEP_SCREEN_ON` — ama ekrandan çıkınca kaldır

---

## Checklist

- [ ] Basit çekim/seçim için sistem intent'i veya Photo Picker tercih edildi
- [ ] CameraX `bindToLifecycle` ile bağlı, `unbindAll()` önce çağrılıyor
- [ ] Use case bağlama hatası yakalanıyor ve daha az use case ile geri düşülüyor
- [ ] `imageProxy.close()` her yolda çağrılıyor
- [ ] `STRATEGY_KEEP_ONLY_LATEST` ve makul analiz çözünürlüğü ayarlı
- [ ] `ExoPlayer.release()` `onDispose`'da çağrılıyor
- [ ] Arka plana geçince oynatma duraklıyor; arka plan oynatma gerekiyorsa MediaSession
- [ ] Görüntü yüklemede hedef boyut veriliyor
- [ ] Kısmi medya erişimi (Android 14+) ele alınmış
- [ ] Ağır işler ayrı executor'da, executor kapatılıyor
- [ ] Gerçek cihazda test edildi (emülatör kamerası temsili değildir)
