# DeepSeek Harness Docker

DSH (DeepSeek Harness) 的 Docker 镜像，内置 **Caddy 反向代理**，默认**免密码认证**（也可选 Basic Auth），支持 **Docker Hub + GHCR** 双仓库自动构建。

## 环境变量

| 变量 | 含义 | 默认值 |
|------|------|--------|
| `DSH_PORT` | DSH 在容器内 `127.0.0.1` 上的监听端口 | `3079` |
| `PROXY_PORT` | Caddy 反向代理对外监听端口（局域网入口） | `3080` |
| `PROXY_USERNAME` | Basic Auth 用户名（可选） | 未设置（无认证） |
| `PROXY_PASSWORD` | Basic Auth 密码（可选） | 未设置（无认证） |
| `DSH_UPDATE_ON_START` | 设 `true` 时容器启动前自动更新 DSH 到最新版 | `false` |
| `DEEPSEEK_API_KEY` | DeepSeek API Key（必需） | 无 |
| `TEAMOROUTER_API_KEY` | TeamoRouter API Key（可选） | 无 |

## 快速开始

```bash
# 1. 准备环境变量
cp .env.example .env
# 编辑 .env，填入 DEEPSEEK_API_KEY

# 2. 启动
docker compose up -d

# 3. 打开 http://localhost:3080
```

## 容器内更新 DSH

有两种更新方式：

**方式一（推荐）：镜像自动更新**
GitHub Actions 每日 00:00 UTC 自动重建镜像并推送 `latest` 标签。重新拉取即可：

```bash
docker compose pull && docker compose up -d
```

**方式二：容器内直接更新**
设置 `DSH_UPDATE_ON_START=true` 后，每次容器启动都会执行 `npm install -g @deepseek-ai/dsh@latest`：

```bash
docker run -d -p 3080:3080 \
  -e DSH_UPDATE_ON_START=true \
  -e DEEPSEEK_API_KEY=sk-xxx \
  <image-name>
```

> 注意：容器内更新只在本次运行生效，镜像本身不会改变。若容器被删除重建，需重新执行更新。持久化到镜像请用方式一。

## Basic Auth（可选）

设置 `PROXY_USERNAME` 和 `PROXY_PASSWORD` 后，Caddy 会自动对代理入口启用 Basic Auth：

```bash
docker run -d -p 3080:3080 \
  -e PROXY_USERNAME=admin \
  -e PROXY_PASSWORD=changeme \
  -e DEEPSEEK_API_KEY=sk-xxx \
  <image-name>
```

密码以 bcrypt 哈希存储（`caddy hash-password`）。

## 镜像仓库

- Docker Hub: `docker.io/<你的用户名>/deepseek-harness`
- GHCR: `ghcr.io/<你的 GitHub 用户名>/deepseek-harness`

## GitHub Actions 自动构建

工作流触发条件：
- **Push** 到 `main`/`master` 且修改了 Docker 相关文件
- **每日 00:00 UTC** — 自动拉取最新 DSH 版本重建
- **手动触发** — 可指定 DSH 版本

### 发布到 GitHub 的步骤

```bash
# 1. 在 GitHub 创建新仓库（不要初始化 README/.gitignore）

# 2. 本地初始化并推送
cd /root/a
git init
git add .
git commit -m "feat: DeepSeek Harness Docker with Caddy reverse proxy"

# 3. 关联远程仓库（替换成你的用户名和仓库名）
git remote add origin https://github.com/<你的用户名>/deepseek-harness-docker.git
git branch -M main
git push -u origin main
```

### 配置 Secrets

推送后，在 GitHub 仓库 **Settings → Secrets and variables → Actions** 添加：

| Secret | 值 |
|--------|-----|
| `DOCKERHUB_USERNAME` | Docker Hub 用户名 |
| `DOCKERHUB_TOKEN` | Docker Hub Access Token（Settings → Security → New Access Token） |

GHCR 使用自动注入的 `GITHUB_TOKEN`，无需额外配置。

配置完成后，工作流会自动构建并推送镜像到两个仓库。

## 参考

- https://1ms.run/r/moelin/deepseek-harness
- https://1ms.run/r/smanx/deepseek-harness
