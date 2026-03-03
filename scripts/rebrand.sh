#!/bin/bash
set -euo pipefail

# rebrand.sh — Replace all upstream branding with LeoBot
# Run this after every upstream sync to re-apply branding changes.

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

echo "🔄 Rebranding: nanoclaw/openclaw → leobot..."

# --- Step 1: Replace content in files ---
EXTENSIONS=(-name '*.ts' -o -name '*.json' -o -name '*.md' -o -name '*.yml' \
  -o -name '*.yaml' -o -name '*.sh' -o -name '*.toml' -o -name 'Dockerfile*')

find . -type f \( "${EXTENSIONS[@]}" \) \
  -not -path './.git/*' \
  -not -path '*/node_modules/*' \
  -not -name 'rebrand.sh' \
  -not -name 'sync-upstream.sh' \
  -exec sed -i '' \
    -e 's/NanoClaw/LeoBot/g' \
    -e 's/NANOCLAW/LEOBOT/g' \
    -e 's/nanoclaw/leobot/g' \
    -e 's/Nanoclaw/Leobot/g' \
    -e 's|qwibitai/leobot|leonardoFu/leobot|g' \
    -e 's|qwibitai/LeoBot|leonardoFu/leobot|g' \
    -e 's|qwibitai|leonardoFu|g' \
    {} +

# Also fix package-lock.json
for f in package-lock.json container/agent-runner/package-lock.json; do
  [ -f "$f" ] && sed -i '' 's/nanoclaw/leobot/g' "$f"
done

echo "  ✅ Content replaced"

# --- Step 2: Rename files/directories containing old names ---
# Process deepest paths first to avoid parent rename issues

rename_items() {
  find . -not -path './.git/*' -not -path '*/node_modules/*' \
    \( -name '*nanoclaw*' -o -name '*NanoClaw*' -o -name '*NANOCLAW*' \) | \
    sort -r | while read -r old; do
      dir=$(dirname "$old")
      base=$(basename "$old")
      new_base=$(echo "$base" | sed -e 's/NanoClaw/LeoBot/g' -e 's/NANOCLAW/LEOBOT/g' -e 's/nanoclaw/leobot/g' -e 's/Nanoclaw/Leobot/g')
      if [ "$base" != "$new_base" ]; then
        mv "$old" "$dir/$new_base"
        echo "  📁 $old → $dir/$new_base"
      fi
    done
}

rename_items

# --- Step 3: Remove OpenClaw-specific references in prose (README etc) ---
# Replace "Why I Built" section references to OpenClaw with neutral text
if grep -q 'OpenClaw' README.md 2>/dev/null; then
  sed -i '' \
    -e 's|\[OpenClaw\](https://github.com/openclaw/openclaw) is an impressive project.*shared memory\.|A personal AI assistant that'\''s small enough to fully understand. One process, a handful of files. Claude agents run in their own Linux containers with true filesystem isolation.|' \
    README.md
  echo "  ✅ README.md OpenClaw references cleaned"
fi

if grep -q 'OpenClaw' README_zh.md 2>/dev/null; then
  sed -i '' \
    -e 's|\[OpenClaw\](https://github.com/openclaw/openclaw).*运行。|一个足够小、可以完全理解的个人 AI 助手。一个进程，几个文件。Claude 代理运行在独立的 Linux 容器中，拥有真正的文件系统隔离。|' \
    README_zh.md
  echo "  ✅ README_zh.md OpenClaw references cleaned"
fi

# Clean remaining openclaw/clawdbot in docs
find . -type f \( "${EXTENSIONS[@]}" \) \
  -not -path './.git/*' \
  -not -path '*/node_modules/*' \
  -not -name 'rebrand.sh' \
  -not -name 'sync-upstream.sh' \
  -exec sed -i '' \
    -e 's/OpenClaw/LeoBot/g' \
    -e 's/openclaw/leobot/g' \
    -e 's/Clawdbot/LeoBot/g' \
    -e 's/clawdbot/leobot/g' \
    -e 's/ClawBot/LeoBot/g' \
    {} +

echo "  ✅ All remaining references cleaned"

# --- Verify ---
REMAINING=$(grep -ric 'nanoclaw\|openclaw\|qwibitai\|clawdbot' \
  --include='*.ts' --include='*.json' --include='*.md' --include='*.yml' \
  --include='*.yaml' --include='*.sh' --include='*.toml' \
  . 2>/dev/null | grep -v '.git/' | grep -v node_modules | grep -v ':0$' | grep -v 'rebrand.sh' | grep -v 'sync-upstream.sh' || true)

if [ -z "$REMAINING" ]; then
  echo "🎉 Rebrand complete — zero remaining references"
else
  echo "⚠️  Some references may remain:"
  echo "$REMAINING"
fi
