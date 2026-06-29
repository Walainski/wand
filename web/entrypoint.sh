#!/bin/sh
# ./templates/nginx : /t/etc/nginx/conf.d/* → /etc/nginx/conf.d/*
# ./templates/vanilla : /t/usr/share/nginx/vanilla/* → /usr/share/nginx/vanilla/*

set -e

find /t -type f -name "*.template" | while read -r src; do
    dst="${src#/t}"
    dst="${dst%.template}"
    mkdir -p "$(dirname "$dst")"
    dockerize -template "$src:$dst"
done

exec "$@"
