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
docker-compose up -d
```
- 默认root密码：`dzzoffice`;可以修改`docker-compose.yaml`，设置数据库root密码（MYSQL_ROOT_PASSWORD=root密码）
- 默认数据库端口3306；站点端口8080；根据需要修改`docker-compose.yaml`中的`ports`
- 打开`db.env`文件修改数据库名称，用户和密码
- **注：同时部署数据库时，数据库地址可以使用数据库容器名(db)**
