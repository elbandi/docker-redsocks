# docker-redsocks

Wraps [redsocks](https://github.com/darkk/redsocks) in an easy to use Docker image. 

### Usage

To run:

```
docker run --net=host --privileged \
  -e REDSOCKS_IP=<listen-addr> \
  -e REDSOCKS_PORT=<listen-port> \
  -e REDSOCKS_DEVICE=<device> \
  -e REDSOCKS_PROXY=<proxy-ip>:<proxy-port> \
  wheelerlaw/redsocks
```

All configuration is done via environment variables:

```
REDSOCKS_IP        Local address to bind to. (127.0.0.1)
REDSOCKS_PORT      Local port to bind to. (12345)
REDSOCKS_DEVICE    Network interface to redirect traffic from. (eth0)
REDSOCKS_PROXY     Upstream proxy server to forward requests to, as ip:port. (localhost:3128)
```

The `redudp` (UDP relaying through a SOCKS proxy) feature is optional and disabled by default. They are enabled by setting `REDUDP_PROXY` respectively:

```
REDUDP_PROXY       Upstream SOCKS proxy for UDP relaying, as ip:port. Setting this enables redudp.
REDUDP_IP          Local address for the redudp listener. (127.0.0.1)
REDUDP_PORT        Local port for the redudp listener. (10053)
REDUDP_DEST_IP     Fixed destination address that redirected UDP traffic is expected to reach. (8.8.8.8)
REDUDP_DEST_PORT   Fixed destination port. (53)
```

The `dnstc` (fake DNS server that forces resolvers to retry over TCP) feature is optional and disabled by default. It is enabled by setting `DNSTC_PORT`:

```
DNSTC_PORT         Local port for the dnstc listener. Setting this enables dnstc.
DNSTC_IP           Local address for the dnstc listener. (127.0.0.1)
```

### Building

To build the image:

```
docker build -t redsocks-ubuntu .
```

An Alpine-based image can be built instead using `Dockerfile.alpine`, which produces a smaller image:

```
docker build -f Dockerfile.alpine -t redsocks-alpine .
```

If you are trying to build the image while behind a proxy, you can specify the proxy server:

```
docker build --build-arg "http_proxy=<proxy-URL>" --build-arg "https_proxy=<proxy-URL>" -t redsocks-ubuntu .
```

Or if your proxy host is defined in a local environment variable (`http_proxy`):

```
docker build --build-arg http_proxy --build-arg https_proxy -t redsocks-ubuntu .
```

If `http_proxy` is set to `http://localhost:3128` (if you are connecting through Cntlm for example), then it is likely the above commands won't work. You will need to tell the Docker daemon to use the host network stack:

```
docker build --build-arg http_proxy --build-arg https_proxy --network=host -t redsocks-ubuntu .
```
