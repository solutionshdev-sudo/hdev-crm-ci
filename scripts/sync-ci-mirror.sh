#!/usr/bin/env bash
# Sincroniza o CÓDIGO (e só o código) pro espelho público de CI e dispara a suíte lá.
#
# Por quê: o repo principal é o workspace inteiro (contém _memoria/ e afins) e é
# privado — Actions em privado é pago. O espelho hdev-crm-ci é público (Actions
# grátis/ilimitado) e recebe SOMENTE hdevCRM/, baileys-service/ e .github/, num
# commit ÚNICO por sync (sem histórico — nada do passado do workspace vaza).
#
# Uso:  scripts/sync-ci-mirror.sh [ref]        # default: branch atual do worktree corrente
#       depois: gh workflow run ci.yml --repo solutionshdev-sudo/hdev-crm-ci --ref <branch>
#       (o próprio script já dispara e imprime o run)
#
# Segurança: allowlist explícita de diretórios. NUNCA adicionar _memoria/,
# identidade/, dados/, saidas/, marketing/, templates/, _sistema/, .claude/.

set -euo pipefail

MIRROR_REPO="solutionshdev-sudo/hdev-crm-ci"
MIRROR_URL="https://github.com/${MIRROR_REPO}.git"
ALLOWLIST=("hdevCRM" "baileys-service" ".github" ".gitignore" "VERSION")

SRC_ROOT="$(git rev-parse --show-toplevel)"
REF="${1:-$(git -C "$SRC_ROOT" rev-parse --abbrev-ref HEAD)}"
SRC_SHA="$(git -C "$SRC_ROOT" rev-parse --short HEAD)"

# Recusa sync com tree sujo: o espelho deve refletir um commit real.
if [[ -n "$(git -C "$SRC_ROOT" status --porcelain)" ]]; then
  echo "ERRO: working tree sujo em $SRC_ROOT — commita antes de sincronizar." >&2
  exit 1
fi

TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

git init -q -b "$REF" "$TMP/mirror"
for item in "${ALLOWLIST[@]}"; do
  if [[ -e "$SRC_ROOT/$item" ]]; then
    cp -r "$SRC_ROOT/$item" "$TMP/mirror/$item"
  fi
done

cat > "$TMP/mirror/README.md" <<EOF
# HDEV CRM — espelho de CI

Espelho público SÓ do código, usado pra rodar o CI de graça.
Fonte de verdade, PRs e issues: repo principal (privado).
Sincronizado de \`$REF\` @ \`$SRC_SHA\` em $(date -u +%Y-%m-%dT%H:%M:%SZ).
EOF

cd "$TMP/mirror"
git add -A

# Restaura os bits de execução: no Windows o checkout/cópia perde o modo 100755
# e o `Lint/ScriptPermission` do rubocop acusa falso positivo no CI do espelho
# (aconteceu de verdade em 05/08 com docker/entrypoints/helpers/pg_database_url.rb).
git -C "$SRC_ROOT" ls-files -s | awk '$1 == "100755" { print $4 }' | while read -r exe; do
  [[ -e "$exe" ]] && git update-index --chmod=+x "$exe"
done
git -c user.name="ci-mirror" -c user.email="ci-mirror@hdev.local" \
  commit -q -m "sync: $REF @ $SRC_SHA"
git push -q --force "$MIRROR_URL" "HEAD:refs/heads/$REF"

echo "Espelho sincronizado: $MIRROR_REPO branch $REF @ $SRC_SHA"
echo "Disparando CI (workflow_dispatch)..."
gh workflow run ci.yml --repo "$MIRROR_REPO" --ref "$REF"
sleep 8
gh run list --repo "$MIRROR_REPO" --branch "$REF" --limit 1
