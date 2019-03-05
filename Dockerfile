FROM php:7.2-fpm

LABEL maintainer="pierstoval@gmail.com"

# Composer is always used as root in our container
ENV COMPOSER_ALLOW_SUPERUSER=1
ENV BLACKFIRE_CONFIG /dev/null
ENV BLACKFIRE_LOG_LEVEL 1
ENV BLACKFIRE_SOCKET tcp://0.0.0.0:8707

COPY bin/entrypoint.sh /entrypoint
RUN chmod a+x /entrypoint

COPY etc/php.ini /usr/local/etc/php/conf.d/99-custom.ini
COPY --from=composer /usr/bin/composer /usr/local/bin/composer
COPY --from=blackfire/blackfire /usr/bin/blackfire* /usr/local/bin/

RUN apt-get update \
    && apt-get install -y \
        libfreetype6-dev \
        libjpeg62-turbo-dev \
        libmcrypt-dev \
        libpng-dev \
        libicu-dev \
        unzip \
        libgs-dev \
        zlib1g-dev \
        libzip-dev \
        curl \
    && version=$(php -r "echo PHP_MAJOR_VERSION.PHP_MINOR_VERSION;") \
    && curl -A "Docker" -o /tmp/blackfire-probe.tar.gz -D - -L -s https://blackfire.io/api/v1/releases/probe/php/linux/amd64/$version \
    && mkdir -p /tmp/blackfire \
    && tar zxpf /tmp/blackfire-probe.tar.gz -C /tmp/blackfire \
    && mv /tmp/blackfire/blackfire-*.so $(php -r "echo ini_get('extension_dir');")/blackfire.so \
    && printf "extension=blackfire.so\nblackfire.agent_socket=tcp://blackfire:8707\n" > $PHP_INI_DIR/conf.d/blackfire.ini \
    && rm -rf /tmp/blackfire /tmp/blackfire-probe.tar.gz \
    && docker-php-ext-configure gd \
        --with-freetype-dir=/usr/include/ \
        --with-jpeg-dir=/usr/include/ \
        --with-png-dir=/usr/include/ \
    && docker-php-ext-install -j$(nproc) gd \
    && docker-php-ext-configure pdo_mysql \
    && docker-php-ext-configure zip \
    && docker-php-ext-install opcache intl pdo_mysql zip \
    && (echo '' | pecl install apcu) \
    && (echo '' | pecl install xdebug) \
    && docker-php-ext-enable apcu \
    && curl -L "https://imagemagick.org/download/ImageMagick.tar.gz" | tar xz \
    && cd ImageMagick-* \
    && ./configure \
    && make \
    && make install \
    && ldconfig /usr/local/lib \
    && cd .. \
    && composer global require --prefer-dist hirak/prestissimo \
    && apt-get clean

ENV PANTHER_NO_SANDBOX 1

WORKDIR /srv
