#!/usr/bin/env bash
#
# Publishes build/web to the gh-pages branch of this repo's origin remote,
# which GitHub Pages serves at https://<user>.github.io/<repo>/.
#
# Usage:
#   ./deploy.sh                 # rebuild the web export, then publish
#   ./deploy.sh --skip-build    # publish whatever is already in build/web
#
# The export needs no COOP/COEP headers (Godot's web build only requires
# cross-origin isolation when thread support is on, which this preset
# leaves off), which is what makes plain GitHub Pages hosting viable at
# all - Pages cannot send custom headers.

set -euo pipefail

cd "$(dirname "$0")"
REPO_ROOT="$(pwd)"
WEB_DIR="$REPO_ROOT/build/web"

# Guard the rm -rf below: refuse to touch anything that isn't the export dir.
case "$WEB_DIR" in
	*/build/web) ;;
	*) echo "Refusing to operate on unexpected path: $WEB_DIR" >&2; exit 1 ;;
esac

if [ "${1:-}" != "--skip-build" ]; then
	./build.sh
fi

if [ ! -f "$WEB_DIR/index.html" ]; then
	echo "No export at $WEB_DIR/index.html - run ./build.sh first." >&2
	exit 1
fi

REMOTE="$(git remote get-url origin)"

# Serve the files verbatim instead of running them through Jekyll, which
# would drop anything beginning with an underscore.
touch "$WEB_DIR/.nojekyll"

# The export is ~38MB, nearly all of it index.wasm. Publishing from a
# throwaway single-commit repository and force-pushing keeps gh-pages at
# exactly one commit, so re-deploying never grows the repo. The source
# history on main stays free of build output entirely (build/ is ignored).
rm -rf "${WEB_DIR:?}/.git"
git -C "$WEB_DIR" init -q
git -C "$WEB_DIR" checkout -q -b gh-pages
git -C "$WEB_DIR" add -A
git -C "$WEB_DIR" commit -qm "Deploy $(date -u '+%Y-%m-%d %H:%M:%SZ')"
git -C "$WEB_DIR" push -q -f "$REMOTE" gh-pages
rm -rf "${WEB_DIR:?}/.git"

echo "Deployed gh-pages -> $REMOTE"
