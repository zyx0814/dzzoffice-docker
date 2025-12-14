FROM php:8.1-fpm-alpine3.16

# RUN sed -i 's/dl-cdn.alpinelinux.org/mirrors.aliyun.com/g' /etc/apk/repositories

# entrypoint.sh and dependencies
RUN set -ex; \
    addgroup -g 101 -S nginx && \
    adduser  -S -D -H -u 101 -h /var/cache/nginx -s /sbin/nologin -G nginx nginx && \
    \
    apk update && apk upgrade &&\
    apk add --no-cache \
        bash \
        rsync \
        supervisor \
        imagemagick \
        ffmpeg \
        ffmpeg-libs \
        tzdata \
        unzip \
        nginx \
        coreutils \
        # forward request and error logs to docker log collector
        && ln -sf /dev/stdout /var/log/nginx/access.log \
        && ln -sf /dev/stderr /var/log/nginx/error.log \
        && mkdir -p /run/nginx \
        && mkdir -p /var/log/supervisor && \
	cp /usr/share/zoneinfo/Asia/Shanghai /etc/localtime && \
	echo "Asia/Shanghai" > /etc/timezone

ADD conf/supervisord.conf /etc/supervisord.conf

# Copy our nginx config
RUN rm -Rf /etc/nginx/nginx.conf
ADD conf/nginx.conf /etc/nginx/nginx.conf

# nginx site conf
RUN mkdir -p /etc/nginx/sites-available/; \
    mkdir -p /etc/nginx/sites-enabled/; \
    mkdir -p /etc/nginx/ssl/; \
    mkdir /var/www/html/; \
    mkdir -p /docker-entrypoint-hooks.d/pre-installation \
             /docker-entrypoint-hooks.d/post-installation \
             /docker-entrypoint-hooks.d/pre-upgrade \
             /docker-entrypoint-hooks.d/post-upgrade \
             /docker-entrypoint-hooks.d/before-starting; \
    chown -R nginx:root /var/www; \
    chmod -R g=u /var/www

ADD conf/private-ssl.conf /etc/nginx/sites-available/private-ssl.conf

# install the PHP extensions we need
RUN set -ex; \
    \
    apk add --no-cache --virtual .build-deps \
        $PHPIZE_DEPS \
        autoconf \
        freetype-dev \
        icu-dev \
        libevent-dev \
        libjpeg-turbo-dev \
        libpng-dev \
        libxml2-dev \
        libzip-dev \
        openldap-dev \
        pcre-dev \
        libwebp-dev \
        bzip2-dev \
        gettext-dev \
        libressl-dev \
        curl-dev \
        imagemagick-dev \
        tidyhtml-dev \
    ; \
    \
    docker-php-ext-configure gd --with-freetype --with-jpeg --with-webp; \
    docker-php-ext-configure intl; \
    docker-php-ext-configure ldap; \
    docker-php-ext-install -j "$(nproc)" \
        bcmath \
        exif \
        ftp \
        gd \
        intl \
        ldap \
        opcache \
        pcntl \
        pdo_mysql \
        mysqli \
        zip \
        bz2 \
        gettext \
        sockets \
        tidy \
    ; \
    \
# pecl will claim success even if one install fails, so we need to perform each install separately
    pecl install redis; \
    pecl install imagick; \
    \
    docker-php-ext-enable \
        imagick \
        redis \
    ; \
    rm -r /tmp/pear; \    
    \
    runDeps="$( \
        scanelf --needed --nobanner --format '%n#p' --recursive /usr/local/lib/php/extensions \
            | tr ',' '\n' \
            | sort -u \
            | awk 'system("[ -e /usr/local/lib/" $1 " ]") == 0 { next } { print "so:" $1 }' \
    )"; \
    apk add --no-network --virtual .dzzoffice-phpext-rundeps $runDeps; \
    apk del --no-network .build-deps

# tweak php-fpm config
ENV fpm_conf=/usr/local/etc/php-fpm.d/www.conf
ENV php_vars=/usr/local/etc/php/conf.d/docker-vars.ini
RUN { \
        echo 'opcache.enable=1'; \
        echo 'opcache.interned_strings_buffer=32'; \
        echo 'opcache.max_accelerated_files=10000'; \
        echo 'opcache.memory_consumption=128'; \
        echo 'opcache.save_comments=1'; \
        echo 'opcache.revalidate_freq=60'; \
        echo 'opcache.jit=1255'; \
        echo 'opcache.jit_buffer_size=128M'; \
    } > "${PHP_INI_DIR}/conf.d/opcache-recommended.ini"; \
    \
    echo "cgi.fix_pathinfo=1" > ${php_vars} &&\
    echo "upload_max_filesize = 512M"  >> ${php_vars} &&\
    echo "post_max_size = 512M"  >> ${php_vars} &&\
    echo "memory_limit = 512M"  >> ${php_vars} && \
    echo "max_execution_time = 3600"  >> ${php_vars} && \
    echo "max_input_time = 3600"  >> ${php_vars} && \
    sed -i \
        -e "s/;catch_workers_output\s*=\s*yes/catch_workers_output = yes/g" \
        -e "s/pm.max_children = */pm.max_children = 50/g" \
        -e "s/pm.start_servers = */pm.start_servers = 10/g" \
        -e "s/pm.min_spare_servers = */pm.min_spare_servers = 10/g" \
        -e "s/pm.max_spare_servers = */pm.max_spare_servers = 30/g" \
        -e "s/;pm.max_requests = 500/pm.max_requests = 500/g" \
        -e "s/user = www-data/user = nginx/g" \
        -e "s/group = www-data/group = nginx/g" \
        -e "s/;listen.mode = 0660/listen.mode = 0666/g" \
        -e "s/;listen.owner = www-data/listen.owner = nginx/g" \
        -e "s/;listen.group = www-data/listen.group = nginx/g" \
        -e "s/listen = 127.0.0.1:9000/listen = \/var\/run\/php-fpm.sock/g" \
        -e "s/^;clear_env = no$/clear_env = no/" \
        ${fpm_conf}

VOLUME /var/www/html

RUN set -ex; \
    echo "Downloading DzzOffice source code during build..."; \
    mkdir -p /usr/src; \
    curl -fsSL -o /usr/src/dzzoffice.zip "https://codeload.github.com/zyx0814/dzzoffice/zip/refs/heads/master"; \
    unzip /usr/src/dzzoffice.zip -d /usr/src; \
    mv /usr/src/dzzoffice-master /usr/src/dzzoffice; \
    rm /usr/src/dzzoffice.zip; \
    echo "DzzOffice source code downloaded and extracted successfully!"

EXPOSE 80 443

COPY entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh
ENTRYPOINT ["/entrypoint.sh"]
CMD ["supervisord","-n","-c","/etc/supervisord.conf"]
