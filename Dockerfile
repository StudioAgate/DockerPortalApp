FROM php:7.1-fpm

LABEL maintainer="pierstoval@gmail.com"

RUN apt-get update

# Install needed packages
RUN apt-get install -y apt-utils

RUN apt-get install -y \
    zlib1g-dev \
    g++ \
    libcurl3 libcurl3-dev libjpeg-dev libpng-dev libicu-dev \
    build-essential

# Install needed php extensions
RUN docker-php-ext-configure gd
RUN docker-php-ext-configure intl
RUN docker-php-ext-configure pdo_mysql
RUN docker-php-ext-configure zip

RUN docker-php-ext-install opcache
RUN docker-php-ext-install gd
RUN docker-php-ext-install intl
RUN docker-php-ext-install pdo_mysql
RUN docker-php-ext-install zip

RUN pecl install apcu && echo "extension=apcu.so" > /usr/local/etc/php/conf.d/apcu.ini

# Now install nodejs and packages

RUN curl -sL https://deb.nodesource.com/setup_6.x | bash - \
    && apt-get install -y  nodejs \
    && curl -sS https://dl.yarnpkg.com/debian/pubkey.gpg | apt-key add - \
    && echo "deb https://dl.yarnpkg.com/debian/ stable main" | tee /etc/apt/sources.list.d/yarn.list \
    && apt-get update && apt-get install yarn \
    && export PATH=$PATH:$PWD/node_modules/.bin \
    && curl -sL https://deb.nodesource.com/setup_6.x | bash -

# Composer is always used as root in our container
ENV COMPOSER_ALLOW_SUPERUSER=1

# Install composer and prestissimo for faster dependency installation
RUN php -r "readfile('https://getcomposer.org/installer');" | php -- --install-dir=/usr/local/bin --filename=composer\
    && chmod +x /usr/local/bin/composer

WORKDIR /var/www/html
