#!/usr/bin/env bash
# Deterministic minion stub: reads the prompt and performs id-specific actions
read -r prompt

case "$prompt" in
  *bootstrap*)
    mkdir -p app tests public &&
    printf "Markdown Previewer\n" > README.md
    ;;

  *parser*)
    cat > app/preview.sh <<'SH'
#!/usr/bin/env bash
set -euo pipefail
in=${1:-README.md}
out=${2:-public/index.html}
mkdir -p "$(dirname "$out")"
if command -v pandoc >/dev/null; then
  pandoc "$in" -o "$out"
else
  printf "<html><body>\n" >"$out"
  sed 's/^# \(.*\)/<h1>\1<\/h1>/' "$in" >>"$out"
  printf "</body></html>\n" >>"$out"
fi
SH
    chmod +x app/preview.sh

    cat > tests/preview.bats <<'BATS'
#!/usr/bin/env bats

@test "renders README to HTML" {
  run app/preview.sh README.md public/index.html
  [ "$status" -eq 0 ]
  grep -q "<html>" public/index.html
}
BATS
    chmod +x tests/preview.bats
    ;;

  *watch*)
    printf "\n## Watch mode\nRun ./app/preview.sh README.md public/index.html --watch\n" >> README.md
    ;;

  *packaging*)
    cat > Makefile <<'MK'
build:
	./app/preview.sh README.md public/index.html

test:
	bats tests
MK
    ;;
esac

echo "ok: $prompt"
