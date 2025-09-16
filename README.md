# DzzOfficr Docker镜像

当前镜像基于PHP8.1、nginx、mariadb10.7构建。

## 1. 快速启动

```bash
docker run -d -p 80:80 xiaohu2023/dzzoffice
```

## 2. 实现数据持久化——创建数据目录并在启动时挂载

```bash
mkdir /data
docker run -d -p 80:80 -v /data:/var/www/html xiaohu2023/dzzoffice
```

## 3. 以https方式启动

- 使用已有ssl证书
  - 证书格式必须是 `fullchain.pem`  `privkey.pem`
  
    ```bash
    docker run -d -p 443:443  -v "你的证书目录":/etc/nginx/ssl --name dzzoffice xiaohu2023/dzzoffice
    ```

## 4. [使用docker-compose同时部署数据库（推荐）](https://github.com/zyx0814/dzzoffice-docker)

```bash
git clone https://github.com/zyx0814/dzzoffice-docker.git
cd ./dzzoffice-docker/compose/
#需在db.env中设置数据库密码，还有yaml中的MYSQL_ROOT_PASSWORD
docker-compose up -d
注:安装时数据库地址可以使用db
```

```yaml
version: "3.5"

services:
  db:
    image: mariadb:10.7
    command: --transaction-isolation=READ-COMMITTED
    volumes:
      - "./db:/var/lib/mysql" #./db是数据库持久化目录，可以修改
    restart: always
    environment:
      - MYSQL_ROOT_PASSWORD=dzzoffice
      - MARIADB_AUTO_UPGRADE=1
      - MARIADB_DISABLE_UPGRADE_BACKUP=1
    env_file:
      - db.env
  dzzoffice:
    image: xiaohu2023/dzzoffice
    ports:
      - "8080:80" #左边8080是映射的主机端口，可以修改。右边80是容器端口
    volumes:
      - "./site:/var/www/html" #./site是站点目录位置,，可以修改。映射整个项目目录到容器的/var/www/html目录下
    restart: always
    links:
      - db
    environment:
      - MYSQL_HOST=db
    env_file:
      - db.env
    depends_on:
      - db
```
