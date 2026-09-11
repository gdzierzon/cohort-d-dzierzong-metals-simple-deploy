FROM nginxinc/nginx-unprivileged:stable-alpine

# The base image substitutes these variables into the Nginx template at startup.
ENV API_UPSTREAM=http://api:5000
# Docker's embedded DNS. Azure Web Apps must override this to 168.63.129.16.
ENV NGINX_RESOLVER=127.0.0.11

COPY docker/default.conf.template /etc/nginx/templates/default.conf.template
COPY index.html /usr/share/nginx/html/index.html
COPY css/ /usr/share/nginx/html/css/
COPY js/ /usr/share/nginx/html/js/
COPY assets/ /usr/share/nginx/html/assets/
COPY docker/runtime-config.js /usr/share/nginx/html/runtime-config.js

EXPOSE 8080
HEALTHCHECK --interval=30s --timeout=5s --start-period=10s --retries=3 \
    CMD wget -q -O /dev/null http://127.0.0.1:8080/health || exit 1

# Use the base image's entrypoint and foreground Nginx command.
