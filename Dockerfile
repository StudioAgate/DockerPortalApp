FROM php:7.3-fpm

LABEL maintainer="pierstoval@gmail.com"

ENV COMPOSER_ALLOW_SUPERUSER=1 \
    DOCKER_COMPOSE_VERSION=1.24.0 \
    BLACKFIRE_CONFIG=/dev/null \
    BLACKFIRE_LOG_LEVEL=1 \
    GOSU_VERSION=1.11 \
    BLACKFIRE_SOCKET=tcp://0.0.0.0:8707 \
    PANTHER_NO_SANDBOX=1

COPY bin/entrypoint.bash /bin/entrypoint
COPY etc/php.ini /usr/local/etc/php/conf.d/99-custom.ini
COPY --from=composer /usr/bin/composer /usr/local/bin/composer
COPY --from=blackfire/blackfire /usr/bin/blackfire* /usr/local/bin/

RUN apt-get update \
    && apt-get upgrade -y \
    && export build_libs="libfreetype6-dev libjpeg62-turbo-dev libpng-dev zlib1g-dev libgs-dev libicu-dev libmcrypt-dev libzip-dev" \
    && export persistent_libs="libfreetype6 libjpeg62-turbo libpng16-16 libicu57 libmcrypt4 libzip4 zlib1g" \
    && apt-get install -y --no-install-recommends \
        ca-certificates \
        curl \
        git \
        openssh-client \
        unzip \
        $build_libs \
        $persistent_libs \
    \
    && `# Blackfire` \
    && version=$(php -r "echo PHP_MAJOR_VERSION.PHP_MINOR_VERSION;") \
    && curl -A "Docker" -o /tmp/blackfire-probe.tar.gz -D - -L -s https://blackfire.io/api/v1/releases/probe/php/linux/amd64/$version \
    && mkdir -p /tmp/blackfire \
    && tar zxpf /tmp/blackfire-probe.tar.gz -C /tmp/blackfire \
    && mv /tmp/blackfire/blackfire-*.so $(php -r "echo ini_get('extension_dir');")/blackfire.so \
    && printf "extension=blackfire.so\nblackfire.agent_socket=tcp://blackfire:8707\n" > $PHP_INI_DIR/conf.d/blackfire.ini \
    && rm -rf /tmp/blackfire /tmp/blackfire-probe.tar.gz \
    \
    && `# PHP extensions` \
    && docker-php-ext-configure gd \
        --with-freetype-dir=/usr/include/ \
        --with-jpeg-dir=/usr/include/ \
        --with-png-dir=/usr/include/ \
    && docker-php-ext-install -j$(nproc) gd \
    && docker-php-ext-configure pdo_mysql \
    && docker-php-ext-configure zip \
    && docker-php-ext-install opcache intl pdo_mysql zip \
    && (echo '' | pecl install apcu) \
    && docker-php-ext-enable apcu \
    && (echo '' | pecl install xdebug) \
    \
    && `# ImageMagick` \
    && curl -L "https://imagemagick.org/download/ImageMagick.tar.gz" | tar xz \
    && cd ImageMagick-* \
    && ./configure \
    && make \
    && make install \
    && ldconfig /usr/local/lib \
    && cd .. \
    \
    && `# Composer` \
    && curl -sS https://getcomposer.org/installer | php -- --install-dir=/usr/local/bin --filename=composer \
    && composer global require --prefer-dist symfony/flex \
    \
    && `# Symfony CLI` \
    && SYMFONYCLI_VERSION=`curl -sS https://get.symfony.com/cli/LATEST` \
    && [[ "i386" = `uname -m` ]] && SYMFONYCLI_MACHINE="386" || SYMFONYCLI_MACHINE="amd64" \
    && curl -sS https://get.symfony.com/cli/v$SYMFONYCLI_VERSION/symfony_linux_$SYMFONYCLI_MACHINE > /usr/local/bin/symfony.gz \
    && gzip -d /usr/local/bin/symfony.gz \
    && chmod +x /usr/local/bin/symfony \
    \
    && `# User management for entrypoint` \
    && curl -L -s -o /bin/gosu https://github.com/tianon/gosu/releases/download/${GOSU_VERSION}/gosu-$(dpkg --print-architecture | awk -F- '{ print $NF }') \
    && chmod +x /bin/gosu \
    && groupadd foo \
    && adduser --home=/home --shell=/bin/bash --ingroup=foo --disabled-password --quiet --gecos "" foo \
    \
    && `# Clean apt and remove unused libs/packages to make image smaller` \
    && apt-get purge -y --auto-remove -o APT::AutoRemove::RecommendsImportant=false -o APT::AutoRemove::SuggestsImportant=false \
        libstdc++-6-dev libc6-dev cpp-6 gcc-6 g++-6 tzdata rsync \
        $build_libs \
    && apt-get -y autoremove \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/* /var/www/* /var/cache/*

WORKDIR /srv

ENTRYPOINT ['/bin/entrypoint']

CMD ['symfony', 'serve', '--dir=/srv', '--allow-http', '--no-tls', '--port=8000']

EXPOSE 8000
