FROM php:7.3-fpm

LABEL maintainer="pierstoval@gmail.com"

ENV COMPOSER_ALLOW_SUPERUSER=1 \
    BLACKFIRE_CONFIG=/dev/null \
    BLACKFIRE_LOG_LEVEL=1 \
    GOSU_VERSION=1.11 \
    BLACKFIRE_SOCKET=tcp://0.0.0.0:8707 \
    PANTHER_NO_SANDBOX=1 \
    IMAGEMAGICK_VERSION=7.0.8-50 \
    SYMFONYCLI_VERSION="4.6.4"

ENV PATH="$PATH:/tools"
ENV PATH="$PATH:/tools/.composer/vendor/bin"
ENV PATH="$PATH:/tools/QualityAnalyzer/bin"
ENV PATH="$PATH:/tools/DesignPatternDetector/bin"
ENV PATH="$PATH:/tools/EasyCodingStandard/bin"
ENV PATH="$PATH:/tools/.composer/vendor-bin/symfony/vendor/bin/simple-phpunit"
ENV PATH="$PATH:/tools/.composer/vendor-bin/tools/vendor/bin/"

COPY bin/entrypoint.sh /bin/entrypoint
COPY etc/php.ini /usr/local/etc/php/conf.d/99-custom.ini
COPY --from=blackfire/blackfire /usr/local/bin/blackfire* /usr/local/bin/

RUN set -xe \
    && apt-get update \
    && apt-get upgrade -y \
    \
    && `# Libs that are already installed or needed, and that will be removed at the end` \
    && export BUILD_LIBS=" \
        `# php gd` libfreetype6-dev libjpeg-dev libjpeg62-turbo-dev libpng-dev \
        `# php intl` libicu-dev \
        git \
    " \
    \
    && `# Libs that may already be installed and we will remove to make the image lighter` \
    && export REMOVE_LIBS=" \
        autoconf file g++ gcc tzdata pkg-config re2c libperl* \
    " \
    \
    && `# Mostly ImageMagick necessary libs, and some for PHP (zip, etc.)` \
    && export PERSISTENT_LIBS=" \
        `# php zip` zlib1g-dev libzip-dev \
    " \
    \
    && apt-get install -y --no-install-recommends \
        ca-certificates \
        make \
        curl \
        graphviz \
        openssh-client \
        unzip \
        chromium \
        $BUILD_LIBS \
        $PERSISTENT_LIBS \
    \
    && `# PHP extensions` \
    && docker-php-ext-configure gd \
        --with-freetype-dir=/usr/include/ \
        --with-jpeg-dir=/usr/include/ \
        --with-png-dir=/usr/include/ \
    && docker-php-ext-install -j$(nproc) gd \
    && docker-php-ext-configure intl \
    && docker-php-ext-configure opcache \
    && docker-php-ext-configure pdo_mysql \
    && docker-php-ext-configure zip \
    && docker-php-ext-install intl \
    && docker-php-ext-install opcache \
    && docker-php-ext-install pdo_mysql \
    && docker-php-ext-install zip \
    && (echo '' | pecl install apcu) \
    && (echo '' | pecl install pcov) \
    && docker-php-ext-enable apcu \
    && (echo '' | pecl install xdebug) \
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
    && `# Composer` \
    && (curl -sS https://getcomposer.org/installer | php -- --install-dir=/usr/local/bin --filename=composer) \
    && composer global require --prefer-dist symfony/flex \
    \
    && `# Static analysis` \
    && composer global require phpstan/phpstan-shim && mv /root/.composer/vendor/bin/phpstan.phar /usr/local/bin/phpstan \
    && curl -L https://cs.symfony.com/download/php-cs-fixer-v2.phar -o /usr/local/bin/php-cs-fixer && chmod a+x /usr/local/bin/php-cs-fixer \
    \
    && `# ImageMagick` \
    && (curl -L "https://github.com/ImageMagick/ImageMagick/archive/${IMAGEMAGICK_VERSION}.tar.gz" | tar xz) \
    && cd ImageMagick-* \
    && ./configure \
    && make \
    && make install \
    && ldconfig /usr/local/lib \
    && cd .. \
    \
    && `# Symfony CLI` \
    && echo "Symfony CLI version: ${SYMFONYCLI_VERSION}" \
    && export SYMFONYCLI_MACHINE="amd64" \
    && (if [[ "i386" = `uname -m` ]]; then export SYMFONYCLI_MACHINE="386"; fi) \
    && echo "Symfony CLI architecture: ${SYMFONYCLI_MACHINE}" \
    && curl -sS https://get.symfony.com/cli/v${SYMFONYCLI_VERSION}/symfony_linux_${SYMFONYCLI_MACHINE} -o /usr/local/bin/symfony.gz \
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
    && composer clearcache \
    && apt-get purge -y --auto-remove -o APT::AutoRemove::RecommendsImportant=false -o APT::AutoRemove::SuggestsImportant=false $BUILD_LIBS $REMOVE_LIBS \
    && apt-get -y autoremove \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/* /var/www/* /var/cache/* /root/.composer/cache

WORKDIR /srv

ENTRYPOINT ["/bin/entrypoint"]

CMD ["symfony", "serve", "--dir=/srv", "--allow-http", "--no-tls", "--port=8000"]

EXPOSE 8000
