#!/usr/bin/env bash
# Documentation checks. Usage: bash tests/docs.sh
# 1. Every local markdown link (and #anchor) in README, exercises and docs resolves.
# 2. Participant paths mention no Node/npm.
# 3. Every bash block in exercises/00-07 runs (with the reference solutions installed as active hooks).
root=$(cd "$(dirname "$0")/.." && pwd)
cd "$root" || exit 1
failed=0; links=0
fail() { echo "FAIL: $*"; failed=$((failed + 1)); }

slug() { tr 'A-Z' 'a-z' | sed -E 's/[^a-z0-9 _-]//g; s/ /-/g'; }
for md in README.md exercises/*.md exercises/extras/*.md docs/*.md; do
  for link in $(grep -oE '\]\([^)#][^)]*\)|\]\(#[^)]*\)' "$md" | sed -E 's/^\]\(//; s/\)$//'); do
    case "$link" in http*|mailto:*) continue ;; esac
    file=${link%%#*}; frag=""; [ "$file" != "$link" ] && frag=${link#*#}
    target="$md"; [ -n "$file" ] && target="$(dirname "$md")/$file"
    links=$((links + 1))
    [ -e "$target" ] || { fail "$md: broken link $link"; continue; }
    if [ -n "$frag" ]; then
      grep -E '^#{1,6} ' "$target" | sed -E 's/^#+ +//' | while IFS= read -r h; do echo "$h" | slug; done | grep -qx "$frag" || fail "$md: missing anchor $link"
    fi
  done
done

if grep -rniwE 'node|nodejs|node\.js|npm|npx' README.md exercises scripts docs demo-app fixtures solutions .devcontainer; then
  fail "Node/npm mentioned in participant paths"
fi

work=$(mktemp -d); trap 'rm -rf "$work"' EXIT
cp -R scripts solutions fixtures demo-app "$work/"
mkdir -p "$work/.github/hooks" && cp solutions/*/*.json "$work/.github/hooks/"
(cd "$work" && git init -q && git add -A && git -c user.name=t -c user.email=t@t commit -q -m init)
blocks=0
for md in exercises/0*.md; do
  awk -v out="$work/block" -v name="$(basename "$md" .md)" '
    /^```bash$/ { n++; file = out "-" name "-" n ".sh"; inblock = 1; next }
    /^```$/ { inblock = 0 }
    inblock { print > file }' "$md"
done
for b in "$work"/block-*.sh; do
  blocks=$((blocks + 1))
  (cd "$work" && bash "$b" > /dev/null 2> "$work/err") || fail "$(basename "$b") failed: $(head -3 "$work/err")"
done
echo "docs: $links links, $blocks bash blocks checked, $failed problem(s)"
[ "$failed" = 0 ]
