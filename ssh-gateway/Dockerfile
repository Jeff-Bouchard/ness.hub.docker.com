FROM docker.io/debian:12-slim

# --- Build dependencies ---
RUN apt-get update && apt-get install --yes --no-install-recommends \
    gcc make \
    libcurl4-openssl-dev \
    libjansson-dev \
    openssh-server \
    ca-certificates \
    && rm -rf /var/lib/apt/lists/*

# --- Build emcssh from local source (includes fallback patches) ---
COPY emcssh/source /build/emcssh/
RUN cd /build/emcssh \
    && make \
    && install -s -m 755 emcssh /usr/sbin/emcssh \
    && rm -rf /build

# Strip build deps, keep runtime libs
RUN apt-get purge --yes gcc make libcurl4-openssl-dev libjansson-dev \
    && apt-get install --yes --no-install-recommends \
       libcurl4 libjansson4 \
    && apt-get autoremove --yes \
    && rm -rf /var/lib/apt/lists/*

# --- emcssh config ---
# emcurl points to emercoin-core on localhost (same netns via softether-vpn)
# RPC credentials injected at runtime via environment
RUN mkdir -p /etc/emercoin /etc/emercoin/emcssh.keys.d
COPY ssh-gateway/emcssh.conf /etc/emercoin/emcssh.conf
RUN chmod 600 /etc/emercoin/emcssh.conf

# --- sshd setup ---
RUN mkdir -p /var/run/sshd /root/.ssh \
    && chmod 700 /root/.ssh

COPY ssh-gateway/sshd_config /etc/ssh/sshd_config

# --- entrypoint ---
COPY ssh-gateway/entrypoint.sh /entrypoint.sh
RUN chmod 755 /entrypoint.sh

EXPOSE 2222

ENTRYPOINT ["/entrypoint.sh"]
