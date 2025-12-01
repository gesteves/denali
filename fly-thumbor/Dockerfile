FROM python:3.11-slim

# Install system dependencies including nginx and supervisor
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
    && rm -rf /var/lib/apt/lists/*

# Install Thumbor and plugins
RUN pip install --no-cache-dir \
    thumbor==7.7.7 \
    tc-aws \
    pillow-avif-plugin \
    pycurl

# Create config directories
RUN mkdir -p /etc/thumbor /var/log/supervisor

# Copy configurations
COPY thumbor.conf /etc/thumbor/thumbor.conf
COPY nginx.conf /etc/nginx/nginx.conf
COPY supervisord.conf /etc/supervisor/conf.d/supervisord.conf

# Expose port
EXPOSE 8888

# Run supervisor (manages both nginx and thumbor)
CMD ["supervisord", "-c", "/etc/supervisor/conf.d/supervisord.conf"]
