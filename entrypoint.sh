#!/bin/sh

set -eu

# return true if specified directory is empty
directory_empty() {
    [ -z "$(ls -A "$1/")" ]
}
fix_permissions() {
    # 设置所有权和权限
    chown -R nginx:nginx /var/www/html
    find /var/www/html -type d -exec chmod 775 {} \;
    find /var/www/html -type f -exec chmod 664 {} \;
    
    # 确保 data 目录有写权限
    mkdir -p /var/www/html/data
    chown nginx:nginx /var/www/html/data
    chmod 775 /var/www/html/data
    
    echo "Permissions fixed for nginx user"
}

if [ -n "${PUID+x}" ]; then
    if [ ! -n "${PGID+x}" ]; then
        PGID=${PUID}
        echo "Adjusting nginx user UID/GID to $PUID/$PGID..."
    fi
    deluser nginx
    addgroup -g ${PGID} nginx
    adduser -D -S -h /var/cache/nginx -s /sbin/nologin -G nginx -u ${PUID} nginx
    chown -R nginx:nginx /var/lib/nginx/
fi

if [ -n "${FPM_MAX+x}" ] && [ -n "${FPM_START+x}" ] && [ -n "${FPM_MIN_SPARE+x}" ] && [ -n "${FPM_MAX_SPARE+x}" ]; then
    echo "Updating PHP-FPM pool config..."
    sed -i "s/pm.max_children = .*/pm.max_children = ${FPM_MAX}/g" /usr/local/etc/php-fpm.d/www.conf
    sed -i "s/pm.start_servers = .*/pm.start_servers = ${FPM_START}/g" /usr/local/etc/php-fpm.d/www.conf
    sed -i "s/pm.min_spare_servers = .*/pm.min_spare_servers = ${FPM_MIN_SPARE}/g" /usr/local/etc/php-fpm.d/www.conf
    sed -i "s/pm.max_spare_servers = .*/pm.max_spare_servers = ${FPM_MAX_SPARE}/g" /usr/local/etc/php-fpm.d/www.conf
    echo "PHP-FPM config updated"
fi

if  directory_empty "/var/www/html"; then
    echo "Installing DzzOffice from pre-downloaded source..."
    if [ "$(id -u)" = 0 ]; then
        rsync_options="-rlDog --chown nginx:nginx"
    else
        rsync_options="-rlD"
    fi

    if rsync $rsync_options --delete /usr/src/dzzoffice/ /var/www/html/; then
        echo "DzzOffice installed successfully!"
    else
        echo "Error: Failed to sync DzzOffice source code!" >&2
        exit 1
    fi
else
    echo "DzzOffice has been configured!"
fi

fix_permissions

if [ -f /etc/nginx/ssl/fullchain.pem ] && [ -f /etc/nginx/ssl/privkey.pem ] && [ ! -f /etc/nginx/sites-enabled/*-ssl.conf ] ; then
    echo "SSL is enabled!"
    ln -s /etc/nginx/sites-available/private-ssl.conf /etc/nginx/sites-enabled/
    sed -i "s/#return 301/return 301/g" /etc/nginx/nginx.conf
fi

echo "Starting DzzOffice services..."
exec "$@"
