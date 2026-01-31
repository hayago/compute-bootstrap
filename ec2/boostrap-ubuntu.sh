#!/bin/bash
set -eux

# パッケージリストを更新
apt update

# zshをインストール
apt install -y zsh

# tigをインストール
apt install -y tig

# ghをインストール
apt install -y gh

# nvimをインストール
apt install -y neovim

# ubuntuユーザーのセットアップ
TARGET_USER=ubuntu
sudo -u $TARGET_USER bash -lc '
set -eux
# Claude Codeをインストール
curl -fsSL https://claude.ai/install.sh | bash

# uvをインストール
curl -LsSf https://astral.sh/uv/install.sh | sh

# dotfilesをセットアップ
git clone https://github.com/hayago/dotfiles ~/dotfiles
cd ~/dotfiles
chmod +x setup.sh
./setup.sh

# シェルをzshに変更
sudo chsh -s $(which zsh) $(whoami)
'

