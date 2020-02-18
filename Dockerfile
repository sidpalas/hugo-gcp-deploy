FROM abiosoft/caddy:1.0.3
COPY ./public /srv

ENV ACME_AGREE=true # Agrees to letsencrypt license agreement
COPY ./Caddyfile /etc/Caddyfile

