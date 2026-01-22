基于 **PHP8.1、Nginx、MariaDB** 镜像，详细介绍 DzzOffice 的 Docker 部署方式（含快速启动、持久化配置、HTTPS 部署及 Docker Compose 推荐方案），并提供数据运维与数据库连接说明。

### 版本与升级说明
- DzzOffice Docker镜像仅用于部署，无固定版本标签（始终为最新部署包），应用更新与镜像无关；
- 数据持久化的用户升级DzzOffice：后台「系统工具」在线升级，或下载源码覆盖挂载目录离线升级。

## 一、部署前提
- 服务器需安装 Docker 20.10+、Docker Compose v2+；
- 在线环境（默认）：直接部署，自动拉取镜像；
- 离线环境：需先导入镜像（见下文），再执行部署。

## 二、离线环境镜像导入（仅离线服务器需做）
1. 联网设备拉取并导出镜像：
```bash
# 拉取核心镜像
docker pull xiaohu2023/dzzoffice
docker pull redis:alpine
docker pull mariadb:lts

# 导出镜像为 tar 包（便于离线传输）
docker save -o dzzoffice.tar xiaohu2023/dzzoffice
docker save -o redis.tar redis:alpine
docker save -o mariadb.tar mariadb:lts
```
> 现成离线包：https://pan.baidu.com/s/110mmXIOMv-Gt_Vcja0nJbw?pwd=xiao

2. 传输 tar 包到离线服务器并进入 tar 包所在目录，执行导入：
```bash
docker load -i dzzoffice.tar
docker load -i redis.tar
docker load -i mariadb.tar
```
导入完成后，执行 `docker images` 命令验证，若能看到 `xiaohu2023/dzzoffice`、`redis:alpine`、`mariadb:lts` 3 个镜像，则导入成功。

## 二、部署方式
### 方式1：快速启动
默认使用 80 端口，**容器删除后数据会丢失**，仅推荐临时测试使用。
```bash
docker run -d -p 80:80 xiaohu2023/dzzoffice
```

### 方式2：实现数据持久化
创建数据目录并在启动时挂载
```bash
mkdir /data
ocker run -d -p 80:80 -v /data:/var/www/html xiaohu2023/dzzoffice
```

### 方式3：以HTTPS方式启动
若需通过 HTTPS 访问，需提前准备 SSL 证书（格式必须为 `fullchain.pem` 、 `privkey.pem`）
```bash
docker run -d -p 443:443 -v "你的证书目录":/etc/nginx/ssl --name dzzoffice xiaohu2023/dzzoffice
```

### 方式4：Docker Compose 部署（推荐）
通过 Docker Compose 同时部署 DzzOffice 应用和 MariaDB 数据库，实现应用、数据库数据双重持久化，且配置更灵活，推荐生产环境使用。

#### 步骤1：拉取部署脚本
```bash
git clone https://github.com/zyx0814/dzzoffice-docker.git
cd ./dzzoffice-docker/compose/
```
> 若无法拉取，可以自行新建`db.env`文件来设置数据库环境变量并创建`docker-compose.yml`文件, 在其中配置映射端口、持久化目录等

```env
MYSQL_PASSWORD=dzzoffice
MYSQL_DATABASE=dzzoffice
MYSQL_USER=dzzoffice
```

```yaml
version: '3.5'

services:
  db:
    image: mariadb:lts
    command: --transaction-isolation=READ-COMMITTED
    restart: always
    volumes:
      - "./db:/var/lib/mysql" #./db是数据库持久化目录，可以修改
    environment:
      - MYSQL_ROOT_PASSWORD=dzzoffice
      - MARIADB_AUTO_UPGRADE=1
      - MARIADB_DISABLE_UPGRADE_BACKUP=1
    env_file:
      - db.env
      
  app:
    image: xiaohu2023/dzzoffice
    restart: always
    ports:
      - "8080:80" #左边8080是映射的主机端口，可以修改。右边80是容器端口
    volumes:
      - "./site:/var/www/html" #./site是站点目录位置,，可以修改。映射整个项目目录到容器的/var/www/html目录下
    environment:
      - MYSQL_HOST=db
      - REDIS_HOST=redis
    env_file:
      - db.env
    depends_on:
      - db
      - redis

  redis:
    image: redis:alpine
    restart: always
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
关键数据已通过挂载宿主机目录实现持久化，目录对应关系如下：
| 宿主机目录       | 容器内目录               | 存储内容                     |
|------------------|--------------------------|------------------------------|
| `./db`        | MySQL 数据目录           | MySQL 所有数据（含 DzzOffice 数据库） |
| `./site/data`         | DzzOffice 数据目录       | 用户上传的文件                |
| `./site/config`       | DzzOffice 配置目录       | 应用配置文件                  |
| `./site`         | DzzOffice 项目目录       | 应用程序所有文件              |

### 2. 运维操作指南
| 操作场景               | 命令/方法                                  | 数据影响                     |
|------------------------|-------------------------------------------|------------------------------|
| 正常重启服务           | `docker-compose restart`                   | 数据完全保留                 |
| 彻底停止后重新启动     | `docker-compose down` → `docker-compose up -d` | 数据保留（依赖宿主机挂载目录） |
| 查看服务状态           | `docker-compose ps`                       | -                            |

### 3. 注意事项
- 不要手动修改 ./db 下的文件，应通过 SQL 命令操作数据库；
- 建议定期备份宿主机上的 `./db`、`./site` 目录，避免数据丢失。

## 四、数据库地址填写规则（初始化配置用）
初始化 DzzOffice 时，需根据数据库部署位置填写正确的“数据库地址”，规则如下：

| 数据库部署位置               | 数据库地址填写内容                          | 说明                                  |
|------------------------------|-------------------------------------------|---------------------------------------|
| 容器内 MySQL（Docker Compose 部署） | `db`                                      | Docker 内部可通过容器名“db”解析通信    |
| 宿主机 MySQL（服务器本地数据库）   | `host.docker.internal`                    | Docker 提供的宿主机映射地址，支持 Windows、Mac 及部分 Linux 环境 |
| 外部 MySQL（其他服务器数据库）     | `数据库IP:端口`（如 `192.168.1.100:3306`） | 需确保数据库服务器允许当前服务器访问    |

## 五、环境变量说明

DzzOffice 容器支持通过环境变量自动初始化信息。

**MYSQL/MariaDB**:

- `MYSQL_DATABASE` 数据库名.
- `MYSQL_USER` 数据库用户.
- `MYSQL_PASSWORD` 数据库用户密码.
- `MYSQL_HOST` 数据库服务地址.

**redis**:

- `REDIS_HOST` redis地址.
- `REDIS_PASSWORD` redis密码.

**uid/gid**:

- `PUID`代表站点运行用户nginx的用户uid
- `PGID`代表站点运行用户nginx的用户组gid

**PHP参数**

- `FPM_MAX` php-fpm最大进程数, 默认50
- `FPM_START` php-fpm初始进程数, 默认10
- `FPM_MIN_SPARE` php-fpm最小空闲进程数, 默认10
- `FPM_MAX_SPARE` php-fpm最大空闲进程数, 默认30
