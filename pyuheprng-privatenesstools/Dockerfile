FROM python:3.11-slim

ARG TARGETPLATFORM

WORKDIR /app

# Install dependencies for entropy generation and privatenesstools
RUN apt-get update && apt-get install -y \
    apt-utils \
    git \
    rng-tools \
    openssl \
    curl \
    supervisor \
    && rm -rf /var/lib/apt/lists/*

# Clone pyuheprng repository
RUN git clone https://github.com/NESS-Network/PyUHEPRNG.git /app/pyuheprng \
    && cd /app/pyuheprng \
    && pip install --no-cache-dir .

# Clone privatenesstools repository
RUN git clone https://github.com/ness-network/privatenesstools.git /app/privatenesstools \
    && cd /app/privatenesstools \
    && pip install --no-cache-dir -r requirements.txt

# Environment variables for Emercoin connection and entropy control
ENV EMERCOIN_HOST=emercoin-core \
    EMERCOIN_PORT=6662 \
    EMERCOIN_USER=rpcuser \
    EMERCOIN_PASS=rpcpassword \
    MIN_ENTROPY_RATE=128 \
    BLOCK_ON_LOW_ENTROPY=true

# Copy supervisor configuration
COPY supervisord.conf /etc/supervisor/conf.d/supervisord.conf

# Copy entrypoint script
COPY entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

EXPOSE 5000 8888

# Health check (check both services)
HEALTHCHECK --interval=30s --timeout=10s --start-period=5s --retries=3 \
    CMD curl -f http://localhost:5000/health && curl -f http://localhost:8888/health || exit 1

ENTRYPOINT ["/entrypoint.sh"]
CMD ["/usr/bin/supervisord", "-c", "/etc/supervisor/conf.d/supervisord.conf"]
