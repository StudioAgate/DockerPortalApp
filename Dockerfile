FROM php:7.1-fpm

LABEL maintainer="pierstoval@gmail.com"

# Composer is always used as root in our container
ENV COMPOSER_ALLOW_SUPERUSER=1

RUN apt-get update \
    && apt-get install -y apt-utils \
    && apt-get install -y \
    zlib1g-dev \
    g++ \
    libcurl3 libcurl3-dev libjpeg-dev libpng-dev libicu-dev libfreetype6-dev libjpeg62-turbo-dev \
    build-essential

# Configure needed php extensions
RUN docker-php-ext-configure gd --with-freetype-dir=/usr/include/ --with-jpeg-dir=/usr/include/ \
    && docker-php-ext-install -j$(nproc) gd \
    && docker-php-ext-configure pdo_mysql \
    && docker-php-ext-configure zip \
    && docker-php-ext-install opcache gd intl pdo_mysql zip \
    && pecl install apcu \
    && docker-php-ext-enable apcu gd intl pdo_mysql zip \
    && echo "date.timezone = Europe/Paris" > /usr/local/etc/php/conf.d/custom.ini \
    && echo "short_open_tag = off" >> /usr/local/etc/php/conf.d/custom.ini \
    && echo "apc.enabled = 1" >> /usr/local/etc/php/conf.d/custom.ini

# Now install nodejs, yarn and composer
RUN curl -sL https://deb.nodesource.com/setup_6.x | bash - \
    && apt-get install -y  nodejs \
    && curl -sS https://dl.yarnpkg.com/debian/pubkey.gpg | apt-key add - \
    && echo "deb https://dl.yarnpkg.com/debian/ stable main" | tee /etc/apt/sources.list.d/yarn.list \
    && apt-get update && apt-get install yarn \
    && export PATH=$PATH:$PWD/node_modules/.bin \
    && curl -sL https://deb.nodesource.com/setup_6.x | bash - \
    \
    && php -r "readfile('https://getcomposer.org/installer');" | php -- --install-dir=/usr/local/bin --filename=composer\
    && chmod +x /usr/local/bin/composer \
    && apt-get clean \
    && apt-get autoclean \
    && apt-get autoremove -y \
    && rm -rf /var/lib/apt /var/lib/dpkg /var/lib/cache /var/lib/log

WORKDIR /var/www/html
