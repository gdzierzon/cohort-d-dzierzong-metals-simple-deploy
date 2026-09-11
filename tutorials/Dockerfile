FROM nginxinc/nginx-unprivileged:stable-alpine

# The tutorial site is fully static with nothing to configure per environment,
# so the Nginx config is copied straight in rather than templated the way
# metals_ui/docker/default.conf.template is.
COPY nginx.conf /etc/nginx/conf.d/default.conf

# One line per top-level section, so nothing but site content reaches the
# document root. Add a line here when a new section folder is created.
COPY index.html /usr/share/nginx/html/index.html
COPY assets/ /usr/share/nginx/html/assets/
COPY images/ /usr/share/nginx/html/images/
COPY api/ /usr/share/nginx/html/api/
COPY database/ /usr/share/nginx/html/database/
COPY ui/ /usr/share/nginx/html/ui/
COPY docker/ /usr/share/nginx/html/docker/
COPY deployment/ /usr/share/nginx/html/deployment/
COPY terraform/ /usr/share/nginx/html/terraform/

EXPOSE 8080
HEALTHCHECK --interval=30s --timeout=5s --start-period=10s --retries=3 \
    CMD wget -q -O /dev/null http://127.0.0.1:8080/health || exit 1

# Use the base image's entrypoint and foreground Nginx command.
