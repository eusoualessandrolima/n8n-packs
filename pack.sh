#!/usr/bin/env bash
# Empacota e publica um pack no GitHub Releases.
#
# Uso: ./pack.sh <slug> <version>
# Exemplo: ./pack.sh corretora-seguros 1.0.2
#
# Requer: gh autenticado (gh auth login)

set -euo pipefail

SLUG="${1:?slug obrigatorio (ex: corretora-seguros)}"
VERSION="${2:?version obrigatoria (ex: 1.0.2)}"
REPO="eusoualessandrolima/n8n-packs"
TAG="${SLUG}-v${VERSION}"
TARBALL="/tmp/${SLUG}-${VERSION}.tar.gz"

PACK_DIR="$(cd "$(dirname "$0")" && pwd)/packs/${SLUG}"

[ -d "$PACK_DIR" ] || { echo "Pack nao encontrado: $PACK_DIR"; exit 1; }
[ -f "$PACK_DIR/pack.json" ] || { echo "pack.json nao encontrado em $PACK_DIR"; exit 1; }

echo "Empacotando $SLUG@$VERSION..."
python3 - <<PYEOF
import tarfile, json
from pathlib import Path

src = Path("$PACK_DIR")
out = "$TARBALL"
slug = "$SLUG"

with tarfile.open(out, "w:gz") as tf:
    tf.add(src / "pack.json", arcname=f"n8n-packs/packs/{slug}/pack.json")
    if (src / "README.md").exists():
        tf.add(src / "README.md", arcname=f"n8n-packs/packs/{slug}/README.md")
    for wf in sorted((src / "workflows").iterdir()):
        if wf.suffix == ".json" and not wf.name.startswith("._"):
            tf.add(wf, arcname=f"n8n-packs/packs/{slug}/workflows/{wf.name}")

# verify pack.json inside
import io
with tarfile.open(out, "r:gz") as tf:
    for m in tf.getmembers():
        if m.name.endswith("pack.json") and not "/._" in m.name:
            content = json.loads(tf.extractfile(m).read().decode("utf-8"))
            print(f"  pack.json: slug={content['slug']} v={content['version']}")
            break
print(f"  workflows: {sum(1 for m in tarfile.open(out,'r:gz').getmembers() if 'workflows/' in m.name and m.name.endswith('.json'))}")
PYEOF

echo "Publicando release $TAG..."
if gh release view "$TAG" --repo "$REPO" &>/dev/null; then
    gh release upload "$TAG" "$TARBALL" --repo "$REPO" --clobber
else
    gh release create "$TAG" "$TARBALL" \
        --repo "$REPO" \
        --title "${SLUG} v${VERSION}" \
        --notes "Pack ${SLUG} versão ${VERSION}"
fi

echo "OK: https://github.com/${REPO}/releases/tag/${TAG}"
rm -f "$TARBALL"
