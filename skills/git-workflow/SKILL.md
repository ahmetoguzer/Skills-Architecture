---
name: git-workflow
description: >
  Git ve PR akışı: branch isimlendirme ve tabandan açma, atomik commit stratejisi,
  commit mesajı formatı, rebase vs merge kararı, PR açma/güncelleme, review yanıtlama,
  conflict çözümü ve release/hotfix dalları.

  Şu isteklerde tetiklen: "branch aç", "commit at", "push et", "PR aç", "rebase",
  "merge conflict", "commit mesajı", "cherry-pick", "hotfix", "değişiklikleri geri al",
  "git" geçen her istek.
---

# Git Workflow Skill

Sen sürüm kontrolü disiplinini kuran kişisin. İki kuralın var:
**ana dalda geliştirme yapılmaz** ve **push/PR onay ister.**

## Branch Stratejisi

Taban dalı projeye göre değişir — önce tespit et:

```bash
git symbolic-ref refs/remotes/origin/HEAD | sed 's@^refs/remotes/origin/@@'
git branch -r | head
```

`develop` varsa feature'lar ondan açılır, `main`/`master` tek dalsa ondan.

| Tip | Kalıp | Taban |
|---|---|---|
| Feature | `feature/order-history` | develop |
| Bug fix | `fix/crash-on-empty-cart` | develop |
| Hotfix | `hotfix/payment-timeout` | main (prod) |
| Refactor | `refactor/extract-order-mapper` | develop |
| Doküman | `docs/adr-offline-strategy` | develop |

```bash
git fetch origin develop
git checkout -b feature/order-history origin/develop
```

`git checkout -b x` (tabansız) yazma — bulunduğun daldaki yarım işi de taşırsın.

**Kod yazmadan önce branch aç.** Sonradan açmak, `git stash` dansına ve yanlış dala
yapılmış commit'lere yol açar.

---

## Commit

### Atomik commit

Bir commit **tek bir mantıksal değişiklik** içerir ve tek başına derlenir.

```
feat(orders): add offline order history

Orders are now read from Room as the single source of truth; the API
only refreshes the cache. Network failure no longer clears the list.

- OrderEntity + OrderDao with migration 4→5
- OrderRepositoryImpl with SSOT flow
- 11 unit tests
```

Format: `<type>(<scope>): <özet>`

| Type | Kullanım |
|---|---|
| `feat` | Yeni davranış |
| `fix` | Bug düzeltmesi |
| `refactor` | Davranış değişmeden yapı değişikliği |
| `perf` | Performans iyileştirmesi |
| `test` | Sadece test ekleme/düzeltme |
| `docs` | Sadece doküman |
| `build` | Gradle, bağımlılık, CI |
| `chore` | Diğer (sürüm bump, dosya taşıma) |

Kurallar:
- Özet **emir kipi**, 72 karakteri geçmez, nokta ile bitmez
- Gövde **neden**i anlatır, ne'yi değil (ne'yi diff söyler)
- Çok fazlı işte **faz başına bir commit** öner — tek dev commit review edilemez
- `WIP`, `fix`, `asd` gibi mesajlar bırakma; gerekirse `git rebase -i` yerine
  `git commit --amend` ile son commit'i düzelt

### Commit öncesi

```bash
git status                # plan dışı dosya var mı
git diff --staged         # ne commit'lenecek
```

Yanlışlıkla girenler: `local.properties`, `.idea/`, keystore, `*.log`, ekran görüntüsü,
debug amaçlı geçici dosyalar. `.gitignore`'a ekle, commit'e alma.

**Commit'ten önce kullanıcıdan onay al.**

---

## Push

```bash
git push -u origin feature/order-history
```

- İlk push'ta `-u` ile upstream kur
- Ağ hatasında yeniden dene (2s, 4s, 8s, 16s)
- **Ortak dala `--force` asla.** Kendi feature dalında gerekiyorsa
  `--force-with-lease` kullan — başkasının commit'ini ezmez

**Push için ayrı onay al.** Commit onayı push onayı değildir.

---

## Rebase vs Merge

| Durum | Tercih |
|---|---|
| Kendi feature dalını güncel tutmak | `git rebase origin/develop` — temiz tarih |
| Paylaşılan dalda (başkası da çalışıyor) | `git merge origin/develop` — tarih yeniden yazılmaz |
| PR'ı ana dala almak | Projenin kuralı (squash / merge commit / rebase) |

Kural: **Push edilmiş ve başkasının çektiği commit'leri rebase etme.**

```bash
git fetch origin develop
git rebase origin/develop
# conflict çıkarsa:
#   dosyaları düzelt → git add <dosya> → git rebase --continue
#   vazgeçersen     → git rebase --abort
```

---

## Conflict Çözümü

1. Hangi dosyalar: `git status`
2. Her dosyada **iki tarafın da niyetini anla** — körlemesine "ours"/"theirs" seçme
3. Çözdükten sonra **derle ve testleri çalıştır** — conflict çözümü sessizce davranış bozar
4. `git add` + `git rebase --continue` / `git merge --continue`

Aynı mantığı iki taraf da değiştirmişse ve hangisinin doğru olduğu belirsizse
**dur ve sor** — birinin işini sessizce silme.

---

## Pull Request

PR açıklaması plan dokümanından türer:

```markdown
## Ne
Sipariş geçmişi ekranı, offline destekli.

## Neden
Kullanıcılar kapsama dışında geçmiş siparişlerini göremiyordu (JIRA-1234).

## Nasıl
- Room SSOT; API yalnızca cache'i tazeler
- Migration 4→5 (`orders` tablosu)
- `WorkManager` ile 6 saatlik periyodik sync

## Test
- 11 yeni unit test, tümü yeşil
- Uçak modunda manuel doğrulama yapıldı

## Kapsam dışı
- Sipariş iptali (ayrı iş)

## Risk
- Şema değişikliği: migration testi eklendi, `schemas/5.json` commit'lendi
```

PR boyutu: **400 satırdan büyükse bölmeyi düşün.** Büyük PR'lar geç ve yüzeysel review alır.

**PR açmadan önce onay al.**

---

## Review Yanıtlama

- Her yoruma yanıt ver — "düzeltildi" veya gerekçeli "katılmıyorum"
- Düzeltmeleri **ayrı commit** olarak at (`fix: address review comments`),
  reviewer neyin değiştiğini görsün; merge sırasında squash edilir
- Reviewer'ın önerisi yanlışsa nedenini açıkla, sessizce görmezden gelme
- Approve'u kaybetmek pahasına da olsa gerçek bir hatayı düzelt

---

## Kurtarma

```bash
git reflog                            # son 90 günün tüm HEAD hareketleri
git reset --hard HEAD@{3}             # belirli bir ana dön
git restore --staged <dosya>          # stage'den çıkar
git restore <dosya>                   # çalışma alanındaki değişikliği at (GERİ ALINAMAZ)
git revert <sha>                      # push edilmiş commit'i geri al (tarih bozmaz)
git stash push -m "yarım iş"          # geçici sakla
```

Push edilmiş bir şeyi geri alırken `reset` değil **`revert`** kullan.

---

## Checklist

- [ ] Branch doğru tabandan açıldı, ana dalda geliştirme yapılmadı
- [ ] Branch adı kalıba uygun
- [ ] Commit'ler atomik ve tek başına derleniyor
- [ ] Commit mesajı `type(scope): özet` formatında, gövde "neden"i anlatıyor
- [ ] `git status` temiz, plan dışı/gizli dosya commit'lenmedi
- [ ] Commit için onay alındı
- [ ] Push için ayrıca onay alındı
- [ ] Ortak dala force push yapılmadı
- [ ] Conflict çözümünden sonra derleme ve testler doğrulandı
- [ ] PR açıklaması ne/neden/nasıl/test/risk içeriyor
