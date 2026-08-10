#!/usr/bin/env bash
# Skill klasörlerinin yapısını ve frontmatter'ını doğrular.
# Hata varsa 1 ile çıkar (CI'da kullanılır).

set -uo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SRC_DIR="$REPO_ROOT/skills"
MAX_LINES=500

errors=0
warnings=0
checked=0

fail() { echo "  HATA   $1"; errors=$((errors + 1)); }
warn() { echo "  UYARI  $1"; warnings=$((warnings + 1)); }

[[ -d "$SRC_DIR" ]] || { echo "hata: $SRC_DIR bulunamadı" >&2; exit 1; }

for skill_path in "$SRC_DIR"/*/; do
  name="$(basename "$skill_path")"
  file="$skill_path/SKILL.md"
  echo "$name"
  checked=$((checked + 1))

  if [[ ! -f "$file" ]]; then
    fail "SKILL.md yok"
    continue
  fi

  # Klasör adı formatı
  if [[ ! "$name" =~ ^[a-z0-9]+(-[a-z0-9]+)*$ ]]; then
    fail "klasör adı kebab-case değil: $name"
  fi

  # Frontmatter ilk satırda --- ile başlamalı
  if [[ "$(head -n 1 "$file")" != "---" ]]; then
    fail "frontmatter '---' ile başlamıyor"
    continue
  fi

  fm_end="$(awk 'NR>1 && /^---[[:space:]]*$/ { print NR; exit }' "$file")"
  if [[ -z "$fm_end" ]]; then
    fail "frontmatter kapanmamış (ikinci '---' yok)"
    continue
  fi

  frontmatter="$(sed -n "2,$((fm_end - 1))p" "$file")"

  fm_name="$(printf '%s\n' "$frontmatter" | awk -F': *' '/^name:/ { print $2; exit }')"
  if [[ -z "$fm_name" ]]; then
    fail "frontmatter'da 'name' yok"
  elif [[ "$fm_name" != "$name" ]]; then
    fail "name ('$fm_name') klasör adıyla ('$name') eşleşmiyor"
  fi

  # Tazelik damgası: eksikse veya 6 aydan eskiyse uyarı (bakım ajanı günceller)
  fm_reviewed="$(printf '%s\n' "$frontmatter" | awk -F': *' '/^last_reviewed:/ { print $2; exit }')"
  if [[ -z "$fm_reviewed" ]]; then
    warn "last_reviewed damgası yok"
  elif [[ "$fm_reviewed" =~ ^([0-9]{4})-([0-9]{2})$ ]]; then
    stamp_months=$(( ${BASH_REMATCH[1]} * 12 + 10#${BASH_REMATCH[2]} ))
    now_months=$(( $(date +%Y) * 12 + 10#$(date +%m) ))
    age=$(( now_months - stamp_months ))
    [[ "$age" -gt 6 ]] && warn "last_reviewed $fm_reviewed — $age aydır elden geçmemiş"
  else
    warn "last_reviewed formatı YYYY-MM olmalı: '$fm_reviewed'"
  fi

  if ! printf '%s\n' "$frontmatter" | grep -q '^description:'; then
    fail "frontmatter'da 'description' yok"
  else
    desc_len="$(printf '%s\n' "$frontmatter" | sed -n '/^description:/,$p' | wc -c | tr -d ' ')"
    [[ "$desc_len" -lt 80 ]] && warn "description çok kısa ($desc_len karakter) — tetikleme zayıf olabilir"
  fi

  # Referans yolları gerçekten var mı
  while IFS= read -r ref; do
    [[ -z "$ref" ]] && continue
    if [[ ! -f "$skill_path/$ref" ]]; then
      fail "eksik referans dosyası: $ref"
    fi
  done < <(grep -o 'references/[A-Za-z0-9._-]*\.md' "$file" | sort -u)

  # Uzunluk
  lines="$(wc -l < "$file" | tr -d ' ')"
  if [[ "$lines" -gt "$MAX_LINES" ]]; then
    warn "$lines satır (> $MAX_LINES) — içeriği references/ altına bölmeyi düşün"
  fi

  # Checklist var mı
  grep -q '^\- \[ \]' "$file" || warn "checklist bölümü yok"
done

echo
echo "Katalog senkronizasyonu"

# Skill listesinin indekslerde eksiksiz olduğunu doğrula.
# Bir skill eklenip kataloglara yazılmazsa kimse onu bulamaz.
declare -a CATALOGS=(
  "$REPO_ROOT/README.md"
  "$REPO_ROOT/skills/README.md"
  "$REPO_ROOT/templates/CLAUDE.md"
)

for catalog in "${CATALOGS[@]}"; do
  rel="${catalog#"$REPO_ROOT"/}"
  if [[ ! -f "$catalog" ]]; then
    fail "katalog dosyası yok: $rel"
    continue
  fi
  missing=""
  for skill_path in "$SRC_DIR"/*/; do
    sname="$(basename "$skill_path")"
    grep -q "\`$sname\`\|($sname)" "$catalog" || missing+=" $sname"
  done
  if [[ -n "$missing" ]]; then
    fail "$rel içinde listelenmeyen skill'ler:$missing"
  else
    echo "  tamam  $rel"
  fi
done

# Ters yön: katalogda anılan ama var olmayan skill (yeniden adlandırma artığı)
while IFS= read -r referenced; do
  [[ -d "$SRC_DIR/$referenced" ]] || fail "skills/README.md var olmayan skill'e referans veriyor: $referenced"
done < <(grep -o '^| \[`[a-z0-9-]*`\](' "$REPO_ROOT/skills/README.md" 2>/dev/null \
         | sed 's/^| \[`//; s/`\](.*//' | sort -u)

echo
echo "Kontrol edilen: $checked skill   Hata: $errors   Uyarı: $warnings"
[[ "$errors" -eq 0 ]] || exit 1
