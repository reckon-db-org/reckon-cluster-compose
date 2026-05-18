#!/usr/bin/env bash
# Install Go on Arch Linux + the buf protobuf toolchain.
#
# Needed for:
#   - reckon-go SDK codegen (buf generate from reckon-proto)
#   - reckon-go SDK build + tests
#   - reckon-lazy (lazyreckon TUI) build
#
# Usage:
#   sudo bash install-go-arch.sh
#
# After install, $HOME/go/bin should be on PATH. The script writes a
# `/etc/profile.d/go.sh' that adds it for login shells; for the
# current shell, source it manually:
#   source /etc/profile.d/go.sh
set -eu

echo "==> pacman -Sy + install go + protobuf"
pacman -Sy --noconfirm --needed go protobuf

echo
echo "==> Set up GOPATH for user rl"
GOPATH_DIR="/home/rl/go"
mkdir -p "${GOPATH_DIR}/bin"
chown -R rl:rl "${GOPATH_DIR}"

echo
echo '==> /etc/profile.d/go.sh — adds $HOME/go/bin to PATH for login shells'
cat > /etc/profile.d/go.sh <<'EOF'
export GOPATH="${HOME}/go"
export PATH="${PATH}:${GOPATH}/bin"
EOF
chmod 644 /etc/profile.d/go.sh

echo
echo "==> Install buf (proto codegen)"
sudo -u rl bash -c '
  export GOPATH="${HOME}/go"
  export PATH="${PATH}:${GOPATH}/bin"
  /usr/bin/go install github.com/bufbuild/buf/cmd/buf@v1.45.0
  /usr/bin/go install google.golang.org/protobuf/cmd/protoc-gen-go@v1.34.2
  /usr/bin/go install google.golang.org/grpc/cmd/protoc-gen-go-grpc@v1.5.1
'

echo
echo "==> Verify"
sudo -u rl bash -c '
  source /etc/profile.d/go.sh
  go version
  buf --version
  protoc-gen-go --version 2>&1 || true
  protoc-gen-go-grpc --version 2>&1 || true
'

echo
echo "Done. In your current shell run:"
echo "  source /etc/profile.d/go.sh"
echo
echo "Or open a fresh terminal."
