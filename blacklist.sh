#!/bin/bash
export PATH=/sbin:/bin:/usr/sbin:/usr/bin:/usr/local/sbin:/usr/local/bin

attempt_counter=0
max_attempts=5
blacklist=/etc/nginx/blacklist
blacklist_new=/etc/nginx/blacklist_new
blacklist_url=https://raw.githubusercontent.com/Scumtron/firewall/master/blacklist

while [ 1 ]; do
    wget --retry-connrefused --waitretry=1 --read-timeout=20 --timeout=15 -t 0 --continue -q --no-cache --no-check-certificate -O - ${blacklist_url} | sed "s/.*/deny &;/"  > ${blacklist_new}
    if [ $? = 0 ]; then break; fi;
    sleep 1s;
done;

sleep 1s;

if [ ! -s ${blacklist_new} ]; then
        echo "File blacklist_new exist or empty"
        exit 25
fi

if [ ! -f "$blacklist" ]; then
        mv ${blacklist_new} ${blacklist}
        nginx -s reload
        if [ $? -eq 0 ]; then
            echo "Blacklist installed"
            exit 25
          else
            echo "Nginx test failed"
            exit 25
        fi
fi

if cmp -s ${blacklist} ${blacklist_new} > /dev/null 2>&1; then
        rm -rf ${blacklist_new}
        echo "No updates for blacklist"
else
        mv ${blacklist_new} ${blacklist}
        nginx -s reload
        if [ $? -eq 0 ]; then
            echo "Blacklist updated"
            exit 25
          else
            echo "Nginx test failed"
            exit 25
        fi
fi

