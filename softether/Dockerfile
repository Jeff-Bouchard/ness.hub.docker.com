FROM docker.io/siomiz/softethervpn:latest

ENV SOFTETHER_ENABLE_WG=1

COPY entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

EXPOSE 443/udp
EXPOSE 5555/tcp

ENTRYPOINT ["/entrypoint.sh"]
