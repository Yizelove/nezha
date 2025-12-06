# Nezha Dashboard ARMv7l 安装指南

本文档介绍如何在 ARMv7l 架构的 Linux 系统上安装 Nezha Dashboard。

## 系统要求

- **架构**: ARMv7l (32 位 ARM)
- **操作系统**: Linux (Debian/Ubuntu, CentOS/RHEL, Alpine 等)
- **内存**: 最少 256MB RAM
- **磁盘**: 最少 100MB 可用空间
- **网络**: 需要互联网连接以下载二进制文件

## 支持的 Linux 发行版

- Ubuntu 18.04 及以上
- Debian 9 及以上
- CentOS 7 及以上
- Raspberry Pi OS
- Alpine Linux
- 其他基于 Linux 的 ARMv7l 系统

## 快速安装

### 方法一：使用一键安装脚本（推荐）

```bash
# 下载安装脚本
curl -fsSL https://raw.githubusercontent.com/Yizelove/nezha/master/script/install_armv7l.sh -o install_armv7l.sh

# 或使用 wget
wget https://raw.githubusercontent.com/Yizelove/nezha/master/script/install_armv7l.sh

# 执行安装脚本
sudo bash install_armv7l.sh
```

### 方法二：手动安装

#### 1. 检查系统架构

```bash
uname -m
# 输出应该是 armv7l 或 arm
```

#### 2. 下载二进制文件

访问 [GitHub Releases](https://github.com/Yizelove/nezha/releases) 页面，下载名称为 `dashboard-linux-arm-v7l.zip` 的文件。

或使用命令下载最新版本：

```bash
# 获取最新版本号
VERSION=$(curl -s https://api.github.com/repos/Yizelove/nezha/releases/latest | grep -o '"tag_name": "[^"]*"' | head -1 | cut -d'"' -f4)

# 下载二进制文件
wget https://github.com/Yizelove/nezha/releases/download/${VERSION}/dashboard-linux-arm-v7l.zip
```

#### 3. 安装二进制文件

```bash
# 创建安装目录
sudo mkdir -p /opt/nezha

# 解压文件
sudo unzip dashboard-linux-arm-v7l.zip -d /opt/nezha

# 设置执行权限
sudo chmod +x /opt/nezha/dashboard-linux-arm-v7l

# 创建符号链接
sudo ln -sf /opt/nezha/dashboard-linux-arm-v7l /opt/nezha/dashboard
```

#### 4. 创建配置文件

```bash
# 创建配置目录
sudo mkdir -p /etc/nezha

# 创建基础配置文件
sudo tee /etc/nezha/config.yaml > /dev/null <<'EOF'
# Nezha Dashboard 配置文件示例
# 详细配置说明请参考官方文档

# 监听地址和端口
listen: ":8008"

# 数据库配置
db:
  path: "/etc/nezha/data.db"

# 管理员账户
admin:
  username: "admin"
  password: "admin"  # 首次运行后请修改密码

# 其他配置项...
EOF
```

#### 5. 创建 systemd 服务

```bash
sudo tee /etc/systemd/system/nezha-dashboard.service > /dev/null <<'EOF'
[Unit]
Description=Nezha Dashboard
After=network.target

[Service]
Type=simple
User=root
WorkingDirectory=/opt/nezha
ExecStart=/opt/nezha/dashboard -c /etc/nezha/config.yaml
Restart=on-failure
RestartSec=10

[Install]
WantedBy=multi-user.target
EOF
```

#### 6. 启动服务

```bash
# 重新加载 systemd 配置
sudo systemctl daemon-reload

# 启用服务开机自启
sudo systemctl enable nezha-dashboard.service

# 启动服务
sudo systemctl start nezha-dashboard.service

# 查看服务状态
sudo systemctl status nezha-dashboard.service
```

## 常用命令

### 服务管理

```bash
# 启动服务
sudo systemctl start nezha-dashboard

# 停止服务
sudo systemctl stop nezha-dashboard

# 重启服务
sudo systemctl restart nezha-dashboard

# 查看服务状态
sudo systemctl status nezha-dashboard

# 查看实时日志
sudo journalctl -u nezha-dashboard -f

# 查看历史日志
sudo journalctl -u nezha-dashboard -n 100
```

### 手动运行

```bash
# 直接运行二进制文件
/opt/nezha/dashboard -c /etc/nezha/config.yaml

# 指定监听地址
/opt/nezha/dashboard -c /etc/nezha/config.yaml -listen ":8080"
```

## 访问 Dashboard

安装完成后，可以通过以下地址访问 Nezha Dashboard：

```
http://<你的服务器IP>:8008
```

默认登录凭证：
- **用户名**: admin
- **密码**: admin

**重要**: 首次登录后请立即修改密码！

## 配置文件说明

配置文件位于 `/etc/nezha/config.yaml`，主要配置项包括：

| 配置项 | 说明 | 默认值 |
|--------|------|--------|
| listen | 监听地址和端口 | :8008 |
| db.path | SQLite 数据库文件路径 | /etc/nezha/data.db |
| admin.username | 管理员用户名 | admin |
| admin.password | 管理员密码 | admin |

## 故障排查

### 1. 服务无法启动

```bash
# 查看详细错误日志
sudo journalctl -u nezha-dashboard -n 50

# 尝试手动运行以查看错误
sudo /opt/nezha/dashboard -c /etc/nezha/config.yaml
```

### 2. 无法访问 Dashboard

- 检查防火墙是否开放了 8008 端口
- 确认服务正在运行：`sudo systemctl status nezha-dashboard`
- 检查网络连接：`curl http://localhost:8008`

### 3. 权限问题

```bash
# 检查文件权限
ls -la /opt/nezha/
ls -la /etc/nezha/

# 修复权限
sudo chown -R root:root /opt/nezha
sudo chown -R root:root /etc/nezha
sudo chmod 755 /opt/nezha
sudo chmod 755 /etc/nezha
```

### 4. 数据库错误

```bash
# 重置数据库（会丢失所有数据）
sudo rm /etc/nezha/data.db
sudo systemctl restart nezha-dashboard
```

## 升级

### 升级到最新版本

```bash
# 停止服务
sudo systemctl stop nezha-dashboard

# 下载最新版本
VERSION=$(curl -s https://api.github.com/repos/Yizelove/nezha/releases/latest | grep -o '"tag_name": "[^"]*"' | head -1 | cut -d'"' -f4)
wget https://github.com/Yizelove/nezha/releases/download/${VERSION}/dashboard-linux-arm-v7l.zip

# 备份旧版本
sudo cp /opt/nezha/dashboard-linux-arm-v7l /opt/nezha/dashboard-linux-arm-v7l.bak

# 解压新版本
sudo unzip -o dashboard-linux-arm-v7l.zip -d /opt/nezha

# 设置权限
sudo chmod +x /opt/nezha/dashboard-linux-arm-v7l

# 启动服务
sudo systemctl start nezha-dashboard

# 验证升级
sudo systemctl status nezha-dashboard
```

## 卸载

```bash
# 停止服务
sudo systemctl stop nezha-dashboard

# 禁用开机自启
sudo systemctl disable nezha-dashboard

# 删除服务文件
sudo rm /etc/systemd/system/nezha-dashboard.service

# 删除安装文件
sudo rm -rf /opt/nezha

# 删除配置文件（可选）
sudo rm -rf /etc/nezha

# 重新加载 systemd
sudo systemctl daemon-reload
```

## 获取帮助

- 官方文档: [https://nezha.wiki/](https://nezha.wiki/)
- GitHub Issues: [https://github.com/Yizelove/nezha/issues](https://github.com/Yizelove/nezha/issues)
- 官方论坛: [https://bbs.youdianyisi.com/](https://bbs.youdianyisi.com/)

## 许可证

Nezha Dashboard 采用 Apache License 2.0 许可证。详见 [LICENSE](LICENSE) 文件。

---

**最后更新**: 2025-12-05

**支持的版本**: v1.0.0 及以上
