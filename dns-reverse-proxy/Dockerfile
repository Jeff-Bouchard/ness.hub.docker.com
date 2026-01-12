FROM golang:1.21-alpine AS builder

ARG TARGETPLATFORM
ARG BUILDPLATFORM
ARG TARGETOS
ARG TARGETARCH

RUN apk add --no-cache git make

WORKDIR /app

RUN git clone https://github.com/ness-network/dns-reverse-proxy.git . \
    && GOOS=${TARGETOS} GOARCH=${TARGETARCH} go build -o dns-reverse-proxy .

FROM alpine:latest

RUN apk add --no-cache ca-certificates curl bind-tools

COPY --from=builder /app/dns-reverse-proxy /usr/local/bin/
COPY entrypoint.sh /usr/local/bin/entrypoint.sh
RUN chmod +x /usr/local/bin/entrypoint.sh

EXPOSE 53/udp 53/tcp 5335

ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]
