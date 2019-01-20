FROM composer

FROM php:7.2-fpm

LABEL maintainer="pierstoval@gmail.com"

# Composer is always used as root in our container
ENV COMPOSER_ALLOW_SUPERUSER=1

COPY bin/entrypoint.sh /entrypoint
RUN chmod a+x /entrypoint

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
        unzip \
        zlib1g-dev \
        libzip-dev \
        chromium \
    && docker-php-ext-configure gd --with-freetype-dir=/usr/include/ --with-jpeg-dir=/usr/include/ \
    && docker-php-ext-install -j$(nproc) gd \
    && docker-php-ext-configure pdo_mysql \
    && docker-php-ext-configure zip \
    && docker-php-ext-install opcache intl pdo_mysql zip \
    && (echo '' | pecl install apcu) \
    && (echo '' | pecl install xdebug) \
    && docker-php-ext-enable apcu \
    && composer global require --prefer-dist hirak/prestissimo \
    && apt-get clean

ENV PANTHER_NO_SANDBOX 1

WORKDIR /srv
