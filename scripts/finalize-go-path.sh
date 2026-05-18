#!/usr/bin/env bash
# Finalize Go PATH setup (sudo required). Writes /etc/profile.d/go.sh
# so $HOME/go/bin is on PATH for all login shells.
set -eu

cat > /etc/profile.d/go.sh <<'EOF'
export GOPATH="${HOME}/go"
export PATH="${PATH}:${GOPATH}/bin"
EOF
chmod 644 /etc/profile.d/go.sh
echo "/etc/profile.d/go.sh written"
echo "For the current shell: source /etc/profile.d/go.sh"
