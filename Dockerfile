FROM debian:bookworm-slim

LABEL org.opencontainers.image.title="KOReader Everywhere" \
      org.opencontainers.image.description="KOReader in a responsive browser container" \
      org.opencontainers.image.source="https://github.com/DishanRajapaksha/koreader-everywhere"

ENV LANG=en_US.UTF-8 LANGUAGE=en_US.UTF-8 LC_ALL=C.UTF-8 DISPLAY=:0.0
ENV EMULATE_READER_W="600" EMULATE_READER_H="800"
ENV VNC_AUTH="password" VNC_PASSWORD_FILE="/config/vnc.passwd"
ARG VERSION=0
ARG TARGETARCH
ARG ARCH

# Install only the runtime packages we need.
RUN apt-get update \
    && apt-get install -y --no-install-recommends \
        ca-certificates \
        novnc \
        wget \
        xz-utils \
        tigervnc-standalone-server \
        tigervnc-tools \
        supervisor \
        tzdata \
    && if [ -n "${ARCH:-}" ]; then \
         KOREADER_ARCH="$ARCH"; \
       else \
         case "$TARGETARCH" in \
           amd64) KOREADER_ARCH="x86_64" ;; \
           arm64) KOREADER_ARCH="arm64" ;; \
           *) echo "Unsupported architecture: $TARGETARCH" >&2; exit 1 ;; \
         esac; \
       fi \
    && KOREADER_URL="https://github.com/koreader/koreader/releases/download/v${VERSION}/koreader-linux-${KOREADER_ARCH}-v${VERSION}.tar.xz" \
    && echo "Downloading $KOREADER_URL" \
    && wget --https-only --tries=3 -q "$KOREADER_URL" -O /tmp/koreader.tar.xz \
    && xz -t /tmp/koreader.tar.xz \
    && cd /usr \
    && tar -xaf /tmp/koreader.tar.xz \
    && rm -f /tmp/koreader.tar.xz \
    && rm -rf /var/lib/apt/lists/*

# Install KOReader branding over noVNC.
COPY resources/icons/* /usr/share/novnc/app/images/icons/
COPY resources/koreader-logo.svg /usr/share/novnc/app/images/

ENV HOME=/home/user

RUN adduser --disabled-password --gecos "" user \
    && mkdir -p /books /config /home/user/.config /opt \
    && ln -s /config /home/user/.config/koreader \
    && ln -s /usr/share/novnc/vnc.html /usr/share/novnc/index.html \
    && sed -i "s/UI.initSetting('resize', 'off');/UI.initSetting('resize', 'remote');/" /usr/share/novnc/app/ui.js \
    && sed -i "s/#noVNC_control_bar_anchor {/#noVNC_control_bar_anchor {\n  display: none;/" /usr/share/novnc/app/styles/base.css \
    && sed -i 's/<div class="noVNC_logo" translate="no"><span>no<\/span>VNC<\/div>/<div class="noVNC_logo" translate="no"><img src="app\/images\/koreader-logo.svg" width=80%><\/div>/' /usr/share/novnc/vnc.html \
    && sed -i 's/<title>noVNC<\/title>/<title>KOReader Everywhere<\/title>/' /usr/share/novnc/vnc.html \
    && sed -i 's/background-color:#494949;/background-color:#DDDDDD;/' /usr/share/novnc/app/styles/base.css \
    && sed -i 's/background-color: #313131;/background-color:#CCCCCC;/' /usr/share/novnc/app/styles/base.css \
    && chown -R user:user "$HOME" /config

COPY resources/supervisord.conf /etc/supervisor/supervisord.conf
COPY resources/start_vnc resources/start_koreader resources/healthcheck resources/settings.reader.lua /opt/
RUN chmod +x /opt/start_vnc /opt/start_koreader /opt/healthcheck

ENTRYPOINT ["supervisord", "-c", "/etc/supervisor/supervisord.conf"]
HEALTHCHECK --interval=30s --timeout=5s --start-period=20s --retries=3 CMD ["/opt/healthcheck"]

EXPOSE 8080
WORKDIR $HOME
USER user
