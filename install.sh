#!/usr/bin/env bash
# Installs Switchboard: the `ccp` command, the provider templates, and (on macOS) the app.
#
#   ./install.sh              everything
#   ./install.sh --no-app     only the ccp command and templates
#
# Your providers live in ~/.claude-providers and are never overwritten.
set -eu

HERE="$(cd "$(dirname "$0")" && pwd)"
BIN_DIR="${BIN_DIR:-$HOME/bin}"
DIR="${CLAUDE_PROVIDERS_DIR:-$HOME/.claude-providers}"
APP_DIR="${APP_DIR:-$HOME/Applications}"
WITH_APP=1
[ "${1:-}" = "--no-app" ] && WITH_APP=0
[ "$(uname -s)" = "Darwin" ] || WITH_APP=0

mkdir -p "$BIN_DIR" "$DIR/templates"
chmod 700 "$DIR"

install -m 755 "$HERE/bin/ccp" "$BIN_DIR/ccp"
echo "installed  $BIN_DIR/ccp"

for t in "$HERE"/templates/*.tpl; do
  install -m 644 "$t" "$DIR/templates/$(basename "$t")"
done
echo "installed  provider templates in $DIR/templates"

case ":$PATH:" in
  *":$BIN_DIR:"*) ;;
  *) echo "note       $BIN_DIR isn't on your PATH. Add this to your shell profile:"
     echo "             export PATH=\"$BIN_DIR:\$PATH\"" ;;
esac

if [ "$WITH_APP" = 1 ]; then
  APP="$APP_DIR/Switchboard.app"
  mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources/src"
  install -m 644 "$HERE/app/Info.plist" "$APP/Contents/Info.plist"
  install -m 755 "$HERE/app/Switchboard" "$APP/Contents/MacOS/Switchboard"
  "$HERE/app/make-icon.sh" "$APP/Contents/Resources/AppIcon.icns" >/dev/null 2>&1 \
    || echo "note       couldn't draw the app icon; the app will use the default one"
  rm -f "$APP/Contents/Resources/src/"*.swift   # drop sources that no longer exist, or the app will not build
  install -m 644 "$HERE"/app/Sources/*.swift "$APP/Contents/Resources/src/"
  mkdir -p "$APP/Contents/Resources/bin" "$APP/Contents/Resources/templates"
  install -m 755 "$HERE/bin/ccp" "$APP/Contents/Resources/bin/ccp"
  install -m 644 "$HERE"/templates/*.tpl "$APP/Contents/Resources/templates/"
  echo "installed  $APP"
  echo "           It compiles itself the first time you open it (about a minute; needs Xcode or the"
  echo "           Command Line Tools: xcode-select --install)."
fi

echo
echo "Next:  ccp add        (or open Switchboard and click Add provider)"
