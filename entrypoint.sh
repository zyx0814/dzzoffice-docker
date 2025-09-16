#!/bin/sh

set -e

directory_empty() {
    [ -z "$(ls -A "$1/")" ]
}
fix_permissions() {
    echo "Fixing permissions for www-data..."
    # 确保 www-data 用户存在
    if ! id -u www-data >/dev/null 2>&1; then
        adduser -D -H -u 82 -G www-data www-data
    fi
    
    # 设置所有权和权限
    chown -R www-data:www-data /var/www/html
    find /var/www/html -type d -exec chmod 775 {} \;
    find /var/www/html -type f -exec chmod 664 {} \;
    
    # 确保 data 目录有写权限
    mkdir -p /var/www/html/data
    chown www-data:www-data /var/www/html/data
    chmod 775 /var/www/html/data
    
    echo "Permissions fixed for www-data"
}
if  directory_empty "/var/www/html"; then
        if [ "$(id -u)" = 0 ]; then
            rsync_options="-rlDog --chown www-data:www-data"
        else
            rsync_options="-rlD"
        fi
        echo "DzzOffice is downloading ..."
        apk add --no-cache --virtual .fetch-deps gnupg
        curl -fsSL -o dzzoffice.zip "https://codeload.github.com/zyx0814/dzzoffice/zip/refs/heads/master"
        export GNUPGHOME="$(mktemp -d)"
        unzip dzzoffice.zip -d /usr/src/
        gpgconf --kill all
        rm dzzoffice.zip
        rm -rf "$GNUPGHOME"
        apk del .fetch-deps
        echo "DzzOffice is installing ..."
        rsync $rsync_options --delete /usr/src/dzzoffice-master/ /var/www/html/
else
        echo "DzzOffice has been configured!"
        fix_permissions
fi
if [ -f /etc/nginx/ssl/fullchain.pem ] && [ -f /etc/nginx/ssl/privkey.pem ] && [ ! -f /etc/nginx/sites-enabled/*-ssl.conf ] ; then
        ln -s /etc/nginx/sites-available/private-ssl.conf /etc/nginx/sites-enabled/
        sed -i "s/#return 301/return 301/g" /etc/nginx/sites-available/default.conf
fi

exec "$@"
