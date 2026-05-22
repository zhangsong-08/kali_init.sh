#!/bin/bash

# ==========================================
# 作者: zs08
# 功能: Kali Linux 初始化配置工具 (CLI 版)
# 说明: 去除了 TUI 界面，改为命令行交互模式
# ==========================================

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# 获取当前脚本路径
SCRIPT_PATH="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/$(basename "${BASH_SOURCE[0]}")"

# 确保以 root 权限运行
if [ "$EUID" -ne 0 ]; then
    echo -e "${RED}[错误]${NC} 请使用 sudo 运行此脚本！"
    echo "例如: sudo bash $0"
    exit 1
fi

# 获取系统版本代号 (例如: kali-rolling)
CODENAME=$(lsb_release -sc 2>/dev/null)
if [ -z "$CODENAME" ]; then
    CODENAME="kali-rolling"
fi

# 定义软件源数据
declare -A MIRRORS
MIRRORS[1]="https://mirrors.tuna.tsinghua.edu.cn/kali"
MIRRORS_NAME[1]="清华大学"
MIRRORS[2]="https://mirrors.aliyun.com/kali"
MIRRORS_NAME[2]="阿里云"
MIRRORS[3]="https://mirrors.ustc.edu.cn/kali"
MIRRORS_NAME[3]="中科大"
MIRRORS[4]="https://mirrors.zju.edu.cn/kali"
MIRRORS_NAME[4]="浙江大学"

# ==================== 功能 1: 中文环境配置 ====================
set_chinese_env() {
    echo -e "${GREEN}[*]${NC} 开始配置中文环境..."
    
    echo -e "${YELLOW}[1/3]${NC} 正在更新软件包索引..."
    apt-get update > /dev/null 2>&1
    
    echo -e "${YELLOW}[2/3]${NC} 正在安装中文字体 (文泉驿)..."
    apt-get install -y fonts-wqy-microhei fonts-wqy-zenhei xfonts-wqy > /dev/null 2>&1
    
    if [ $? -eq 0 ]; then
        echo -e "${GREEN}[成功]${NC} 字体安装完成。"
    else
        echo -e "${RED}[失败]${NC} 字体安装出错，请检查网络连接。"
        read -p "按回车键返回主菜单..."
        return
    fi

    echo -e "${YELLOW}[3/3]${NC} 正在调用系统语言配置工具..."
    echo -e "${BLUE}------------------------------------------------${NC}"
    echo -e "${YELLOW}操作指南:${NC}"
    echo -e "1. 使用空格键选中 'zh_CN.GBK' 和 'zh_CN.UTF-8'"
    echo -e "2. 按 Tab 键切换到 '<Ok>' 并回车"
    echo -e "3. 在下一个界面选中 'zh_CN.UTF-8' 作为默认环境"
    echo -e "4. 按 Tab 键切换到 '<Ok>' 并回车"
    echo -e "${BLUE}------------------------------------------------${NC}"
    
    read -p "准备好后按回车键进入配置界面..."
    
    # 执行配置
    dpkg-reconfigure locales

    echo ""
    echo -e "${GREEN}[重要提示]${NC} 无论您在上述界面中选择确认还是取消，"
    echo -e "${GREEN}[重要提示]${NC} 为了确保中文环境完全生效，${RED}请务必立即重启系统${NC}。"
    
    read -p "是否现在立即重启? (y/n, 默认 n): " REBOOT_CHOICE
    if [[ "$REBOOT_CHOICE" =~ ^[Yy]$ ]]; then
        echo "系统即将重启..."
        reboot
    else
        echo "请稍后手动重启系统。"
        read -p "按回车键返回主菜单..."
    fi
}

# ==================== 功能 2: 更换软件源 ====================
change_sources() {
    while true; do
        echo ""
        echo -e "${GREEN}[*]${NC} 当前系统版本: ${CODENAME}"
        echo -e "${YELLOW}请选择国内软件源:${NC}"
        
        for key in "${!MIRRORS_NAME[@]}"; do
            echo "  $key) ${MIRRORS_NAME[$key]}"
        done
        echo -e "  ${BLUE}b) 返回上一级菜单${NC}"
        echo ""
        
        read -p "请输入选项编号 (默认 1 清华大学): " SOURCE_CHOICE
        
        # 处理返回上一级
        if [[ "$SOURCE_CHOICE" =~ ^[Bb]$ ]] || [[ "$SOURCE_CHOICE" == "0" ]]; then
            return
        fi

        # 默认选择清华大学
        if [ -z "$SOURCE_CHOICE" ]; then
            SOURCE_CHOICE=1
        fi

        # 验证输入
        if [ -z "${MIRRORS[$SOURCE_CHOICE]}" ]; then
            echo -e "${RED}[错误]${NC} 无效的选项，请重新输入。"
            sleep 1
            continue # 继续循环，重新显示菜单
        fi

        SELECTED_URL="${MIRRORS[$SOURCE_CHOICE]}"
        SELECTED_NAME="${MIRRORS_NAME[$SOURCE_CHOICE]}"

        echo -e "${YELLOW}[1/3]${NC} 备份原源文件..."
        BACKUP_FILE="/etc/apt/sources.list.bak_$(date +%Y%m%d%H%M%S)"
        cp /etc/apt/sources.list "$BACKUP_FILE"
        echo -e "${GREEN}[成功]${NC} 已备份至: $BACKUP_FILE"

        echo -e "${YELLOW}[2/3]${NC} 写入新源 (${SELECTED_NAME})..."
        cat > /etc/apt/sources.list <<EOF
deb ${SELECTED_URL} ${CODENAME} main non-free contrib non-free-firmware
deb-src ${SELECTED_URL} ${CODENAME} main non-free contrib non-free-firmware
EOF

        echo -e "${YELLOW}[3/3]${NC} 更新软件包索引..."
        apt-get update
        
        if [ $? -eq 0 ]; then
            echo -e "${GREEN}[成功]${NC} 软件源切换完成并更新索引。"
        else
            echo -e "${RED}[警告]${NC} 更新索引时出现错误，请检查网络或源地址。"
        fi

        read -p "是否立即升级所有软件包? (耗时较长) (y/n, 默认 n): " UPGRADE_CHOICE
        if [[ "$UPGRADE_CHOICE" =~ ^[Yy]$ ]]; then
            echo -e "${YELLOW}开始系统升级...${NC}"
            apt-get dist-upgrade -y
            echo -e "${GREEN}[完成]${NC} 系统升级结束。"
        else
            echo "已跳过系统升级。"
        fi
        
        # 操作完成后返回主菜单，不再循环停留在换源界面
        break
    done
    read -p "按回车键返回主菜单..."
}

# ==================== 功能 3: 自动更新脚本 ====================
update_script() {
    echo -e "${YELLOW}[信息]${NC} 正在检查最新版本..."
    
    # 定义 GitHub 原始文件地址 (请确保替换为您仓库中实际的 raw 地址)
    # 注意：github.com/zs08/kali-init-tui/blob/main/kali_init.sh 的 raw 地址通常是:
    GITHUB_RAW_URL="https://raw.githubusercontent.com/zs08/kali-init-tui/main/kali_init.sh"
    
    # 创建临时文件
    TEMP_SCRIPT=$(mktemp /tmp/kali_init_update.XXXXXX.sh)
    
    # 下载新脚本
    if curl -sL -o "$TEMP_SCRIPT" "$GITHUB_RAW_URL"; then
        # 简单校验：检查新脚本是否包含关键标识，防止下载失败或空文件
        if grep -q "Kali Linux 初始化配置工具" "$TEMP_SCRIPT"; then
            echo -e "${GREEN}[成功]${NC} 新版本下载成功。"
            
            # 比较版本（可选，这里简单直接替换）
            echo -e "${YELLOW}[提示]${NC} 正在替换旧脚本..."
            
            # 赋予执行权限
            chmod +x "$TEMP_SCRIPT"
            
            # 移动覆盖原脚本
            mv "$TEMP_SCRIPT" "$SCRIPT_PATH"
            
            echo -e "${GREEN}[完成]${NC} 脚本已更新至最新版本！"
            echo -e "${YELLOW}[提示]${NC} 脚本将在 3 秒后自动重启以应用更新..."
            sleep 3
            
            # 重新执行当前脚本（此时已是新版本）
            exec bash "$SCRIPT_PATH"
        else
            echo -e "${RED}[失败]${NC} 下载的脚本内容无效，已取消更新。"
            rm -f "$TEMP_SCRIPT"
            read -p "按回车键返回主菜单..."
        fi
    else
        echo -e "${RED}[失败]${NC} 无法连接到 GitHub 下载更新。"
        echo -e "${YELLOW}[建议]${NC} 请检查网络连接或手动访问: https://github.com/zs08/kali-init-tui"
        rm -f "$TEMP_SCRIPT"
        read -p "按回车键返回主菜单..."
    fi
}

# ==================== 主菜单 ====================
main_menu() {
    while true; do
        clear
        echo ""
        echo -e "${GREEN}========================================${NC}"
        echo -e "${GREEN}  Kali Linux 初始化配置工具 (CLI版)   ${NC}"
        echo -e "${GREEN}  作者: zs08                          ${NC}"
        echo -e "${GREEN}========================================${NC}"
        echo "1) 自动化配置中文环境"
        echo "2) 更换国内软件源"
        echo "3) 检查并更新脚本"
        echo "4) 退出"
        echo ""
        
        read -p "请选择操作 [1-4]: " MAIN_CHOICE

        case "$MAIN_CHOICE" in
            1) 
                set_chinese_env 
                ;;
            2) 
                change_sources 
                ;;
            3) 
                update_script 
                ;;
            4) 
                echo "感谢使用！再见。"
                exit 0 
                ;;
            *) 
                echo -e "${RED}无效输入，请重新选择。${NC}"
                sleep 1
                ;;
        esac
    done
}

# 启动主菜单
main_menu