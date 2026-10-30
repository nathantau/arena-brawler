# Headless authoritative game server. Build with server/build.sh, which exports the
# Linux binaries into build/server/ first (the image only copies them in).
FROM debian:bookworm-slim

ARG TARGETARCH
RUN useradd --create-home --shell /usr/sbin/nologin arena
COPY build/server/arena-server.${TARGETARCH} /opt/arena/arena-server
RUN chmod +x /opt/arena/arena-server

USER arena
WORKDIR /opt/arena
EXPOSE 7777/udp
# Extra server args (e.g. "--bots 2 --mode duel") can be appended to `docker run`.
ENTRYPOINT ["/opt/arena/arena-server", "--headless", "--", "--server", "--port", "7777"]
