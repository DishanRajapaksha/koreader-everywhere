# KOReader Everywhere

Run [KOReader](https://github.com/koreader/koreader) in a web browser from a small, multi-architecture container. The browser is provided by noVNC, the virtual desktop by TigerVNC, and the framebuffer follows the browser viewport instead of merely stretching a fixed desktop.

This repository started from [wardwouts/koreader-novnc](https://github.com/wardwouts/koreader-novnc) and keeps that project's Git history. It is an independent community container and is not affiliated with the KOReader project.

## What it does

- Runs KOReader in any modern browser through noVNC.
- Resizes the actual virtual desktop when the browser window changes size or a phone/tablet rotates.
- Publishes `linux/amd64` and `linux/arm64` images to GitHub Container Registry.
- Persists KOReader settings separately from your book library.
- Runs as an unprivileged user with VNC bound to the container loopback interface.
- Requires VNC authentication by default and makes passwordless VNC an explicit opt-in.
- Includes a Docker health check and supervised process restarts.

## Quick start with Docker Compose

Create a books directory, choose a password, and start the container:

```bash
mkdir -p books
VNC_PASSWORD='choose-a-password' docker compose up -d
```

Open <http://127.0.0.1:8080> and enter the same VNC password when prompted.

Put your books in `./books`. KOReader sees that directory as `/books`, mounted read-only by default. Its settings live in the `koreader_config` Docker volume.

To stop it:

```bash
docker compose down
```

To upgrade to the newest published image:

```bash
docker compose pull
docker compose up -d
```

## Docker CLI

If you do not want Compose:

```bash
docker run -d \
  --name koreader-everywhere \
  -p 127.0.0.1:8080:8080 \
  -e VNC_PASSWORD='choose-a-password' \
  -e TZ='Europe/Amsterdam' \
  -v "$PWD/books:/books:ro" \
  -v koreader_config:/config \
  --restart unless-stopped \
  ghcr.io/dishanrajapaksha/koreader-everywhere:latest
```

## Responsive display

KOReader Everywhere starts with a small fallback desktop, `600x800` by default. Once noVNC connects, it requests remote resizing and TigerVNC changes the real framebuffer to match the browser viewport.

That means resizing a desktop browser, rotating a phone, or moving between portrait and landscape changes KOReader's usable screen rather than scaling a fixed image.

`EMULATE_READER_W` and `EMULATE_READER_H` control only the initial geometry before the browser supplies its size.

## Configuration

| Variable | Default | Purpose |
| --- | --- | --- |
| `VNC_AUTH` | `password` | `password` requires VNC authentication. `none` explicitly disables it. |
| `VNC_PASSWORD` | unset | Creates/updates the VNC password file at container start. |
| `VNC_PASSWORD_FILE` | `/config/vnc.passwd` | Location of the persistent TigerVNC password file. |
| `EMULATE_READER_W` | `600` | Initial virtual display width. |
| `EMULATE_READER_H` | `800` | Initial virtual display height. |
| `TZ` | system default | Container timezone, for example `Europe/Amsterdam`. |

### Volumes

| Path | Use |
| --- | --- |
| `/books` | Book library. A read-only mount is recommended. |
| `/config` | KOReader configuration and the generated VNC password file. Must be writable. |
| `/usr/lib/koreader/fonts/myfonts` | Optional additional fonts. A read-only mount is suitable. |

## Security

The Compose file publishes the web interface on `127.0.0.1` by default. The VNC server itself listens only on the container loopback interface, so port 5900 is never exposed by the image.

For access from another machine, put the service behind HTTPS or a private network/VPN. If a reverse proxy provides strong authentication, you may deliberately set `VNC_AUTH=none`; do not use passwordless mode on an untrusted network.

To bind the web service to every host interface with Compose, set:

```bash
KOREADER_BIND=0.0.0.0 VNC_PASSWORD='choose-a-password' docker compose up -d
```

That makes port 8080 reachable from your network. Treat it accordingly.

### Caddy example

A local container bound to `127.0.0.1:8080` can sit behind Caddy:

```caddyfile
reader.example.com {
    reverse_proxy 127.0.0.1:8080
}
```

Caddy handles the WebSocket upgrade used by noVNC. Add whatever authentication policy is appropriate for the deployment rather than exposing passwordless VNC to the public Internet.

## Versioning

KOReader Everywhere and KOReader have independent versions:

- `VERSION` is the KOReader Everywhere release version, for example `0.1.0`.
- `KOREADER_VERSION` is the upstream KOReader version embedded in the image, for example `2026.03`.

This lets KOReader Everywhere ship fixes without pretending there is a new KOReader release.

## Building locally

```bash
KOREADER_VERSION="$(cat KOREADER_VERSION)"
docker build \
  --build-arg KOREADER_VERSION="$KOREADER_VERSION" \
  -t koreader-everywhere:local \
  .
```

Docker BuildKit supplies the target architecture automatically. Supported targets are `amd64` and `arm64`.

## Container publishing

Container images are published only for KOReader Everywhere release tags. A release tag must match `VERSION`.

For example, if `VERSION` contains `0.1.0`:

```bash
git tag v0.1.0
git push origin v0.1.0
```

Before publishing, CI builds an `amd64` image, starts it, waits for Docker health, and verifies the noVNC page. Only after that passes does GitHub Actions build and publish the `amd64`/`arm64` release manifest:

```text
ghcr.io/dishanrajapaksha/koreader-everywhere:latest
ghcr.io/dishanrajapaksha/koreader-everywhere:0.1.0
```

`KOREADER_VERSION` is independent of this release tag. A mismatched project tag, such as `v0.2.0` while `VERSION` still contains `0.1.0`, fails before publishing. Pull requests and manual workflow runs execute the same boot smoke test but never publish an image.

## KOReader updates

A scheduled GitHub Actions workflow checks upstream KOReader releases every Monday. When a newer stable release appears, it updates `KOREADER_VERSION`, builds and boots a candidate container, and opens a pull request only if that smoke test succeeds.

If a PR for the same KOReader release is already open, the workflow leaves it alone. You can also run the update check manually from GitHub Actions.

## Components and attribution

KOReader Everywhere combines several upstream projects. Each retains its own licence and copyright terms:

- [KOReader](https://github.com/koreader/koreader)
- [noVNC](https://github.com/novnc/noVNC)
- [TigerVNC](https://github.com/TigerVNC/tigervnc)
- Original browser-container work: [wardwouts/koreader-novnc](https://github.com/wardwouts/koreader-novnc)
