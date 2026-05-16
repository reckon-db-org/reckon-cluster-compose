#!/usr/bin/env bash
# Install Docker on Arch Linux + put user `rl' in the docker group.
#
# After running, your zsh session does NOT yet have the docker group
# (Unix shells can't inherit group changes from child processes).
# Options:
#   * Open a new terminal (groups refresh on login)
#   * Run `newgrp docker' in your current shell
#   * Or just keep using `sudo docker ...' for one-offs
set -euo pipefail

echo "==> pacman -Sy + install docker + compose plugin + buildx"
sudo pacman -Sy --noconfirm --needed docker docker-compose docker-buildx

echo "==> Adding rl to docker group"
sudo usermod -aG docker rl

echo "==> Enabling docker on boot + starting now"
sudo systemctl enable --now docker.service

echo
echo "==> Verify under the docker group via sg (one-command shell)"
sg docker -c 'docker --version && docker compose version && docker run --rm hello-world | grep -E "Hello|working correctly"'

echo
echo "==> Done. To run docker without sudo in your CURRENT shell:"
echo "    newgrp docker"
echo
echo "    (or just open a new terminal — groups refresh on login.)"
