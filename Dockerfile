FROM debian:10-slim

LABEL maintainer="pierstoval@gmail.com"

WORKDIR /srv

CMD ["symfony", "serve", "--dir=/srv", "--allow-http", "--port=8000"]

EXPOSE 8000

ENTRYPOINT ["/bin/entrypoint"]

ENV PHP_VERSION=7.4 \
    BLACKFIRE_CONFIG=/dev/null \
    BLACKFIRE_LOG_LEVEL=1 \
    GOSU_VERSION=1.12 \
    BLACKFIRE_SOCKET=tcp://0.0.0.0:8707 \
    PANTHER_NO_SANDBOX=1 \
    PATH=/home/.composer/vendor/bin:$PATH \
    PATH=/home/.config/composer/vendor/bin:$PATH \
    RUN_USER="_www"

COPY bin/entrypoint.sh /bin/entrypoint
COPY etc/php.ini /etc/php/${PHP_VERSION}/fpm/conf.d/99-custom.ini
COPY etc/php.ini /etc/php/${PHP_VERSION}/cli/conf.d/99-custom.ini
COPY --from=blackfire/blackfire /usr/local/bin/blackfire* /usr/local/bin/

RUN set -xe \
    && apt-get update \
    && apt-get upgrade -y \
    && apt-get install -y --no-install-recommends \
        ca-certificates \
        git \
        curl \
        wget \
        openssh-client \
        unzip \
        chromium-driver `# For symfony/panther` \
        dialog apt-utils `# Prevents having this issue: https://github.com/moby/moby/issues/27988` \
    \
    && `# Deb Sury PHP repository` \
    && apt-get -y install apt-transport-https lsb-release ca-certificates curl \
    && wget -O /etc/apt/trusted.gpg.d/php.gpg https://packages.sury.org/php/apt.gpg \
    && sh -c 'echo "deb https://packages.sury.org/php/ $(lsb_release -sc) main" > /etc/apt/sources.list.d/php.list' \
    && apt-get update \
    \
    && `# PHP and extensions` \
    && apt-get install -y \
        php${PHP_VERSION} \
        php${PHP_VERSION}-cli \
        php${PHP_VERSION}-common \
        php${PHP_VERSION}-curl \
        php${PHP_VERSION}-fpm \
        php${PHP_VERSION}-gd \
        php${PHP_VERSION}-intl \
        php${PHP_VERSION}-json \
        php${PHP_VERSION}-mbstring \
        php${PHP_VERSION}-mysql \
        php${PHP_VERSION}-opcache \
        php${PHP_VERSION}-readline \
        php${PHP_VERSION}-xml \
        php${PHP_VERSION}-zip \
        php${PHP_VERSION}-xdebug \
        php${PHP_VERSION}-apcu \
    \
    && `# User management for entrypoint` \
    && curl -L -s -o /bin/gosu https://github.com/tianon/gosu/releases/download/${GOSU_VERSION}/gosu-$(dpkg --print-architecture | awk -F- '{ print $NF }') \
    && chmod +x /bin/gosu \
    && mkdir -p /home \
    && groupadd ${RUN_USER} \
    && adduser --home=/home --shell=/bin/bash --ingroup=${RUN_USER} --disabled-password --quiet --gecos "" --force-badname ${RUN_USER} \
    && chown ${RUN_USER}:${RUN_USER} /home \
    \
    && `# Composer` \
    && (curl -sS https://getcomposer.org/installer | php -- --install-dir=/usr/local/bin --filename=composer) \
    && runuser -l ${RUN_USER} -c 'composer global require --prefer-dist symfony/flex' \
    \
    && `# Static analysis` \
    && runuser -l ${RUN_USER} -c 'composer global require nunomaduro/phpinsights' \
    && runuser -l ${RUN_USER} -c 'composer global require phpstan/phpstan' \
    && runuser -l ${RUN_USER} -c 'composer global require phpstan/phpstan-symfony' \
    && runuser -l ${RUN_USER} -c 'composer global require phpstan/phpstan-doctrine' \
    && runuser -l ${RUN_USER} -c 'composer global require phpstan/phpstan-phpunit' \
    && runuser -l ${RUN_USER} -c 'composer global require phpstan/phpstan-deprecation-rules' \
    && curl -L https://cs.symfony.com/download/php-cs-fixer-v2.phar -o /usr/local/bin/php-cs-fixer && chmod a+x /usr/local/bin/php-cs-fixer \
    \
    && `# ImageMagick` \
    && apt-get install -y imagemagick \
    \
    && `# Symfony CLI` \
    && (wget https://get.symfony.com/cli/installer -O - | bash) \
    && mv /root/.symfony/bin/symfony /usr/local/bin/symfony \
    && chown ${RUN_USER}:${RUN_USER} /usr/local/bin/symfony \
    \
    && `# Clean apt and remove unused libs/packages to make image smaller` \
    && runuser -l $RUN_USER -c 'composer clearcache' \
    && apt-get purge -y --auto-remove -o APT::AutoRemove::RecommendsImportant=false -o APT::AutoRemove::SuggestsImportant=false $BUILD_LIBS \
    && apt-get -y autoremove \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/* /var/www/* /var/cache/* /home/.composer/cache
