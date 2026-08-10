---
name: Skill hatası
about: Bir skill yanlış bilgi verdi, yanlış tetiklendi veya eksik kaldı
title: "[skill-adı] Kısa özet"
labels: skill-bug
---

## Hangi skill?

<!-- örn. android-data-layer -->

## Hata türü

- [ ] Yanlış bilgi — skill'in söylediği, gerçekte doğru değildi
- [ ] Yanlış tetikleme — bu istekte başka skill seçilmeliydi
- [ ] Eksik — skill bu durumu hiç kapsamıyor
- [ ] Çelişki — iki skill aynı konuda farklı şey söylüyor

## Ne oldu?

<!-- İstek neydi, skill ne dedi/yaptı -->

## Doğrusu ne?

<!-- Gerçekte doğru olan neydi? KAYNAK LİNKİ zorunlu:
     resmi doküman, release notes, veya derlenen/çalışan kod -->

## Kapanış kriteri

- [ ] Skill düzeltildi (küçük, doğrulanabilir değişiklik; `docs/AUTHORING.md` kuralları)
- [ ] Yanlış tetiklemeyse: vaka `evals/routing.yaml`'a eklendi
- [ ] Tutarlılık kontrolü yapıldı (`mobile-code-review` → "Skill / Doküman PR'ları")
- [ ] Skill'in `last_reviewed` damgası güncellendi
