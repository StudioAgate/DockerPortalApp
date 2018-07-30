FROM composer

FROM php:7.2-fpm-stretch

LABEL maintainer="pierstoval@gmail.com"

# Composer is always used as root in our container
ENV COMPOSER_ALLOW_SUPERUSER=1

COPY bin/entrypoint.sh /usr/bin/entrypoint.sh
COPY etc/php.ini /usr/local/etc/php/conf.d/99-custom.ini
COPY --from=composer /usr/bin/composer /usr/local/bin/composer

RUN apt-get update \
    && apt-get install -y \
        libfreetype6-dev \
        libjpeg62-turbo-dev \
        libmcrypt-dev \
        libpng-dev \
        libicu-dev \
        imagemagick \
        zlib1g-dev \
        chromium \
    && docker-php-ext-configure gd --with-freetype-dir=/usr/include/ --with-jpeg-dir=/usr/include/ \
    && docker-php-ext-install -j$(nproc) gd \
    && docker-php-ext-configure pdo_mysql \
    && docker-php-ext-configure zip \
    && docker-php-ext-install opcache intl pdo_mysql zip \
    && (echo '' | pecl install apcu) \
    && docker-php-ext-enable apcu \
    && composer global require hirak/prestissimo \
    && addgroup foo \
    && adduser --gecos "" --disabled-password --home=/srv --no-create-home --shell=/bin/sh --ingroup foo foo \
    && apt-get clean

WORKDIR /var/www/html
