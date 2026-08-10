#!/usr/bin/env bash
# Skill'leri ~/.claude/skills (varsayılan) veya bir projenin .claude/skills
# klasörüne symlink olarak kurar.
#
# Kullanım:
#   ./scripts/install.sh                        → ~/.claude/skills
#   ./scripts/install.sh --project /yol/proje   → /yol/proje/.claude/skills
#   ./scripts/install.sh --copy                 → symlink yerine kopyala
#   ./scripts/install.sh --only android-architect,kmp-shared

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SRC_DIR="$REPO_ROOT/skills"

TARGET_DIR="$HOME/.claude/skills"
MODE="link"
ONLY=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --project)
      [[ $# -ge 2 ]] || { echo "hata: --project bir yol bekler" >&2; exit 1; }
      TARGET_DIR="$2/.claude/skills"
      shift 2
      ;;
    --target)
      [[ $# -ge 2 ]] || { echo "hata: --target bir yol bekler" >&2; exit 1; }
      TARGET_DIR="$2"
      shift 2
      ;;
    --copy) MODE="copy"; shift ;;
    --only)
      [[ $# -ge 2 ]] || { echo "hata: --only virgülle ayrılmış skill adları bekler" >&2; exit 1; }
      ONLY="$2"
      shift 2
      ;;
    -h|--help) sed -n '2,10p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
    *) echo "bilinmeyen argüman: $1" >&2; exit 1 ;;
  esac
done

[[ -d "$SRC_DIR" ]] || { echo "hata: $SRC_DIR bulunamadı" >&2; exit 1; }

mkdir -p "$TARGET_DIR"

wanted() {
  [[ -z "$ONLY" ]] && return 0
  local name="$1"
  IFS=',' read -ra list <<< "$ONLY"
  for item in "${list[@]}"; do
    [[ "${item// /}" == "$name" ]] && return 0
  done
  return 1
}

installed=0
skipped=0

for skill_path in "$SRC_DIR"/*/; do
  name="$(basename "$skill_path")"
  wanted "$name" || continue

  if [[ ! -f "$skill_path/SKILL.md" ]]; then
    echo "  atlandı  $name (SKILL.md yok)"
    skipped=$((skipped + 1))
    continue
  fi

  dest="$TARGET_DIR/$name"

  if [[ -e "$dest" || -L "$dest" ]]; then
    if [[ -L "$dest" && "$(readlink "$dest")" == "${skill_path%/}" ]]; then
      echo "  güncel   $name"
      installed=$((installed + 1))
      continue
    fi
    backup="$dest.backup.$(date +%Y%m%d%H%M%S)"
    mv "$dest" "$backup"
    echo "  yedek    $name → $(basename "$backup")"
  fi

  if [[ "$MODE" == "copy" ]]; then
    cp -R "${skill_path%/}" "$dest"
    echo "  kopya    $name"
  else
    ln -s "${skill_path%/}" "$dest"
    echo "  link     $name"
  fi
  installed=$((installed + 1))
done

echo
echo "Hedef : $TARGET_DIR"
echo "Kurulan: $installed  Atlanan: $skipped"
echo
echo "Claude Code'u yeniden başlat veya yeni bir oturum aç; skill'ler otomatik yüklenir."
