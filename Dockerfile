FROM composer

FROM php:7.2-fpm-alpine

LABEL maintainer="pierstoval@gmail.com"

# Composer is always used as root in our container
ENV COMPOSER_ALLOW_SUPERUSER=1

COPY bin/entrypoint.sh /usr/bin/entrypoint.sh
COPY etc/php.ini /usr/local/etc/php/conf.d/99-custom.ini
COPY --from=composer /usr/bin/composer /usr/local/bin/composer

RUN apk add --no-cache --update libpng-dev libjpeg-turbo-dev icu-dev imagemagick \
    && apk add --no-cache --virtual .build-deps $PHPIZE_DEPS \
    && docker-php-ext-configure gd --with-jpeg-dir=/usr/include/ \
    && docker-php-ext-install gd \
    && docker-php-ext-configure pdo_mysql \
    && docker-php-ext-configure zip \
    && docker-php-ext-install opcache intl pdo_mysql zip \
    && pecl install apcu \
    && docker-php-ext-enable apcu \
    && composer global require hirak/prestisimo \
    && addgroup foo \
    && adduser -D -h /srv -s /bin/sh -G foo foo \
    && apk del .build-deps

WORKDIR /var/www/html
