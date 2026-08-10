---
name: mobile-ci-release
last_reviewed: 2026-08
description: >
  Mobil CI/CD ve yayın süreci uzmanlığı: GitHub Actions ve Jenkins pipeline'ları,
  Gradle/Xcode build akışları, statik analiz kapıları (detekt/ktlint/SonarQube),
  imzalama (keystore, fastlane match), Play Console ve App Store Connect otomasyonu,
  staged rollout, versiyonlama, changelog, crash izleme ve release sonrası takip.

  Şu isteklerde tetiklen: "CI kur", "GitHub Actions", "Jenkins", "Jenkinsfile", "pipeline",
  "otomatik build", "fastlane", "Play Store'a yükle", "TestFlight", "internal testing",
  "imzalama", "keystore CI", "staged rollout", "release süreci", "versiyon numarası",
  "changelog", "PR'da test çalıştır", "lint CI", "detekt CI", "SonarQube", "quality gate",
  "Firebase App Distribution".
---

# Mobile CI/CD & Release Skill

Sen release engineer'sın. Prensibin: **her release aynı komutla, aynı şekilde üretilir.**
"Benim makinemde build alıp yükledim" bir süreç değildir.

## Pipeline Katmanları

| Tetikleyici | Ne çalışır | Süre hedefi |
|---|---|---|
| Her PR | lint + detekt + unit test + debug build | < 10 dk |
| `main` merge | yukarısı + instrumented test + internal track'e yükleme | < 25 dk |
| Tag (`v*`) | release build + imzalama + store'a staged rollout | < 40 dk |
| Gecelik | full instrumented matrix + baseline profile + benchmark | süre serbest |

PR pipeline'ı 10 dakikayı geçerse geliştiriciler onu beklemeyi bırakır ve süreç anlamını yitirir.

---

## 1. PR Workflow — Android

```yaml
name: PR Checks
on:
  pull_request:
    branches: [main]

concurrency:
  group: pr-${{ github.event.pull_request.number }}
  cancel-in-progress: true

jobs:
  check:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: actions/setup-java@v4
        with:
          distribution: temurin
          java-version: '17'
      - uses: gradle/actions/setup-gradle@v4
        with:
          cache-read-only: ${{ github.ref != 'refs/heads/main' }}

      - name: Lint & static analysis
        run: ./gradlew lintDebug detekt --continue

      - name: Unit tests
        run: ./gradlew testDebugUnitTest

      - name: Assemble debug
        run: ./gradlew assembleDebug

      - name: Publish test report
        if: always()
        uses: mikepenz/action-junit-report@v5
        with:
          report_paths: '**/build/test-results/test*/TEST-*.xml'
```

`--continue` sayesinde ilk hatada durmaz; tüm sorunları tek turda görürsün.
`concurrency` ile aynı PR'a yeni push gelince eski koşu iptal olur, runner israfı önlenir.

---

## 1b. Jenkins Pipeline (kurumsal ortam)

Birçok kurumsal Android projesi GitHub Actions değil **Jenkins** kullanır (self-hosted
runner, iç ağdaki artifact deposu, kurumsal SSO). Declarative pipeline standardı:

```groovy
pipeline {
    agent { label 'android' }

    options {
        timeout(time: 45, unit: 'MINUTES')
        disableConcurrentBuilds(abortPrevious: true)
        buildDiscarder(logRotator(numToKeepStr: '30'))
        timestamps()
    }

    environment {
        JAVA_HOME    = tool name: 'jdk-17', type: 'jdk'
        GRADLE_OPTS  = '-Dorg.gradle.jvmargs=-Xmx4g -Dorg.gradle.daemon=false'
        ANDROID_HOME = '/opt/android-sdk'
    }

    parameters {
        choice(name: 'FLAVOR', choices: ['Staging', 'Prod'], description: 'Hangi flavor')
        booleanParam(name: 'DISTRIBUTE', defaultValue: false, description: 'Testere dağıt')
    }

    stages {
        stage('Checkout') {
            steps { checkout scm }
        }

        stage('Static analysis') {
            parallel {
                stage('detekt') {
                    // Takım konfigürasyonu ve baseline projenin toplu detekt görevinde tanımlıysa
                    // onu çağır; çıplak `detekt` bunları almaz ve yanlış yeşil verir.
                    steps { sh './gradlew detektAll' }
                }
                stage('lint') {
                    steps { sh "./gradlew lint${params.FLAVOR}Debug" }
                }
            }
        }

        stage('Unit tests') {
            steps { sh "./gradlew test${params.FLAVOR}DebugUnitTest" }
            post {
                always {
                    junit '**/build/test-results/test*/TEST-*.xml'
                    recordCoverage tools: [[parser: 'JACOCO']]
                }
            }
        }

        stage('Build') {
            steps { sh "./gradlew :app:assemble${params.FLAVOR}Debug" }
        }

        stage('SonarQube') {
            when { branch pattern: 'develop|main', comparator: 'REGEXP' }
            steps {
                withSonarQubeEnv('sonar-server') { sh './gradlew sonar' }
            }
        }

        stage('Quality gate') {
            when { branch pattern: 'develop|main', comparator: 'REGEXP' }
            steps {
                timeout(time: 10, unit: 'MINUTES') {
                    waitForQualityGate abortPipeline: true
                }
            }
        }

        stage('Distribute') {
            when { expression { params.DISTRIBUTE } }
            steps {
                withCredentials([file(credentialsId: 'firebase-sa', variable: 'GOOGLE_APPLICATION_CREDENTIALS')]) {
                    sh "./gradlew appDistributionUpload${params.FLAVOR}Debug"
                }
            }
        }
    }

    post {
        always  { archiveArtifacts artifacts: '**/build/outputs/**/*.apk', allowEmptyArchive: true }
        failure { emailext to: '$DEFAULT_RECIPIENTS', subject: "FAIL: ${env.JOB_NAME} #${env.BUILD_NUMBER}", body: '${BUILD_URL}' }
        cleanup { sh './gradlew --stop' }
    }
}
```

Jenkins'e özgü tuzaklar:

| Tuzak | Çözüm |
|---|---|
| Gradle daemon paylaşılan runner'da bellek şişiriyor | `-Dorg.gradle.daemon=false`, `post { cleanup { sh './gradlew --stop' } }` |
| Workspace kirli kalıyor (önceki build'in çıktısı) | `cleanWs()` veya `checkout scm` öncesi `deleteDir()` |
| Aynı branch'e ardışık push'lar sırayla kuyruğa giriyor | `disableConcurrentBuilds(abortPrevious: true)` |
| Sırlar shell log'una sızıyor | `withCredentials` kullan; `sh "echo $TOKEN"` yazma, `set +x` |
| Emülatör testleri kararsız | Ayrı gecelik job, PR pipeline'ında değil |
| `detekt` yeşil ama takım kuralları uygulanmamış | Projenin kendi toplu görevini çağır (`detektAll` gibi) |

**Flavor'lı projelerde** görev adlarının flavor içerdiğini unutma:
`testStagingDebugUnitTest`, `assembleProdRelease`. Jenkins parametresini görev adına
enterpolasyonla geçirmek en sade yol.

---

## 1c. Statik Analiz Kapıları

Hangi CI olursa olsun, PR pipeline'ında şu üç kapı bulunur:

```bash
./gradlew detektAll          # veya projenin toplu detekt görevi
./gradlew lintDebug          # Android Lint
./gradlew sonar              # SonarQube (develop/main)
```

Kurallar:
- **Baseline dosyalarını commit'le** (`detekt-baseline.xml`) — mevcut ihlaller build'i
  kırmasın ama yenileri kırsın. Baseline büyüyorsa kural zayıflıyor demektir; küçültmeyi planla.
- SonarQube quality gate `abortPipeline: true` ile bağlansın; yoksa "gate kırmızı ama merge edildi" olur
- Yeni kod için ayrı eşik kullan (Sonar "new code" metrikleri) — eski borç yeni PR'ı bloklamasın
- Lint uyarılarını `warningsAsErrors` ile hataya çevirmeden önce mevcut uyarıları temizle,
  yoksa ekip `@Suppress` serpmeye başlar

---

## 2. İmzalama — Sır Yönetimi

Keystore **asla** repoda durmaz. Base64 olarak GitHub Secret'ta tutulur:

```bash
base64 -i release.keystore | pbcopy    # → RELEASE_KEYSTORE secret'ına yapıştır
```

```yaml
      - name: Decode keystore
        env:
          KEYSTORE_B64: ${{ secrets.RELEASE_KEYSTORE }}
        run: echo "$KEYSTORE_B64" | base64 --decode > ${{ runner.temp }}/release.keystore

      - name: Build release bundle
        env:
          KEYSTORE_PATH: ${{ runner.temp }}/release.keystore
          KEYSTORE_PASSWORD: ${{ secrets.KEYSTORE_PASSWORD }}
          KEY_ALIAS: ${{ secrets.KEY_ALIAS }}
          KEY_PASSWORD: ${{ secrets.KEY_PASSWORD }}
        run: ./gradlew bundleRelease
```

```kotlin
// build.gradle.kts
signingConfigs {
    create("release") {
        val path = System.getenv("KEYSTORE_PATH") ?: return@create
        storeFile = file(path)
        storePassword = System.getenv("KEYSTORE_PASSWORD")
        keyAlias = System.getenv("KEY_ALIAS")
        keyPassword = System.getenv("KEY_PASSWORD")
    }
}
```

Play App Signing kullan: yükleme anahtarı kaybolursa Google ile kurtarılabilir,
uygulama imzalama anahtarını hiç elinde tutmazsın.

**Adım sonunda keystore dosyasını sil** (`runner.temp` zaten job sonunda yok olur ama
self-hosted runner'da açıkça temizle).

---

## 3. Play Store'a Yükleme

```yaml
      - name: Upload to Play (internal)
        uses: r0adkll/upload-google-play@v1
        with:
          serviceAccountJsonPlainText: ${{ secrets.PLAY_SERVICE_ACCOUNT_JSON }}
          packageName: com.example.app
          releaseFiles: app/build/outputs/bundle/release/app-release.aab
          track: internal
          status: completed
          mappingFile: app/build/outputs/mapping/release/mapping.txt
```

Track ilerleyişi: `internal` → `alpha` → `beta` → `production`.
Production'a **her zaman staged rollout** ile çık:

```yaml
          track: production
          status: inProgress
          userFraction: 0.10     # %10 → 24 saat izle → %50 → %100
```

`mappingFile` yüklemeyi unutma; yoksa Play Console'daki crash stack trace'leri okunmaz.

---

## 4. iOS Pipeline — fastlane

`Fastfile`:
```ruby
platform :ios do
  desc "TestFlight'a yükle"
  lane :beta do
    setup_ci if ENV['CI']
    match(type: "appstore", readonly: true)
    increment_build_number(build_number: latest_testflight_build_number + 1)
    build_app(scheme: "App", export_method: "app-store")
    upload_to_testflight(skip_waiting_for_build_processing: true)
  end
end
```

```yaml
  ios:
    runs-on: macos-14
    steps:
      - uses: actions/checkout@v4
      - uses: maxim-lobanov/setup-xcode@v1
        with: { xcode-version: latest-stable }
      - env:
          MATCH_PASSWORD: ${{ secrets.MATCH_PASSWORD }}
          APP_STORE_CONNECT_API_KEY: ${{ secrets.ASC_API_KEY }}
        run: bundle exec fastlane beta
```

App Store Connect API key kullan (Apple ID + şifre değil) — 2FA sorunu yaşamazsın.
`match` ile sertifikaları şifreli bir repoda tut; `readonly: true` CI'ın yeni sertifika
üretip mevcutları iptal etmesini engeller.

---

## 5. Versiyonlama

```kotlin
val versionMajor = 2
val versionMinor = 4
val versionPatch = 1

android {
    defaultConfig {
        versionCode = System.getenv("GITHUB_RUN_NUMBER")?.toInt()
            ?: (versionMajor * 10000 + versionMinor * 100 + versionPatch)
        versionName = "$versionMajor.$versionMinor.$versionPatch"
    }
}
```

`versionCode` monoton artmalı ve **asla** düşmemeli. CI run number güvenli bir kaynaktır.
`versionName` semantic versioning: breaking → major, feature → minor, fix → patch.

---

## 6. Release Kontrol Listesi (yayın öncesi)

- [ ] Tüm testler yeşil, coverage düşmemiş
- [ ] Release build gerçek cihazda smoke test edilmiş (debug değil — R8 sorunları sadece release'de çıkar)
- [ ] ProGuard mapping dosyası Crashlytics ve Play'e yüklenmiş
- [ ] Baseline profile güncel
- [ ] Changelog / "Yenilikler" metni yazılmış (tüm desteklenen dillerde)
- [ ] Data Safety / Privacy Manifest güncel
- [ ] Feature flag'ler doğru varsayılanda
- [ ] Backend API sürümü uyumlu ve deploy edilmiş
- [ ] Rollback planı belli (staged rollout durdurma / önceki sürüme halt)

---

## 7. Release Sonrası İzleme

İlk 24-48 saat aktif izle:

| Metrik | Eşik | Aksiyon |
|---|---|---|
| Crash-free users | < %99 | Rollout'u durdur |
| ANR oranı | > %0.47 | Rollout'u durdur, Perfetto ile incele |
| Yeni crash cluster'ı | herhangi | Etki alanını ölç, hotfix kararı ver |
| Store puanı düşüşü | > 0.3 | Yorumları oku, regresyon ara |

Rollout durdurma refleksin hızlı olsun: %10'da yakalanan bir bug, %100'de yakalanandan
10 kat ucuzdur.

---

## Checklist

- [ ] PR pipeline < 10 dk ve her PR'da zorunlu
- [ ] Statik analiz kapıları bağlı (detekt/lint/Sonar) ve gate pipeline'ı kırıyor
- [ ] Baseline dosyaları commit'li ve büyümüyor
- [ ] Jenkins ise: daemon kapalı, workspace temizleniyor, eşzamanlı build engelli
- [ ] Gradle/SPM cache aktif
- [ ] Keystore ve sertifikalar repoda değil, secret'ta
- [ ] Release build tamamen otomatik, elle adım yok
- [ ] Mapping/dSYM otomatik yükleniyor
- [ ] Production çıkışları staged rollout ile
- [ ] versionCode otomatik ve monoton artan
- [ ] Rollback prosedürü yazılı ve denenmiş
