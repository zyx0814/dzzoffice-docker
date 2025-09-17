DzzOffice 官网：https://www.dzzoffice.com/

DzzOffice 是一款开源办公套件，旨在为企业和团队提供类似于“Google 企业应用套件”和“微软 Office365”的协同办公平台。它由多款开源办公应用组成，用户可根据需求选择和安装，实现高度灵活和可定制的使用体验。

当前基于 **PHP8.1、Nginx、MariaDB** 镜像，详细介绍 DzzOffice 的 Docker 部署方式（含快速启动、持久化配置、HTTPS 部署及 Docker Compose 推荐方案），并提供数据运维与数据库连接说明。

## 一、部署前提
服务器需已安装以下环境，版本需满足要求：
- Docker：20.10 及以上
- Docker Compose：v2 及以上

## 二、部署方式（4种可选）
### 方式1：快速启动（适用于测试，无数据持久化）
直接拉取镜像并启动容器，默认使用 80 端口，**容器删除后数据会丢失**，仅推荐临时测试使用。
```bash
docker run -d -p 80:80 xiaohu2023/dzzoffice
```
启动后通过 `http://服务器IP` 访问。

### 方式2：基础数据持久化（挂载宿主机目录）
通过挂载宿主机目录 `/data` 到容器内 `/var/www/html`，实现应用数据持久化（容器删除后数据保留在宿主机 `/data` 中）。
1. 先在宿主机创建数据目录：
   ```bash
   mkdir /data
   ```
2. 启动容器并挂载目录：
   ```bash
   docker run -d -p 80:80 -v /data:/var/www/html xiaohu2023/dzzoffice
   ```
启动后通过 `http://服务器IP` 访问，数据会自动存储到宿主机 `/data` 目录。


### 方式3：HTTPS 方式启动（使用已有 SSL 证书）
若需通过 HTTPS 访问，需提前准备 SSL 证书（格式必须为 `fullchain.pem` 和 `privkey.pem`），并通过挂载证书目录到容器实现配置。
1. 替换命令中的 **“你的证书目录”** 为宿主机存放证书的实际路径（如 `/home/ssl`）；
2. 执行启动命令（默认使用 443 端口，可按需修改）：
   ```bash
   docker run -d -p 443:443 -v "你的证书目录":/etc/nginx/ssl --name dzzoffice xiaohu2023/dzzoffice
   ```
启动后通过 `https://服务器IP` 或 `https://你的域名` 访问。

### 方式4：Docker Compose 部署（推荐，含独立数据库）
通过 Docker Compose 同时部署 DzzOffice 应用和 MariaDB 数据库，实现应用、数据库数据双重持久化，且配置更灵活，推荐生产环境使用。

#### 步骤1：拉取部署脚本
```bash
git clone https://github.com/zyx0814/dzzoffice-docker.git
cd ./dzzoffice-docker/compose/
```

#### 步骤2：自定义配置（可选）
根据需求修改以下文件，默认配置可直接跳过：
- **数据库密码**：编辑 `docker-compose.yml`，修改 `MYSQL_ROOT_PASSWORD=dzzoffice` 中的“dzzoffice”为自定义密码；
- **端口**：编辑 `docker-compose.yml`，修改 `ports` 字段（默认站点端口 8080）；
- **数据库信息**：编辑 `db.env`，修改数据库名称、用户名及密码。

#### 步骤3：启动服务
```bash
docker-compose up -d
```
命令执行后，会自动拉取所需容器并后台运行。

#### 步骤4：访问与初始化
容器启动完成后，通过 `http://服务器IP:8080` 访问（端口可在 `docker-compose.yml` 中修改），按页面提示完成 DzzOffice 初始化设置。

## 三、数据持久化说明
### 1. 持久化目录结构（Docker Compose 部署）
关键数据通过挂载宿主机目录实现持久化，目录对应关系如下：
| 宿主机目录       | 容器内目录               | 存储内容                     |
|------------------|--------------------------|------------------------------|
| `./mysql`        | MySQL 数据目录           | MySQL 所有数据（含 DzzOffice 数据库） |
| `./data`         | DzzOffice 数据目录       | 用户上传的文件                |
| `./config`       | DzzOffice 配置目录       | 应用配置文件                  |
| `./site`         | DzzOffice 项目目录       | 应用程序所有文件              |

### 2. 运维操作指南
| 操作场景               | 命令/方法                                  | 数据影响                     |
|------------------------|-------------------------------------------|------------------------------|
| 正常重启服务           | `docker-compose restart`                   | 数据完全保留                 |
| 彻底停止后重新启动     | `docker-compose down` → `docker-compose up -d` | 数据保留（依赖宿主机挂载目录） |
| 查看服务状态           | `docker-compose ps`                       | -                            |

### 3. 注意事项
- 不要手动修改 ./mysql 下的文件，应通过 SQL 命令操作数据库；
- 建议定期备份宿主机上的 `./mysql`、`./data`、`./config` 目录，避免数据丢失。


## 四、数据库地址填写规则（初始化配置用）
初始化 DzzOffice 时，需根据数据库部署位置填写正确的“数据库地址”，规则如下：

| 数据库部署位置               | 数据库地址填写内容                          | 说明                                  |
|------------------------------|-------------------------------------------|---------------------------------------|
| 容器内 MySQL（Docker Compose 部署） | `db`                                      | Docker 内部可通过容器名“db”解析通信    |
| 宿主机 MySQL（服务器本地数据库）   | `host.docker.internal`                    | Docker 提供的宿主机映射地址，支持 Windows、Mac 及部分 Linux 环境 |
| 外部 MySQL（其他服务器数据库）     | `数据库IP:端口`（如 `192.168.1.100:3306`） | 需确保数据库服务器允许当前服务器访问    |
