FROM php:7.3-fpm

LABEL maintainer="pierstoval@gmail.com"

ENV COMPOSER_ALLOW_SUPERUSER=1 \
    DOCKER_COMPOSE_VERSION=1.24.0 \
    BLACKFIRE_CONFIG=/dev/null \
    BLACKFIRE_LOG_LEVEL=1 \
    BLACKFIRE_SOCKET=tcp://0.0.0.0:8707 \
    PANTHER_NO_SANDBOX=1

COPY bin/entrypoint.sh /entrypoint
COPY etc/php.ini /usr/local/etc/php/conf.d/99-custom.ini
COPY --from=composer /usr/bin/composer /usr/local/bin/composer
COPY --from=blackfire/blackfire /usr/bin/blackfire* /usr/local/bin/

RUN chmod a+x /entrypoint \
    && apt-get update \
    && apt-get upgrade -y \
    && export build_deps="libfreetype6-dev libjpeg62-turbo-dev libpng-dev zlib1g-dev libgs-dev libicu-dev libmcrypt-dev libzip-dev" \
    && export persistent_deps="libfreetype6 libjpeg62-turbo libpng16-16 libicu57 libmcrypt4 libzip4 zlib1g" \
    && apt-get install -y --no-install-recommends \
        ca-certificates \
        curl \
        git \
        iptables \
        openssh-client \
        unzip \
        $build_deps \
        $persistent_deps \
    \
    && `# Docker` \
    && curl -sSL https://get.docker.com/ | sh \
    && which docker \
    && docker --version \
    \
    && `# Docker-compose` \
    && export DOCKER_COMPOSE_URL="https://github.com/docker/compose/releases/download/${DOCKER_COMPOSE_VERSION}/docker-compose-$(uname -s)-$(uname -m)" \
    && echo "Docker compose URL : ${DOCKER_COMPOSE_URL}" \
    && curl -L "${DOCKER_COMPOSE_URL}" -o /usr/local/bin/docker-compose \
    && chmod +x /usr/local/bin/docker-compose \
    && docker-compose --version \
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
    && `# Clean apt to make image smaller` \
    && apt-get purge -y --auto-remove -o APT::AutoRemove::RecommendsImportant=false -o APT::AutoRemove::SuggestsImportant=false \
        libstdc++-6-dev \
        git \
        libc6-dev \
        cpp-6 \
        gcc-6 \
        g++-6 \
        perl-modules-5.24 libperl5.24 \
        $build_deps \
    && apt-get -y autoremove \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/* /var/www/* /var/cache/*

WORKDIR /srv
