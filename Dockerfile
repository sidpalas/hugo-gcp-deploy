FROM abiosoft/caddy:1.0.3
COPY ./public /srv

# Agrees to letsencrypt license agreement
ENV ACME_AGREE=true 
COPY ./Caddyfile /etc/Caddyfile

