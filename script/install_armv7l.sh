#!/bin/bash

#========================================================
#   Nezha Dashboard ARMv7l 一键安装脚本
#   System Required: ARMv7l (32-bit ARM)
#   Description: 自动下载并安装 Nezha Dashboard ARMv7l 版本
#   Version: 1.2.0
#========================================================

NZ_BASE_PATH="/opt/nezha"
NZ_DASHBOARD_PATH="${NZ_BASE_PATH}/dashboard"
NZ_DASHBOARD_SERVICE="nezha-dashboard"
NZ_VERSION="latest"

# GitHub 代理列表（国内加速）
GITHUB_PROXY_LIST=(
    "https://gh.llkk.cc/"
    "https://gh-proxy.net/"
    "https://ghfast.top/"
    "https://gh-proxy.com/"
)

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
    
    # 尝试使用代理获取版本信息
    for proxy in "${GITHUB_PROXY_LIST[@]}"; do
        API_URL="${proxy}https://api.github.com/repos/Yizelove/nezha/releases/latest"
        NZ_VERSION=$(curl -s --connect-timeout 5 "${API_URL}" | grep '"tag_name":' | sed -E 's/.*"([^"]+)".*/\1/')
        
        if [[ -n "${NZ_VERSION}" ]]; then
            success "最新版本: ${NZ_VERSION}"
            if [[ -n "${proxy}" ]]; then
                info "使用代理: ${proxy}"
            fi
            return 0
        fi
    done
    
    err "无法获取最新版本号，使用默认版本"
    NZ_VERSION="latest"
}

# 下载 Dashboard
download_dashboard() {
    info "下载 Nezha Dashboard ARMv7l 版本..."
    
    mkdir -p ${NZ_DASHBOARD_PATH}
    cd ${NZ_DASHBOARD_PATH}
    
    # 构建基础下载 URL
    if [[ "${NZ_VERSION}" == "latest" ]]; then
        BASE_URL="https://github.com/Yizelove/nezha/releases/latest/download/dashboard-linux-armv7l.zip"
    else
        BASE_URL="https://github.com/Yizelove/nezha/releases/download/${NZ_VERSION}/dashboard-linux-armv7l.zip"
    fi
    
    # 尝试使用不同的代理下载
    DOWNLOAD_SUCCESS=0
    for proxy in "${GITHUB_PROXY_LIST[@]}"; do
        DOWNLOAD_URL="${proxy}${BASE_URL}"
        
        if [[ -n "${proxy}" ]]; then
            info "尝试使用代理下载: ${proxy}"
        else
            info "尝试直接下载..."
        fi
        
        info "下载地址: ${DOWNLOAD_URL}"
        
        # 下载文件（设置超时时间）
        if wget --timeout=30 --tries=2 -O dashboard.zip "${DOWNLOAD_URL}"; then
            success "下载完成"
            DOWNLOAD_SUCCESS=1
            break
        else
            err "下载失败，尝试下一个源..."
        fi
    done
    
    if [[ ${DOWNLOAD_SUCCESS} -eq 0 ]]; then
        err "所有下载源均失败，请检查网络连接或手动下载"
        err "手动下载地址: ${BASE_URL}"
        exit 1
    fi
    
    # 解压
    info "解压文件..."
    unzip -o dashboard.zip
    rm -f dashboard.zip
    
    # 设置执行权限
    # 注意：解压出来的二进制文件名在 .goreleaser.yml 中定义为 dashboard-linux-arm
    chmod +x dashboard-linux-arm
    
    success "Dashboard 文件下载并解压完成"
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
ExecStart=${NZ_DASHBOARD_PATH}/dashboard-linux-arm
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
    else
        err "服务启动失败，请检查日志"
        journalctl -u ${NZ_DASHBOARD_SERVICE} -n 50
        exit 1
    fi
}

# 停止服务
stop_service() {
    info "停止 Nezha Dashboard 服务..."
    systemctl stop ${NZ_DASHBOARD_SERVICE}
    success "服务已停止"
}

# 重启服务
restart_service() {
    info "重启 Nezha Dashboard 服务..."
    systemctl restart ${NZ_DASHBOARD_SERVICE}
    success "服务已重启"
}

# 更新 Dashboard
update_dashboard() {
    info "开始更新 Nezha Dashboard..."
    
    if [[ ! -d "${NZ_DASHBOARD_PATH}" ]]; then
        err "未检测到已安装的 Nezha Dashboard，请先执行安装"
        exit 1
    fi
    
    get_latest_version
    
    # 检查当前版本（如果可能）
    # 这里简单处理，直接下载最新版覆盖
    
    stop_service
    download_dashboard
    start_service
    
    success "Nezha Dashboard 更新完成！"
}

# 卸载 Dashboard
uninstall_dashboard() {
    printf "${yellow}确定要卸载 Nezha Dashboard 吗？(y/n): ${plain}"
    read -r confirm
    if [[ "${confirm}" != "y" ]]; then
        info "已取消卸载"
        return
    fi
    
    info "开始卸载 Nezha Dashboard..."
    systemctl stop ${NZ_DASHBOARD_SERVICE}
    systemctl disable ${NZ_DASHBOARD_SERVICE}
    rm -f /etc/systemd/system/${NZ_DASHBOARD_SERVICE}.service
    systemctl daemon-reload
    
    printf "${yellow}是否删除所有数据文件（包括配置和数据库）？(y/n): ${plain}"
    read -r delete_data
    if [[ "${delete_data}" == "y" ]]; then
        rm -rf ${NZ_BASE_PATH}
        success "所有数据已删除"
    else
        rm -f ${NZ_DASHBOARD_PATH}/dashboard-linux-arm
        info "保留了数据文件在: ${NZ_BASE_PATH}"
    fi
    
    success "Nezha Dashboard 卸载完成"
}

# 显示使用说明
show_usage() {
    echo ""
    success "=========================================="
    success "  Nezha Dashboard ARMv7l 管理说明"
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

# 菜单
menu() {
    clear
    echo ""
    success "=========================================="
    success "  Nezha Dashboard ARMv7l 一键管理脚本"
    success "=========================================="
    echo ""
    echo "  1. 安装 Nezha Dashboard"
    echo "  2. 更新 Nezha Dashboard (一键更新)"
    echo "  3. 启动 Nezha Dashboard"
    echo "  4. 停止 Nezha Dashboard"
    echo "  5. 重启 Nezha Dashboard"
    echo "  6. 卸载 Nezha Dashboard"
    echo "  0. 退出脚本"
    echo ""
    printf "请输入数字 [0-6]: "
    read -r num
    case "$num" in
        1)
            check_arch
            check_system
            install_dependencies
            get_latest_version
            download_dashboard
            create_service
            start_service
            show_usage
            ;;
        2)
            check_arch
            update_dashboard
            ;;
        3)
            start_service
            ;;
        4)
            stop_service
            ;;
        5)
            restart_service
            ;;
        6)
            uninstall_dashboard
            ;;
        0)
            exit 0
            ;;
        *)
            err "请输入正确的数字 [0-6]"
            sleep 2
            menu
            ;;
    esac
}

# 执行菜单
if [[ $# -gt 0 ]]; then
    case "$1" in
        "install")
            check_arch
            check_system
            install_dependencies
            get_latest_version
            download_dashboard
            create_service
            start_service
            show_usage
            ;;
        "update")
            check_arch
            update_dashboard
            ;;
        "start")
            start_service
            ;;
        "stop")
            stop_service
            ;;
        "restart")
            restart_service
            ;;
        *)
            menu
            ;;
    esac
else
    menu
fi
