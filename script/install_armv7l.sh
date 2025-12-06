#!/bin/bash

#========================================================
#   Nezha Dashboard ARMv7l 一键安装脚本
#   System Required: ARMv7l (32-bit ARM)
#   Description: 自动下载并安装 Nezha Dashboard ARMv7l 版本
#   Version: 1.0.0
#========================================================

NZ_BASE_PATH="/opt/nezha"
NZ_DASHBOARD_PATH="${NZ_BASE_PATH}/dashboard"
NZ_DASHBOARD_SERVICE="nezha-dashboard"
NZ_VERSION="latest"

red='\033[0;31m'
green='\033[0;32m'
yellow='\033[0;33m'
plain='\033[0m'

err() {
    printf "${red}%s${plain}\n" "$*" >&2
}

success() {
    printf "${green}%s${plain}\n" "$*"
}

info() {
    printf "${yellow}%s${plain}\n" "$*"
}

# 检测系统架构
check_arch() {
    ARCH=$(uname -m)
    if [[ "${ARCH}" != "armv7l" ]]; then
        err "错误: 此脚本仅支持 ARMv7l 架构系统"
        err "当前系统架构: ${ARCH}"
        exit 1
    fi
    success "系统架构检测通过: ${ARCH}"
}

# 检测系统类型
check_system() {
    if [[ -f /etc/redhat-release ]]; then
        RELEASE="centos"
    elif cat /etc/issue | grep -Eqi "debian"; then
        RELEASE="debian"
    elif cat /etc/issue | grep -Eqi "ubuntu"; then
        RELEASE="ubuntu"
    elif cat /etc/issue | grep -Eqi "centos|red hat|redhat"; then
        RELEASE="centos"
    elif cat /proc/version | grep -Eqi "debian"; then
        RELEASE="debian"
    elif cat /proc/version | grep -Eqi "ubuntu"; then
        RELEASE="ubuntu"
    elif cat /proc/version | grep -Eqi "centos|red hat|redhat"; then
        RELEASE="centos"
    else
        err "不支持的系统类型"
        exit 1
    fi
    success "系统类型: ${RELEASE}"
}

# 安装依赖
install_dependencies() {
    info "安装依赖包..."
    if [[ "${RELEASE}" == "centos" ]]; then
        yum install -y wget curl unzip
    else
        apt-get update
        apt-get install -y wget curl unzip
    fi
}

# 获取最新版本号
get_latest_version() {
    info "获取最新版本信息..."
    NZ_VERSION=$(curl -s "https://api.github.com/repos/Yizelove/nezha/releases/latest" | grep '"tag_name":' | sed -E 's/.*"([^"]+)".*/\1/')
    if [[ -z "${NZ_VERSION}" ]]; then
        err "无法获取最新版本号，使用默认版本"
        NZ_VERSION="latest"
    else
        success "最新版本: ${NZ_VERSION}"
    fi
}

# 下载 Dashboard
download_dashboard() {
    info "下载 Nezha Dashboard ARMv7l 版本..."
    
    mkdir -p ${NZ_DASHBOARD_PATH}
    cd ${NZ_DASHBOARD_PATH}
    
    # 构建下载 URL
    if [[ "${NZ_VERSION}" == "latest" ]]; then
        DOWNLOAD_URL="https://github.com/Yizelove/nezha/releases/latest/download/dashboard-linux-arm-v7l.zip"
    else
        DOWNLOAD_URL="https://github.com/Yizelove/nezha/releases/download/${NZ_VERSION}/dashboard-linux-arm-v7l.zip"
    fi
    
    info "下载地址: ${DOWNLOAD_URL}"
    
    # 下载文件
    if wget -O dashboard.zip "${DOWNLOAD_URL}"; then
        success "下载完成"
    else
        err "下载失败，请检查网络连接或版本号"
        exit 1
    fi
    
    # 解压
    info "解压文件..."
    unzip -o dashboard.zip
    rm -f dashboard.zip
    
    # 设置执行权限
    chmod +x dashboard-linux-arm-v7l
    
    success "Dashboard 安装完成"
}

# 创建 systemd 服务
create_service() {
    info "创建 systemd 服务..."
    
    cat > /etc/systemd/system/${NZ_DASHBOARD_SERVICE}.service <<EOF
[Unit]
Description=Nezha Dashboard
After=network.target

[Service]
Type=simple
User=root
WorkingDirectory=${NZ_DASHBOARD_PATH}
ExecStart=${NZ_DASHBOARD_PATH}/dashboard-linux-arm-v7l
Restart=on-failure
RestartSec=10s

[Install]
WantedBy=multi-user.target
EOF
    
    systemctl daemon-reload
    systemctl enable ${NZ_DASHBOARD_SERVICE}
    
    success "服务创建完成"
}

# 启动服务
start_service() {
    info "启动 Nezha Dashboard 服务..."
    systemctl start ${NZ_DASHBOARD_SERVICE}
    
    sleep 3
    
    if systemctl is-active --quiet ${NZ_DASHBOARD_SERVICE}; then
        success "Nezha Dashboard 启动成功！"
        info "查看状态: systemctl status ${NZ_DASHBOARD_SERVICE}"
        info "查看日志: journalctl -u ${NZ_DASHBOARD_SERVICE} -f"
    else
        err "服务启动失败，请检查日志"
        journalctl -u ${NZ_DASHBOARD_SERVICE} -n 50
        exit 1
    fi
}

# 显示使用说明
show_usage() {
    echo ""
    success "=========================================="
    success "  Nezha Dashboard ARMv7l 安装完成！"
    success "=========================================="
    echo ""
    info "常用命令:"
    echo "  启动服务: systemctl start ${NZ_DASHBOARD_SERVICE}"
    echo "  停止服务: systemctl stop ${NZ_DASHBOARD_SERVICE}"
    echo "  重启服务: systemctl restart ${NZ_DASHBOARD_SERVICE}"
    echo "  查看状态: systemctl status ${NZ_DASHBOARD_SERVICE}"
    echo "  查看日志: journalctl -u ${NZ_DASHBOARD_SERVICE} -f"
    echo ""
    info "安装路径: ${NZ_DASHBOARD_PATH}"
    info "配置文件: ${NZ_DASHBOARD_PATH}/data/config.yaml"
    echo ""
}

# 主函数
main() {
    echo ""
    success "=========================================="
    success "  Nezha Dashboard ARMv7l 一键安装脚本"
    success "=========================================="
    echo ""
    
    check_arch
    check_system
    install_dependencies
    get_latest_version
    download_dashboard
    create_service
    start_service
    show_usage
}

# 执行主函数
main
