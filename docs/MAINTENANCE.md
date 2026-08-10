# Haftalık Bakım Runbook'u

Bu doküman, koleksiyonu diri tutan **haftalık bakım ajanının** izlediği prosedürdür.
Ajan her pazartesi taze bir oturumda çalışır, bu dosyayı okur ve adımları sırayla uygular.
Elle bakım yapan bir insan da aynı prosedürü izler.

Amaç: skill'lerdeki sürüm bağımlı bilgilerin, platform davranış kurallarının ve
son tarihlerin **sessizce eskimesini** engellemek. Eskimiş bir skill, olmayan
skill'den kötüdür — otoriteyle yanlış söyler.

---

## 0. Sınırlar (önce oku)

- **Küçük ve doğrulanabilir değişiklikler yap.** Bu bir bakım turu, yeniden yazım değil.
  Bir skill'in yapısını, üslubunu veya kapsamını değiştirme.
- **Doğrulayamadığını değiştirme.** Bir sürüm/davranış değişikliğini güvenilir bir
  kaynaktan teyit edemiyorsan skill'e dokunma; raporda "teyit edilemedi" olarak not et.
- **Yeni skill ekleme.** Yeni alan ihtiyacı görürsen rapora öneri olarak yaz; kararı insan verir.
- **Ana dala doğrudan push yok.** Tüm değişiklikler bakım branch'i + PR ile gider.
- Değişen her kuralda `mobile-code-review` skill'inin "Skill / Doküman PR'ları"
  bölümündeki tutarlılık kontrollerini uygula (komşu skill'de kopya var mı, sınır kaydı mı).

---

## 1. Araştırma — Kaynaklar ve Etki Haritası

Her kaynağı web'den kontrol et; **son 7-10 günün** duyurularına odaklan.

| Kaynak | Ne aranır | Etkilenen skill'ler |
|---|---|---|
| Android Developers Blog / android.com/about/versions | Yeni OS sürümü, davranış değişikliği, targetSdk takvimi | `android-platform-upgrade`, `android-security`, `android-notifications` |
| AGP release notes (developer.android.com/build/releases) | Yeni AGP sürümü, DSL değişikliği | `android-gradle-build` |
| Kotlin blog / GitHub releases | Kotlin, KSP, coroutines sürümleri | `android-gradle-build`, `kmp-shared` |
| Compose BOM / Jetpack release notes | Compose, Navigation, CameraX, Media3, Credential Manager, Glance sürümleri; yeni stable API'ler; deprecation'lar | `android-compose-ui`, `android-navigation`, `android-media-camera`, `android-auth-credentials`, `android-adaptive-formfactors` |
| Play Console policy updates | targetSdk son tarihleri, Data Safety, hesap silme politikaları | `android-platform-upgrade`, `android-security`, `mobile-ci-release` |
| Apple Developer News / Xcode release notes | Yeni Xcode/Swift/iOS sürümü, App Store politikaları, Privacy Manifest | `ios-swift-architect`, `mobile-ci-release` |
| Swift.org blog | Swift dil değişiklikleri, concurrency güncellemeleri | `ios-swift-architect` |
| Kotlin Multiplatform blog / SKIE releases | KMP stable durumu, CMP iOS, SKIE sürümleri | `kmp-shared` |
| ML Kit / Gemini Nano (AICore) duyuruları | Yeni API, cihaz desteği genişlemesi, model değişikliği | `on-device-ai` |
| Firebase release notes | Crashlytics, Remote Config, FCM, Performance değişiklikleri | `mobile-observability`, `feature-flags`, `android-notifications` |
| GitHub Actions runner / fastlane releases | Runner imajı, action sürümleri, fastlane kırılmaları | `mobile-ci-release` |

Mevsimsel yoğunluk: **Google I/O (Mayıs)** ve **WWDC (Haziran)** haftalarında değişiklik
hacmi yüksek olur — o haftalarda tur daha uzun sürer, normaldir. **Ağustos** civarı Play
targetSdk eşiği yaklaşır — `android-platform-upgrade` takvim bölümünü mutlaka kontrol et.

## 2. Karşılaştırma

Her bulgu için:

1. İlgili skill'i aç, mevcut ifadeyi bul
2. Üç sınıftan hangisi olduğuna karar ver:
   - **Sürüm bump'ı** — `libs.versions.toml` örneği, araç sürümü: sessizce güncelle
   - **Davranış değişikliği** — yeni zorunluluk/kısıt: ilgili bölümü güncelle, gerekiyorsa
     tarih/sürüm damgası ekle ("Android 17 itibarıyla …")
   - **Deprecation** — skill hâlâ eski deseni öneriyorsa: eski deseni **sil**, yenisini yaz
     ("eskiden şöyleydi" bölümü ekleme — ARCHITECTURE.md P-kuralı)
3. Değişiklik bir skill sınırını etkiliyorsa sınır tablolarını da güncelle

## 3. Doğrulama

```bash
./scripts/validate.sh        # yapı + katalog senkronu
./scripts/check-links.sh     # göreli linkler
```

İkisi de temiz olmadan teslim etme.

## 4. Teslimat

- Branch: varsayılan daldan `maintenance/YYYY-MM-DD`
- Commit'ler konu başına atomik (`docs(maintenance): bump AGP to X`, `fix(platform-upgrade): ...`)
- **PR aç**, varsayılan dala hedefle. PR gövdesi:
  - Ne değişti (skill → değişiklik → kaynak linki tablosu)
  - Teyit edilemeyen / insan kararı bekleyen notlar
  - Yeni skill önerileri (varsa)
- Değişiklik **yoksa**: PR açma, branch açma. Sadece log'a "değişiklik yok" satırı işle
  (bunun için tek satırlık commit doğrudan varsayılan dala atılabilir — tek istisna budur).

## 4b. Tazelik damgası

Bu turda içeriğine dokunduğun **veya** okuyup güncel olduğunu teyit ettiğin her skill'in
frontmatter'ındaki `last_reviewed` alanını içinde bulunulan aya güncelle (`YYYY-MM`).
`validate.sh` 6 aydan eski damgalar için uyarı verir — hedef, hiçbir skill'in
uyarıya düşmemesi. Uyarıdaki skill'ler bir sonraki turun öncelikli inceleme listesidir.

---

## 4c. Periyodik ek görevler

Tur numarası = `docs/maintenance-log.md`'deki veri satırı sayısı + 1.

**Her 4. tur — yönlendirme evali** (`evals/README.md` prosedürü):
`evals/routing.yaml`'daki tüm vakaları, yalnızca skill description'larını okuyarak koş.
Sonucu rapora yaz (geçen/toplam + başarısız vakalar tablosu). Başarısızlık varsa
düzeltme **description seviyesindedir** (tetikleyici ekle / daralt); düzeltmeyi
bakım PR'ına dahil et ve evali yeniden koşup sonucu doğrula.

**Her 12. tur — derin tutarlılık denetimi:**
Haftalık kaynak taramasına ek olarak tüm koleksiyonu çapraz tara —
`mobile-code-review` skill'inin "Skill / Doküman PR'ları" bölümündeki kontrollerle:
aynı konunun iki skill'de anlatılması, çelişen kod örnekleri, güncelliğini yitirmiş
sınır tabloları, description tetikleyici çakışmaları. Bulgular normal bakım PR'ının
ayrı bir bölümünde raporlanır; incelenen ve temiz çıkan skill'lerin damgası güncellenir.

---

## 5. Log

Her turda `docs/maintenance-log.md` dosyasının **başına** bir satır ekle:

```markdown
| 2026-08-17 | 3 güncelleme (AGP 8.9, Compose BOM, Play eşiği) | PR #12 |
| 2026-08-10 | Değişiklik yok | — |
```

Bu log, hangi haftaların tarandığını kanıtlar; bir hafta atlanırsa görünür olur.

---

## Tur Checklist

- [ ] Tablodaki tüm kaynaklar kontrol edildi (erişilemeyenler raporda belirtildi)
- [ ] Her değişiklik güvenilir kaynakla teyitli, kaynak PR'da linkli
- [ ] Deprecated desen silindi, "eskiden" bölümü eklenmedi
- [ ] Tutarlılık kontrolü yapıldı (kopya kural / sınır kayması yok)
- [ ] `validate.sh` + `check-links.sh` temiz
- [ ] PR açıldı ve özet tablosu içeriyor (veya "değişiklik yok" log'landı)
- [ ] `maintenance-log.md` güncellendi
