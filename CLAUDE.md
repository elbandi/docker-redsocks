# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What this is

A Docker image that wraps [redsocks](https://github.com/darkk/redsocks) to transparently redirect a container's/host's outbound TCP (and optionally UDP/DNS) traffic through an upstream SOCKS5/HTTP proxy using iptables NAT redirection.

There are two image variants:
- `Dockerfile` — multi-stage build on `ubuntu:16.04` that compiles redsocks from source (`release-0.5` tarball).
- `Dockerfile.alpine` — single-stage build on `alpine:3.24` that installs redsocks from the Alpine package repo.

Both variants COPY the same `redsocks.tmpl`, `entrypoint.sh`, and `fw.sh` into the image and set `entrypoint.sh` as the ENTRYPOINT.

## Build

```
docker build .                          # ubuntu-based image (Dockerfile)
docker build -f Dockerfile.alpine .     # alpine-based image
```

If building behind a proxy, pass `--build-arg http_proxy --build-arg https_proxy` (and `--network=host` if the proxy itself listens on localhost).

## Run

```
docker run --net=host --privileged \
  -e REDSOCKS_IP=<listen-addr> -e REDSOCKS_PORT=<listen-port> \
  -e REDSOCKS_DEVICE=<device> -e REDSOCKS_PROXY=<proxy-ip>:<proxy-port> \
  <image>
```

Configuration is entirely env-var driven (`REDSOCKS_*` prefix — see `entrypoint.sh`): `REDSOCKS_IP` (default `127.0.0.1`), `REDSOCKS_PORT` (default `12345`), `REDSOCKS_DEVICE` (default `eth0`), `REDSOCKS_PROXY` (default `localhost:3128`, must be plain `ip:port`, not a URL), `REDSOCKS_AUTH` (optional, `user:pass` — login credentials for the upstream proxy; kept separate from `REDSOCKS_PROXY` rather than embedded as `user:pass@host:port`, since `REDSOCKS_PROXY` is split on the *last* colon while `REDSOCKS_AUTH` is split on the *first* colon, so a password may itself contain colons). Because the container manipulates the host's iptables NAT table and network interfaces directly, it must run with `--net=host --privileged`.

## Architecture / request flow

1. **`entrypoint.sh`** reads `REDSOCKS_IP`/`REDSOCKS_PORT`/`REDSOCKS_DEVICE`/`REDSOCKS_PROXY`/`REDSOCKS_AUTH` into like-named local shell variables (`redsocks_ip`, `redsocks_port`, `redsocks_device`, `redsocks_proxy`, `redsocks_auth`, ...), splits `redsocks_proxy` on `ip:port` (no URL scheme/auth support) into `redsocks_proxy_host`/`redsocks_proxy_port` via bash parameter expansion, and if `REDSOCKS_AUTH` is set, splits it on the first `:` into `redsocks_login`/`redsocks_password` and builds a `login = "..."; password = "...";` config line (left as an empty placeholder otherwise, since redsocks treats the mere *presence* of these keys as "offer auth to the proxy"). It then generates `/tmp/redsocks.conf` from `/etc/redsocks.tmpl` via `sed` substitution of `${ip}`, `${port}`, `${proxy_ip}`, `${proxy_port}`, `${auth}` placeholders.
2. It calls **`fw.sh <device> <port> <proxy_host> <proxy_port> start`** to install iptables NAT rules: traffic outbound on `<device>` is redirected into a custom `REDSOCKS` chain, which `RETURN`s (bypasses the proxy) for addresses listed in `/etc/redsocks-whitelist.txt` (RFC1918/loopback ranges by default) and for the proxy's own host:port, then `REDIRECT`s remaining TCP traffic to the local redsocks port.
3. It launches `redsocks -c /tmp/redsocks.conf` in the foreground, tracks its PID, and traps `SIGTERM`/`INT`/`QUIT` to kill redsocks and call `fw.sh ... stop` (which flushes rules via `iptables-save | grep -v REDSOCKS | iptables-restore`) for clean shutdown.
4. `redsocks.tmpl` defines three redsocks sections: `redsocks` (TCP, `socks5` to the upstream proxy), `redudp` (UDP redirection), and `dnsu2t` (UDP-to-TCP DNS relay). `redsocks_redudp.tmpl` and `redsocks_dnsu2t.tmpl` are narrower templates covering only the `redudp` block / the combined base+redsocks+dnsu2t setup respectively — check which template a given Dockerfile/entrypoint path actually copies in before assuming all three are wired together.

## Working in this repo

- Shell scripts (`entrypoint.sh`, `fw.sh`) are the core logic — there is no application code or test suite. Validate changes by building the image and running it with `--net=host --privileged` against a real or mock SOCKS/HTTP proxy, then inspecting `iptables -t nat -L REDSOCKS` and the generated `/tmp/redsocks.conf` inside the container.
- `whitelist.txt` (installed as `/etc/redsocks-whitelist.txt` in the alpine image) lists CIDR ranges excluded from proxying; the ubuntu `Dockerfile` does not currently copy this file in, so whitelist behavior differs between the two image variants.
- Keep `fw.sh`'s `fw_clear`/`fw_setup` symmetric with whatever `fw_setup` adds, since `fw_clear` relies on filtering the `REDSOCKS` string out of `iptables-save` output to undo all changes cleanly.
