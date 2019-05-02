#!/bin/sh
set -e

uid=$(stat -c %u /srv)
gid=$(stat -c %g /srv)

if [ "${uid}" -eq 0 ] && [ "${gid}" -eq 0 ]; then
    if [ $# -eq 0 ]; then
        php-fpm
    else
        exec "$@"
        exit
    fi
fi

sed -i "s/user = www-data/user = _www/g" /usr/local/etc/php-fpm.d/www.conf
sed -i "s/group = www-data/group = _www/g" /usr/local/etc/php-fpm.d/www.conf
sed -i -r "s/_www:x:\d+:\d+:/_www:x:$uid:$gid:/g" /etc/passwd
sed -i -r "s/_www:x:\d+:/_www:x:$gid:/g" /etc/group
chown _www /home

if [ $# -eq 0 ]; then
    php-fpm
else
    exec gosu _www "$@"
fi
