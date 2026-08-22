# DeepSeek Harness Docker

> DSH 的 Docker 镜像 — 内置 Caddy 反向代理，免密码认证，开箱即用。

[![Docker Build & Push](https://github.com/SimonQvQ/deepseek-harness-docker/actions/workflows/docker-build.yml/badge.svg)](https://github.com/SimonQvQ/deepseek-harness-docker/actions/workflows/docker-build.yml)

## 一行命令启动

```bash
docker run -d -p 3080:3080 -v dsh-data:/opt/dsh-home ghcr.io/simonqvq/deepseek-harness:latest
```

打开 http://localhost:3080，在 Web UI 的 Settings 中配置 API Key 即可使用。

## 镜像仓库

| 仓库 | 地址 |
|------|------|
| Docker Hub | [`simonqvq/deepseek-harness`](https://hub.docker.com/r/simonqvq/deepseek-harness) |
| GHCR | [`ghcr.io/simonqvq/deepseek-harness`](https://github.com/SimonQvQ/deepseek-harness-docker/pkgs/container/deepseek-harness) |

## 环境变量

| 变量 | 含义 | 默认值 |
|------|------|--------|
| `DSH_PORT` | DSH 内部监听端口（127.0.0.1） | `3079` |
| `PROXY_PORT` | Caddy 反向代理对外端口 | `3080` |
| `PROXY_USERNAME` | Basic Auth 用户名（可选，不设则无认证） | — |
| `PROXY_PASSWORD` | Basic Auth 密码（可选） | — |
| `DSH_TRUSTED_HOSTS` | 通过局域网 IP/域名访问时声明的信任主机（逗号/空格分隔，不带端口） | 自动收集本机 IP |
| `DSH_UPDATE_ON_START` | `true` 时启动前自动更新 DSH 到最新版 | `false` |

> API Key 直接在 DSH Web UI 中配置，无需通过环境变量传入。

### 局域网访问（重要）

DSH 的 `/api` 接口有**浏览器信任围栏**：默认只接受 `localhost`/`127.0.0.1`。通过局域网 IP 访问（如 `http://192.168.0.105:3080`）时，所有 `/api` 请求会返回 `HTTP 403`。

解决：启动时声明你的访问地址：

```bash
docker run -d -p 3080:3080 \
  -e DSH_TRUSTED_HOSTS=192.168.0.105 \
  -v dsh-data:/opt/dsh-home \
  ghcr.io/simonqvq/deepseek-harness:latest
```

Caddy 会将请求 Host 原样转发给 DSH，因此只需填写你访问的 IP（不带端口）。

## 使用方式

### Docker Compose

```bash
git clone https://github.com/SimonQvQ/deepseek-harness-docker.git
cd deepseek-harness-docker
docker compose up -d
```

### Docker Run

```bash
docker run -d -p 3080:3080 -v dsh-data:/opt/dsh-home ghcr.io/simonqvq/deepseek-harness:latest
```

### 启用 Basic Auth

```bash
docker run -d -p 3080:3080 \
  -e PROXY_USERNAME=admin \
  -e PROXY_PASSWORD=changeme \
  -v dsh-data:/opt/dsh-home \
  ghcr.io/simonqvq/deepseek-harness:latest
```

### 容器内更新 DSH

```bash
# 方法一：拉取新镜像
docker pull ghcr.io/simonqvq/deepseek-harness:latest
docker stop deepseek-harness && docker rm deepseek-harness
docker run -d -p 3080:3080 -v dsh-data:/opt/dsh-home ghcr.io/simonqvq/deepseek-harness:latest

# 方法二：启动时自动更新
docker run -d -p 3080:3080 \
  -e DSH_UPDATE_ON_START=true \
  -v dsh-data:/opt/dsh-home \
  ghcr.io/simonqvq/deepseek-harness:latest
```

## 特性

- **免密码认证** — 个人/私有部署开箱即用
- **Caddy 反向代理** — 自动处理 WebSocket、长超时、安全头
- **可选 Basic Auth** — 对外暴露时加密码保护
- **每日自动构建** — GitHub Actions 每天 00:00 UTC 拉取最新 DSH 重建
- **数据持久化** — 挂载 `/opt/dsh-home` 保留会话和设置