#!/bin/bash

# Bitz Miner CLI 自动化安装脚本（支持 base58 私钥，适用于中文用户）
# 适用环境：Ubuntu 22.04
# 功能：自动安装依赖、Solana CLI、Bitz，并配置运行 miner

# 设置颜色代码
GREEN='\033[0;32m'
RED='\033[0;31m'
NC='\033[0m'

echo -e "${GREEN}=== Bitz Miner CLI 自动化安装脚本 ===${NC}"
echo "本脚本将帮助您在 Eclipse 网络上安装和运行 Bitz Miner CLI。"
echo "请确保您已准备好 Eclipse 钱包（如 Backpack）并存有少量 ETH。"
echo -e "${RED}注意：运行脚本需要 root 权限。${NC}"
echo "按 Enter 继续，或按 Ctrl+C 退出..."
read

# 检查 root 权限
if [[ $EUID -ne 0 ]]; then
   echo -e "${RED}请使用 sudo 运行：sudo bash bitz_setup.sh${NC}"
   exit 1
fi

# 检查系统环境
echo -e "${GREEN}检查系统环境...${NC}"
GLIBC_VERSION=$(ldd --version | head -n1 | awk '{print $NF}')
echo "GLIBC 版本：$GLIBC_VERSION"

# 更新系统并安装依赖
echo -e "${GREEN}步骤 1：更新系统并安装依赖...${NC}"
apt-get update && apt-get upgrade -y
apt-get install -y screen curl nano build-essential python3 python3-pip
pip3 install base58
if [ $? -ne 0 ]; then
    echo -e "${RED}依赖安装失败，请检查网络或磁盘空间！${NC}"
    exit 1
fi

# 安装 Rust
echo -e "${GREEN}步骤 2：安装 Rust...${NC}"
curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y
source $HOME/.cargo/env
rustc --version
if [ $? -ne 0 ]; then
    echo -e "${RED}Rust 安装失败，请检查网络！${NC}"
    exit 1
fi

# 安装 Solana CLI
echo -e "${GREEN}步骤 3：安装 Solana CLI...${NC}"
sh -c "$(curl -sSfL https://release.anza.xyz/v1.18.25/install)"
export PATH="/root/.local/share/solana/install/active_release/bin:$PATH"
echo 'export PATH="/root/.local/share/solana/install/active_release/bin:$PATH"' >> ~/.bashrc
source ~/.bashrc
solana --version
if [ $? -ne 0 ]; then
    echo -e "${RED}Solana CLI 安装失败，请检查网络或磁盘空间！${NC}"
    exit 1
fi

# 配置 Solana RPC
echo -e "${GREEN}步骤 4：配置 Solana RPC...${NC}"
solana config set --url https://mainnetbeta-rpc.eclipse.xyz/
echo "Solana RPC 设置为 https://mainnetbeta-rpc.eclipse.xyz/"

# 配置钱包
echo -e "${GREEN}步骤 5：配置 Solana CLI 钱包...${NC}"
echo "您想使用现有钱包还是创建新钱包？"
echo "1. 使用现有钱包（base58 或 JSON 私钥）"
echo "2. 创建新钱包"
echo "请输入选项（1 或 2）："
read WALLET_OPTION

if [ "$WALLET_OPTION" = "1" ]; then
    echo "请输入您的 Eclipse 钱包私钥（base58 如 3QfGm... 或 JSON 如 [123,45,...]）："
    read -r PRIVATE_KEY
    if [[ "$PRIVATE_KEY" =~ ^\[.*\]$ ]]; then
        echo "检测到 JSON 数组，导入私钥..."
        echo "$PRIVATE_KEY" > ~/.config/solana/id.json
    else
        echo "检测到 base58 格式，转换为 JSON 数组..."
        python3 -c "import base58; import json; key = base58.b58decode('$PRIVATE_KEY'); json_array = list(key); print(json.dumps(json_array))" > ~/.config/solana/id.json
        if [ $? -ne 0 ]; then
            echo -e "${RED}私钥转换失败，请检查 base58 私钥！${NC}"
            exit 1
        fi
    fi
    echo "验证钱包地址..."
    PUBKEY=$(solana-keygen pubkey)
    echo "您的钱包地址：$PUBKEY"
    echo -e "${RED}请确认此地址与您的钱包一致！${NC}"
else
    echo "创建新钱包..."
    solana-keygen new
    echo -e "${RED}重要：请保存助记词和公钥！${NC}"
fi

# 显示钱包信息
echo -e "${GREEN}步骤 6：显示钱包信息...${NC}"
solana config get
echo "私钥存储在 ~/.config/solana/id.json："
cat ~/.config/solana/id.json
echo -e "${RED}请确认私钥正确，并确保钱包有 0.01-0.05 ETH。${NC}"
echo "按 Enter 继续..."
read

# 安装 Bitz
echo -e "${GREEN}步骤 7：安装 Bitz...${NC}"
cargo install bitz
if [ $? -ne 0 ]; then
    echo -e "${RED}Bitz 安装失败，请检查 Rust 或网络！${NC}"
    exit 1
fi

# 运行 Bitz Miner
echo -e "${GREEN}步骤 8：运行 Bitz Miner...${NC}"
echo "请输入 CPU 核心数（默认 1，例如 4 或 8）："
read CPU_CORES
if [[ ! $CPU_CORES =~ ^[0-9]+$ ]]; then
    CPU_CORES=1
fi
screen -dmS bitz bash -c "bitz collect --cores $CPU_CORES"
echo -e "${GREEN}Bitz Miner 已启动！使用 $CPU_CORES 核心。${NC}"
echo "管理命令："
echo "- 查看：screen -r bitz"
echo "- 停止：Ctrl+C（在 screen 中）"
echo "- 退出 screen：Ctrl+A+D"
echo "- 终止：screen -XS bitz quit"
echo "- 检查账户：bitz account"
echo "- 领取奖励：bitz claim"

echo -e "${GREEN}=== 安装完成！ ===${NC}"
echo "Bitz Miner 已在后台运行。如需帮助，联系 Contabo 支持或 Eclipse 社区。"
