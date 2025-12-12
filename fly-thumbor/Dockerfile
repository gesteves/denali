FROM python:3.11-slim

# Install system dependencies including nginx, supervisor, and monit
RUN apt-get update && apt-get install -y \
    build-essential \
    libssl-dev \
    libcurl4-openssl-dev \
    libjpeg-dev \
    libpng-dev \
    libwebp-dev \
    curl \
    nginx \
    supervisor \
    monit \
    && rm -rf /var/lib/apt/lists/*

# Install Thumbor and plugins
RUN pip install --no-cache-dir \
    thumbor==7.7.7 \
    tc-aws \
    pillow-avif-plugin \
    pycurl

# Create config directories
RUN mkdir -p /etc/thumbor /var/log/supervisor /tmp/thumbor/storage

# Copy configurations
COPY thumbor.conf /etc/thumbor/thumbor.conf
COPY nginx.conf /etc/nginx/nginx.conf
COPY supervisord.conf /etc/supervisor/conf.d/supervisord.conf
COPY monitrc /etc/monit/monitrc
COPY cleanup.sh /usr/local/bin/cleanup.sh
RUN chmod +x /usr/local/bin/cleanup.sh && chmod 700 /etc/monit/monitrc

# Expose port
EXPOSE 8888

# Run supervisor (manages nginx, thumbor, and monit)
CMD ["supervisord", "-c", "/etc/supervisor/conf.d/supervisord.conf"]
