---
name: android-native-ndk
description: >
  Android NDK ve native (C/C++) katman uzmanlığı: JNI köprüsü, CMake yapılandırması,
  Kotlin/Java ↔ C++ veri geçişi, bellek yönetimi ve leak önleme, native thread'den JNI çağrısı,
  prebuilt kütüphane entegrasyonu (.so/.a), ABI yönetimi, native crash (tombstone) analizi,
  16 KB page size uyumu.

  Şu isteklerde tetiklen: "NDK", "JNI", "C++ kodu çağır", "native library", "CMakeLists",
  "libfoo.so", "external native build", "native crash", "SIGSEGV", "tombstone",
  "ffmpeg/opencv entegre et", "ABI filtre", "arm64-v8a", "16 KB page size", "native memory leak".
---

# Android Native (NDK/JNI) Skill

Sen native Android geliştirme uzmanısın. JNI sınırını **maliyetli ve tehlikeli** bir sınır
olarak ele al: her geçiş overhead getirir, her hata process'i öldürür (yakalanabilir exception değil).

## Ne Zaman Native Kod?

Meşru sebepler:
- CPU-yoğun işlem (görüntü/ses işleme, kriptografi, ML inference)
- Mevcut C/C++ kütüphanesi (FFmpeg, OpenCV, SQLite eklentileri)
- Platformlar arası paylaşılan çekirdek mantık
- Gerçek zamanlı düşük gecikmeli ses (Oboe/AAudio)

Meşru **olmayan** sebep: "kodu gizlemek". `.so` dosyası da tersine mühendisliğe açıktır,
karşılığında crash riski, build karmaşıklığı ve APK boyutu ödersin.

---

## 1. Proje Yapısı

```
app/
├── build.gradle.kts
└── src/main/cpp/
    ├── CMakeLists.txt
    ├── native-lib.cpp        → sadece JNI köprüsü (ince katman)
    ├── core/                 → saf C++ iş mantığı (JNI'dan bağımsız, test edilebilir)
    │   ├── image_processor.cpp
    │   └── image_processor.h
    └── include/
```

**Kritik prensip:** İş mantığını JNI fonksiyonlarının içine yazma. JNI dosyası sadece
tip dönüşümü yapıp saf C++ katmanını çağırsın. Böylece C++ tarafı Android'siz test edilebilir.

### CMakeLists.txt

```cmake
cmake_minimum_required(VERSION 3.22.1)
project("myapp")

add_library(myapp SHARED
    native-lib.cpp
    core/image_processor.cpp
)

target_include_directories(myapp PRIVATE ${CMAKE_CURRENT_SOURCE_DIR}/include)
target_compile_features(myapp PRIVATE cxx_std_17)
target_compile_options(myapp PRIVATE -Wall -Wextra -fvisibility=hidden)

find_library(log-lib log)
target_link_libraries(myapp ${log-lib})

# 16 KB page size uyumu (Android 15+ cihazlarda zorunlu; sürüm takvimi ve
# üçüncü parti .so denetimi için android-platform-upgrade skill'ine bak)
target_link_options(myapp PRIVATE "-Wl,-z,max-page-size=16384")
```

### build.gradle.kts

```kotlin
android {
    defaultConfig {
        externalNativeBuild {
            cmake { arguments += listOf("-DANDROID_STL=c++_shared") }
        }
        ndk { abiFilters += listOf("arm64-v8a", "armeabi-v7a", "x86_64") }
    }
    externalNativeBuild {
        cmake {
            path = file("src/main/cpp/CMakeLists.txt")
            version = "3.22.1"
        }
    }
    ndkVersion = "27.2.12479018"
    packaging { jniLibs.useLegacyPackaging = false }
}
```

ABI seçimi: `arm64-v8a` zorunlu (Play Store şartı), `armeabi-v7a` eski cihazlar için,
`x86_64` emülatör için. Her ABI APK boyutunu artırır — AAB kullanınca Play otomatik ayırır.

---

## 2. JNI Köprüsü

```kotlin
class ImageProcessor : AutoCloseable {
    private var nativeHandle: Long = nativeCreate()

    fun blur(bitmap: Bitmap, radius: Int): Bitmap {
        check(nativeHandle != 0L) { "ImageProcessor kapatılmış" }
        return nativeBlur(nativeHandle, bitmap, radius)
    }

    override fun close() {
        if (nativeHandle != 0L) {
            nativeDestroy(nativeHandle)
            nativeHandle = 0L
        }
    }

    private external fun nativeCreate(): Long
    private external fun nativeBlur(handle: Long, bitmap: Bitmap, radius: Int): Bitmap
    private external fun nativeDestroy(handle: Long)

    companion object {
        init { System.loadLibrary("myapp") }
    }
}
```

Native nesneyi `Long` handle olarak taşı ve **`AutoCloseable`** ile ömrünü açıkça yönet.
Finalizer'a güvenme — ne zaman çalışacağı belirsizdir, native bellek birikir.

```cpp
extern "C" JNIEXPORT jlong JNICALL
Java_com_example_ImageProcessor_nativeCreate(JNIEnv*, jobject) {
    return reinterpret_cast<jlong>(new ImageProcessor());
}

extern "C" JNIEXPORT void JNICALL
Java_com_example_ImageProcessor_nativeDestroy(JNIEnv*, jobject, jlong handle) {
    delete reinterpret_cast<ImageProcessor*>(handle);
}
```

### String geçişi — sızıntının bir numaralı kaynağı

```cpp
extern "C" JNIEXPORT jstring JNICALL
Java_com_example_Foo_process(JNIEnv* env, jobject, jstring input) {
    const char* chars = env->GetStringUTFChars(input, nullptr);
    if (chars == nullptr) return nullptr;          // OOM kontrolü

    std::string result = doWork(chars);

    env->ReleaseStringUTFChars(input, chars);      // ZORUNLU
    return env->NewStringUTF(result.c_str());
}
```

RAII wrapper yazıp her yerde onu kullan — manuel `Release*` çağrısı er ya da geç unutulur:

```cpp
class ScopedUtfChars {
    JNIEnv* env_; jstring s_; const char* p_;
public:
    ScopedUtfChars(JNIEnv* env, jstring s) : env_(env), s_(s), p_(env->GetStringUTFChars(s, nullptr)) {}
    ~ScopedUtfChars() { if (p_) env_->ReleaseStringUTFChars(s_, p_); }
    const char* c_str() const { return p_; }
};
```

### Büyük veri: ByteBuffer kullan

`jbyteArray` kopyalar; `ByteBuffer.allocateDirect()` kopyalamaz:

```cpp
void* data = env->GetDirectBufferAddress(buffer);
jlong size = env->GetDirectBufferCapacity(buffer);
```

Megabaytlık veri geçirirken fark 10x'e çıkar.

---

## 3. JNI Referans Kuralları

| Referans | Ömrü | Not |
|---|---|---|
| Local | Sadece o JNI çağrısı | Döngüde çok üretirsen tablo dolar → `DeleteLocalRef` |
| Global | Elle silinene kadar | `NewGlobalRef` / `DeleteGlobalRef` çifti şart |
| Weak Global | GC alabilir | Kullanmadan önce `IsSameObject(ref, nullptr)` kontrolü |

**`JNIEnv*` thread'e özeldir — asla saklama.** Native thread'den Java çağırman gerekiyorsa:

```cpp
JavaVM* g_vm;   // JNI_OnLoad'da sakla

void callFromNativeThread() {
    JNIEnv* env;
    bool attached = false;
    if (g_vm->GetEnv(reinterpret_cast<void**>(&env), JNI_VERSION_1_6) == JNI_EDETACHED) {
        g_vm->AttachCurrentThread(&env, nullptr);
        attached = true;
    }
    // ... env ile çalış
    if (attached) g_vm->DetachCurrentThread();   // unutursan thread sızar
}
```

---

## 4. Hata Yönetimi

C++ exception'ı JNI sınırından **geçemez** — process çöker. Sınırda yakala:

```cpp
extern "C" JNIEXPORT jint JNICALL
Java_com_example_Foo_compute(JNIEnv* env, jobject, jint x) {
    try {
        return core::compute(x);
    } catch (const std::exception& e) {
        jclass ex = env->FindClass("java/lang/RuntimeException");
        env->ThrowNew(ex, e.what());
        return -1;
    }
}
```

Java tarafında exception pending iken JNI çağrısı yapma; önce `env->ExceptionCheck()`.

---

## 5. Native Crash Analizi

Native crash Crashlytics'e otomatik gitmez, NDK desteğini aç:

```kotlin
plugins { id("com.google.firebase.crashlytics") }
android {
    buildTypes { release { configure<CrashlyticsExtension> { nativeSymbolUploadEnabled = true } } }
}
```

Tombstone'u sembolize et:
```bash
ndk-stack -sym app/build/intermediates/cmake/release/obj/arm64-v8a -dump tombstone.txt
```

Sinyal okuması: `SIGSEGV` = geçersiz pointer, `SIGABRT` = yakalanmamış C++ exception veya
`assert`, `SIGBUS` = hizalama hatası (genelde ARM'de yanlış cast).

Geliştirme sırasında sanitizer aç:
```cmake
target_compile_options(myapp PRIVATE -fsanitize=address -fno-omit-frame-pointer)
target_link_options(myapp PRIVATE -fsanitize=address)
```

---

## Checklist

- [ ] JNI katmanı ince; iş mantığı saf C++ tarafında ve testli
- [ ] Her `Get*Chars`/`Get*ArrayElements` için `Release*` var (tercihen RAII)
- [ ] Native handle `AutoCloseable` ile yönetiliyor, finalizer yok
- [ ] `JNIEnv*` saklanmıyor; native thread'ler attach/detach yapıyor
- [ ] C++ exception'ları JNI sınırında yakalanıyor
- [ ] `arm64-v8a` build ediliyor, 16 KB page size linker flag'i var
- [ ] Crashlytics NDK sembol yükleme açık
- [ ] Debug build'de ASan ile çalıştırılıp temiz çıktı alınmış
