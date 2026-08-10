#!/usr/bin/env bash
# Markdown dosyalarındaki göreli linklerin hedefinin var olduğunu doğrular.
# Harici (http/https), mailto ve yalnızca çapa (#bolum) linkleri atlanır.

set -uo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$REPO_ROOT"

broken=0
checked=0

while IFS= read -r file; do
  # Satır satır tara ki hangi dosyada olduğunu bilelim
  while IFS= read -r target; do
    [[ -z "$target" ]] && continue

    # Harici şema, çapa ve şablon yer tutucularını atla
    case "$target" in
      http://*|https://*|mailto:*|\#*|\<*) continue ;;
    esac

    # Çapa kısmını at: docs/X.md#bolum → docs/X.md
    path="${target%%#*}"
    [[ -z "$path" ]] && continue

    checked=$((checked + 1))
    if [[ ! -e "$(dirname "$file")/$path" ]]; then
      echo "  KIRIK  $file → $target"
      broken=$((broken + 1))
    fi
    # Kod bloğu içindeki örnek linkler atlanır (```...``` arası) — oradakiler
    # gerçek hedef değil, şablon örneği.
  done < <(awk '
      /^[[:space:]]*```/ { fence = !fence; next }
      !fence            { print }
    ' "$file" | grep -oE '\]\([^)]+\)' | sed 's/^](//; s/)$//')
done < <(find . -name '*.md' -not -path './.git/*')

echo
echo "Kontrol edilen link: $checked   Kırık: $broken"
[[ "$broken" -eq 0 ]] || exit 1
