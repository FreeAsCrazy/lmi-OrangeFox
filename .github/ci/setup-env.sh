#!/usr/bin/env bash
# 准备 GitHub Actions 构建环境：清理预装工具、创建 swap、安装依赖、安装 repo。
set -euo pipefail

SWAP_GB=${SWAP_GB:-24}

echo "=== 清理预装工具链 ==="
sudo rm -rf /usr/share/dotnet /usr/local/lib/android /opt/ghc \
            /usr/local/share/boost /opt/hostedtoolcache/CodeQL \
            /usr/share/swift /usr/local/.ghcup 2>/dev/null || true
sudo docker image prune -af >/dev/null 2>&1 || true
sudo apt-get clean >/dev/null 2>&1 || true

if [ "$SWAP_GB" -gt 0 ]; then
  echo "=== 启用 ${SWAP_GB}G swap ==="
  sudo swapoff -a 2>/dev/null || true
  sudo rm -f /swapfile
  sudo fallocate -l "${SWAP_GB}G" /swapfile ||
    sudo dd if=/dev/zero of=/swapfile bs=1M count=$((SWAP_GB * 1024)) status=none
  sudo chmod 600 /swapfile
  sudo mkswap /swapfile >/dev/null
  sudo swapon /swapfile
else
  echo "=== SWAP_GB=0，跳过 swap ==="
  sudo swapoff -a 2>/dev/null || true
  sudo rm -f /swapfile
fi
free -h
df -h /

PKGS=(
  bc bison build-essential ccache curl flex g++-multilib gcc-multilib git gnupg
  gperf imagemagick libc6-dev-i386 libelf-dev libgl1-mesa-dev liblz4-tool zstd
  libncurses-dev libssl-dev libx11-dev lzop openjdk-17-jdk pngcrush python3
  python3-pip rsync schedtool xsltproc unzip zip zlib1g-dev
)
apt_install() {
  sudo DEBIAN_FRONTEND=noninteractive apt-get install -y -qq --no-install-recommends "$@"
}
apt_install "${PKGS[@]}" || {
  sudo apt-get update -qq
  apt_install "${PKGS[@]}"
}

# noble 移除了 libncurses5/libtinfo5，而 AOSP 预编译 clang 需要 libtinfo.so.5。
N=6.2-0ubuntu2.1
for P in libtinfo5 libncurses5; do
  curl -fsSL --retry 3 --retry-delay 2 -O "https://archive.ubuntu.com/ubuntu/pool/universe/n/ncurses/${P}_${N}_amd64.deb" || continue
  sudo dpkg -i "${P}_${N}_amd64.deb" || true
  rm -f "${P}_${N}_amd64.deb"
done
df -h /

mkdir -p "$HOME/bin"
curl -fsSL --retry 3 --retry-delay 2 https://storage.googleapis.com/git-repo-downloads/repo -o "$HOME/bin/repo"
chmod +x "$HOME/bin/repo"
echo "$HOME/bin" >> "$GITHUB_PATH"
git config --global user.name "GitHub Actions"
git config --global user.email "actions@github.com"
git config --global --replace-all safe.directory '*'
"$HOME/bin/repo" --version || true

if [ -n "${JAVA_HOME_17_X64:-}" ] && [ -d "$JAVA_HOME_17_X64" ]; then
  echo "JAVA_HOME=$JAVA_HOME_17_X64" >> "$GITHUB_ENV"
  echo "$JAVA_HOME_17_X64/bin" >> "$GITHUB_PATH"
fi
java -version 2>&1 || true
