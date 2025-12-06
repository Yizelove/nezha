#!/bin/bash

#========================================================
# Nezha Dashboard ARMv7l 一键安装脚本
# 支持 ARMv7l 架构的 Linux 系统
#========================================================

set -e

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# 日志函数
log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# 检查系统架构
check_arch() {
    local arch=$(uname -m)
    case "$arch" in
        armv7l|armv7|arm)
            log_success "检测到 ARMv7l 架构"
            return 0
            ;;
        *)
            log_error "当前系统架构为 $arch，此脚本仅支持 ARMv7l 架构"
            exit 1
            ;;
    esac
}

# 检查依赖
check_dependencies() {
    log_info "检查系统依赖..."
    
    local missing_deps=()
    
    for cmd in curl wget tar gzip; do
        if ! command -v "$cmd" &> /dev/null; then
            missing_deps+=("$cmd")
        fi
    done
    
    if [ ${#missing_deps[@]} -gt 0 ]; then
        log_warn "缺少以下依赖: ${missing_deps[*]}"
        log_info "正在安装依赖..."
        
        if command -v apt-get &> /dev/null; then
            sudo apt-get update
            sudo apt-get install -y "${missing_deps[@]}"
        elif command -v yum &> /dev/null; then
            sudo yum install -y "${missing_deps[@]}"
        elif command -v apk &> /dev/null; then
            sudo apk add "${missing_deps[@]}"
        else
            log_error "无法自动安装依赖，请手动安装: ${missing_deps[*]}"
            exit 1
        fi
    fi
    
    log_success "依赖检查完成"
}

# 获取最新版本
get_latest_version() {
    log_info "获取最新版本信息..."
    
    # 尝试从 GitHub API 获取最新版本
    local version=$(curl -s https://api.github.com/repos/Yizelove/nezha/releases/latest | grep -o '"tag_name": "[^"]*"' | head -1 | cut -d'"' -f4)
    
    if [ -z "$version" ]; then
        log_warn "无法获取最新版本，使用默认版本 v1.0.0"
        version="v1.0.0"
    fi
    
    echo "$version"
}

# 下载二进制文件
download_binary() {
    local version=$1
    local download_dir="${2:-.}"
    
    log_info "下载 Nezha Dashboard ARMv7l 版本 $version..."
    
    # 构建下载 URL
    local binary_name="dashboard-linux-arm-v7l"
    local download_url="https://github.com/Yizelove/nezha/releases/download/${version}/${binary_name}.zip"
    
    # 检查国内镜像
    local use_mirror=false
    if ping -c 1 -W 1 github.com &> /dev/null; then
        log_info "使用 GitHub 源下载"
    else
        log_warn "GitHub 连接缓慢，尝试使用国内镜像"
        download_url="https://ghproxy.com/https://github.com/Yizelove/nezha/releases/download/${version}/${binary_name}.zip"
        use_mirror=true
    fi
    
    # 下载文件
    if command -v wget &> /dev/null; then
        wget -O "${download_dir}/${binary_name}.zip" "$download_url" || {
            if [ "$use_mirror" = false ]; then
                log_warn "GitHub 下载失败，尝试使用国内镜像"
                download_url="https://ghproxy.com/https://github.com/Yizelove/nezha/releases/download/${version}/${binary_name}.zip"
                wget -O "${download_dir}/${binary_name}.zip" "$download_url"
            else
                log_error "下载失败"
                return 1
            fi
        }
    elif command -v curl &> /dev/null; then
        curl -L -o "${download_dir}/${binary_name}.zip" "$download_url" || {
            if [ "$use_mirror" = false ]; then
                log_warn "GitHub 下载失败，尝试使用国内镜像"
                download_url="https://ghproxy.com/https://github.com/Yizelove/nezha/releases/download/${version}/${binary_name}.zip"
                curl -L -o "${download_dir}/${binary_name}.zip" "$download_url"
            else
                log_error "下载失败"
                return 1
            fi
        }
    fi
    
    log_success "下载完成"
    echo "${download_dir}/${binary_name}.zip"
}

# 安装二进制文件
install_binary() {
    local zip_file=$1
    local install_dir="${2:-/opt/nezha}"
    
    log_info "安装 Nezha Dashboard 到 $install_dir..."
    
    # 创建安装目录
    sudo mkdir -p "$install_dir"
    
    # 解压文件
    cd "$install_dir"
    sudo unzip -o "$zip_file"
    
    # 设置权限
    sudo chmod +x dashboard-linux-arm-v7l
    
    # 创建符号链接
    sudo ln -sf dashboard-linux-arm-v7l dashboard
    
    log_success "安装完成"
}

# 创建 systemd 服务
create_systemd_service() {
    local install_dir="${1:-/opt/nezha}"
    local config_dir="${2:-/etc/nezha}"
    
    log_info "创建 systemd 服务..."
    
    # 创建配置目录
    sudo mkdir -p "$config_dir"
    
    # 创建服务文件
    sudo tee /etc/systemd/system/nezha-dashboard.service > /dev/null <<EOF
[Unit]
Description=Nezha Dashboard
After=network.target

[Service]
Type=simple
User=root
WorkingDirectory=$install_dir
ExecStart=$install_dir/dashboard -c $config_dir/config.yaml
Restart=on-failure
RestartSec=10

[Install]
WantedBy=multi-user.target
EOF
    
    # 重新加载 systemd
    sudo systemctl daemon-reload
    
    log_success "systemd 服务创建完成"
}

# 启动服务
start_service() {
    log_info "启动 Nezha Dashboard 服务..."
    
    sudo systemctl enable nezha-dashboard.service
    sudo systemctl start nezha-dashboard.service
    
    # 等待服务启动
    sleep 2
    
    if sudo systemctl is-active --quiet nezha-dashboard.service; then
        log_success "服务启动成功"
        
        # 获取服务状态
        local status=$(sudo systemctl status nezha-dashboard.service)
        log_info "服务状态:\n$status"
    else
        log_error "服务启动失败"
        sudo systemctl status nezha-dashboard.service
        return 1
    fi
}

# 显示安装信息
show_info() {
    log_success "Nezha Dashboard ARMv7l 版本安装完成！"
    echo ""
    echo -e "${BLUE}=== 安装信息 ===${NC}"
    echo "安装目录: /opt/nezha"
    echo "配置目录: /etc/nezha"
    echo "服务名称: nezha-dashboard"
    echo ""
    echo -e "${BLUE}=== 常用命令 ===${NC}"
    echo "启动服务:   sudo systemctl start nezha-dashboard"
    echo "停止服务:   sudo systemctl stop nezha-dashboard"
    echo "重启服务:   sudo systemctl restart nezha-dashboard"
    echo "查看日志:   sudo journalctl -u nezha-dashboard -f"
    echo "查看状态:   sudo systemctl status nezha-dashboard"
    echo ""
}

# 主函数
main() {
    log_info "开始安装 Nezha Dashboard ARMv7l 版本..."
    echo ""
    
    # 检查架构
    check_arch
    
    # 检查依赖
    check_dependencies
    
    # 获取最新版本
    local version=$(get_latest_version)
    log_info "将安装版本: $version"
    
    # 创建临时目录
    local temp_dir=$(mktemp -d)
    trap "rm -rf $temp_dir" EXIT
    
    # 下载二进制文件
    local zip_file=$(download_binary "$version" "$temp_dir")
    
    # 安装二进制文件
    install_binary "$zip_file" "/opt/nezha"
    
    # 创建 systemd 服务
    create_systemd_service "/opt/nezha" "/etc/nezha"
    
    # 启动服务
    start_service
    
    # 显示安装信息
    show_info
}

# 执行主函数
main "$@"
