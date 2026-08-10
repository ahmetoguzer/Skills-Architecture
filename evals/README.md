# Evals — Yönlendirme Doğrulaması

31 skill'lik koleksiyonda en kırılgan nokta içerik değil, **seçimdir**: bir istek
geldiğinde doğru skill tetikleniyor mu? Bu klasör onu ölçer.

## routing.yaml

Vaka listesi: kullanıcı ifadesi → kabul edilebilir skill(ler). `trap: true` işaretli
vakalar bilinçli tuzaklardır — iki alana birden dokunan ifadeler ("login yavaş",
"build uzun sürüyor") yanlış yönlendirmenin asıl kaynağıdır.

## Nasıl koşulur

Değerlendirici (bakım ajanının her 4. turu, ya da elle bir Claude oturumu):

1. **Yalnızca** 31 skill'in frontmatter `description` alanlarını okur — içerikleri değil.
   Gerçek tetiklemede model de yalnızca description'ları görür; eval aynı koşulda olmalı.
2. Her `input` için hangi skill(ler)i yükleyeceğine karar verir.
3. Seçim, `expected` listesindeki herhangi bir elemansa vaka **geçer**.
4. Sonuç raporlanır: `geçen/toplam`, başarısız vakalar tablo halinde
   (input → seçilen → beklenen).

## Başarısızlık çıkarsa

Çözüm her zaman **description'dadır**, içerikte değil:

- Yanlış skill seçildiyse → doğru skill'in description'ına eksik tetikleyiciyi ekle
  ve/veya yanlış seçilenin description'ını daralt (devretme cümlesi ekle)
- Düzeltme sınır tablolarını etkiliyorsa `skills/README.md` sınır kurallarını da güncelle
- Düzeltmeden sonra evali yeniden koş — başka vakayı bozmadığını gör

## Set nasıl büyür

Gerçek kullanımda her yanlış yönlendirme yaşandığında o istek buraya vaka olarak
eklenir (regresyon testi mantığı). Skill bug'ları için `.github/ISSUE_TEMPLATE/skill-bug.md`
şablonunu kullan; "yanlış skill tetiklendi" issue'su kapanırken vakası bu dosyaya girer.
