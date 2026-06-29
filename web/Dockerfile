FROM nginx:stable-alpine3.23

ENV DOCKERIZE_VERSION v0.12.0
ENV NGINX_LOG_LEVEL warn

# Use ash with pipefail so a failure mid-pipe aborts
SHELL ["/bin/ash", "-eo", "pipefail", "-c"]

# Verify checksum before extracting Dockerize
RUN \
    ARCH=$(arch | sed s/aarch64/arm64/ | sed s/x86_64/amd64/) \
    && TARBALL="dockerize-alpine-linux-$ARCH-$DOCKERIZE_VERSION.tar.gz" \
    && curl -fsSL \
         "https://github.com/jwilder/dockerize/releases/download/$DOCKERIZE_VERSION/$TARBALL" \
         -o "$TARBALL" \
    && CHECKSUM=$(curl -fsSL \
         "https://github.com/jwilder/dockerize/releases/download/$DOCKERIZE_VERSION/checksums.txt" \
         | grep "$TARBALL" \
         | cut -d' ' -f1) \
    && echo "$CHECKSUM  $TARBALL" | sha256sum -c - \
    && tar -C /usr/local/bin -xzvf "$TARBALL" \
    && rm "$TARBALL"

COPY --chmod=755 entrypoint.sh /usr/local/bin/entrypoint

RUN sed -i \
    "s|notice;|$NGINX_LOG_LEVEL;|" \
    /etc/nginx/nginx.conf

ENTRYPOINT ["entrypoint"]

CMD ["nginx", "-g", "daemon off;"]