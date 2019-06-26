FROM php:7.3-fpm

LABEL maintainer="pierstoval@gmail.com"

ENV COMPOSER_ALLOW_SUPERUSER=1 \
    DOCKER_COMPOSE_VERSION=1.24.1 \
    BLACKFIRE_CONFIG=/dev/null \
    BLACKFIRE_LOG_LEVEL=1 \
    GOSU_VERSION=1.11 \
    BLACKFIRE_SOCKET=tcp://0.0.0.0:8707 \
    PANTHER_NO_SANDBOX=1 \
    IMAGEMAGICK_VERSION=7.0.8-50 \
    TOOLBOX_TARGET_DIR="/tools" \
    TOOLBOX_VERSION="1.6.6" \
    PATH="$PATH:$TOOLBOX_TARGET_DIR:$TOOLBOX_TARGET_DIR/.composer/vendor/bin:/tools/QualityAnalyzer/bin:$TOOLBOX_TARGET_DIR/DesignPatternDetector/bin:$TOOLBOX_TARGET_DIR/EasyCodingStandard/bin"

COPY bin/entrypoint.sh /bin/entrypoint
COPY etc/php.ini /usr/local/etc/php/conf.d/99-custom.ini
COPY --from=composer /usr/bin/composer /usr/local/bin/composer
COPY --from=blackfire/blackfire /usr/bin/blackfire* /usr/local/bin/

RUN set -xe \
    && apt-get update \
    && apt-get upgrade -y \
    && `# Libs that are already installed or needed, and that will be removed at the end` \
    && export BUILD_LIBS=" \
        autoconf \
        file \
        g++ \
        gcc \
        libc-dev \
        libfreetype6-dev \
        libgs-dev \
        libicu-dev \
        libjpeg62-turbo-dev \
        libmcrypt-dev \
        libpng-dev \
        libstdc++-6-dev libc6-dev cpp-6 gcc-6 g++-6 tzdata rsync \
        libzip-dev \
        pkg-config \
        re2c \
        zlib1g-dev \
    " \
    && `# Mostly ImageMagick necessary libs, and some for PHP (zip, etc.)` \
    && export persistent_libs="libfreetype6 libjpeg62-turbo libpng16-16 libicu57 libmcrypt4 libzip4 zlib1g libjbig0 liblcms2-2 libtiff5 libfontconfig1 libopenjp2-7 libgomp1" \
    \
    && apt-get install -y --no-install-recommends \
        ca-certificates \
        make \
        curl \
        git \
        graphviz \
        openssh-client \
        unzip \
        chromium \
        $BUILD_LIBS \
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
    && (echo '' | pecl install pcov) \
    && docker-php-ext-enable apcu \
    && (echo '' | pecl install xdebug) \
    \
    && `# Jakzal/toolbox` \
    && git clone https://github.com/nikic/php-ast.git && cd php-ast && phpize && ./configure && make && make install && cd .. && rm -rf php-ast && docker-php-ext-enable ast \
    && docker-php-ext-install zip pcntl \
    && mkdir -p $TOOLBOX_TARGET_DIR && curl -Ls https://github.com/jakzal/toolbox/releases/download/v$TOOLBOX_VERSION/toolbox.phar -o $TOOLBOX_TARGET_DIR/toolbox && chmod +x $TOOLBOX_TARGET_DIR/toolbox \
    && php $TOOLBOX_TARGET_DIR/toolbox install \
    \
    && `# ImageMagick` \
    && curl -L "https://github.com/ImageMagick/ImageMagick/archive/${IMAGEMAGICK_VERSION}.tar.gz" | tar xz \
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
    && echo "Symfony CLI version: ${SYMFONYCLI_VERSION}" \
    && [[ "i386" = `uname -m` ]] && SYMFONYCLI_MACHINE="386" || SYMFONYCLI_MACHINE="amd64" \
    && echo "Symfony CLI architecture: ${SYMFONYCLI_MACHINE}" \
    && curl -sS "https://get.symfony.com/cli/v${SYMFONYCLI_VERSION}/symfony_linux_${SYMFONYCLI_MACHINE}" -o /usr/local/bin/symfony.gz \
    && gzip -d /usr/local/bin/symfony.gz \
    && chmod +x /usr/local/bin/symfony \
    \
    && `# User management for entrypoint` \
    && curl -L -s -o /bin/gosu https://github.com/tianon/gosu/releases/download/${GOSU_VERSION}/gosu-$(dpkg --print-architecture | awk -F- '{ print $NF }') \
    && chmod +x /bin/gosu \
    && groupadd _www \
    && adduser --home=/home --shell=/bin/bash --ingroup=_www --disabled-password --quiet --gecos "" --force-badname _www \
    \
    && `# Clean apt and remove unused libs/packages to make image smaller` \
    && apt-get purge -y --auto-remove -o APT::AutoRemove::RecommendsImportant=false -o APT::AutoRemove::SuggestsImportant=false $BUILD_LIBS \
    && apt-get -y autoremove \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/* /var/www/* /var/cache/*

WORKDIR /srv

ENTRYPOINT ["/bin/entrypoint"]

CMD ["symfony", "serve", "--dir=/srv", "--allow-http", "--no-tls", "--port=8000"]

EXPOSE 8000
