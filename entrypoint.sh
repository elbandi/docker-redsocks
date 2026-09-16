#!/bin/bash

# All settings come from environment variables (REDSOCKS_* prefix).
redsocks_device="${REDSOCKS_DEVICE:-eth0}"

redsocks_ip="${REDSOCKS_IP:-127.0.0.1}"
redsocks_port="${REDSOCKS_PORT:-12345}"
redsocks_type="${REDSOCKS_TYPE:-socks5}"
redsocks_proxy="${REDSOCKS_PROXY:-localhost:3128}"

# REDSOCKS_PROXY must be in ip:port format
redsocks_proxy_host="${redsocks_proxy%:*}"
redsocks_proxy_port="${redsocks_proxy##*:}"

if [ -z "$redsocks_proxy_host" ] || [ -z "$redsocks_proxy_port" ] || ! [[ "$redsocks_proxy_port" =~ ^[0-9]+$ ]] || [ "$redsocks_proxy_port" -lt 1 ] || [ "$redsocks_proxy_port" -gt 65535 ]; then
    echo "Invalid REDSOCKS_PROXY: '${redsocks_proxy}'. Expected format ip:port." >&2
    exit 1
fi

if [ -z "$redsocks_ip" ]; then
    echo "No listening address specified, defaulting to 127.0.0.1"
    redsocks_ip="127.0.0.1"
fi

if [ -z "$redsocks_port" ]; then
    echo "No listening port specified, defaulting to 12345"
    redsocks_port="12345"
fi

echo "Creating redsocks configuration file using proxy ${redsocks_proxy_host}:${redsocks_proxy_port}..."
sed -e "s|\${redsocks_proxy_ip}|${redsocks_proxy_host}|" \
    -e "s|\${redsocks_proxy_port}|${redsocks_proxy_port}|" \
    -e "s|\${redsocks_ip}|${redsocks_ip}|" \
    -e "s|\${redsocks_port}|${redsocks_port}|" \
    -e "s|\${redsocks_type}|${redsocks_type}|" \
    /etc/redsocks.tmpl > /tmp/redsocks.conf

# redudp is optional, only enabled when REDUDP_PROXY is set
redudp_proxy="${REDUDP_PROXY}"

if [ -n "$redudp_proxy" ]; then
    redudp_ip="${REDUDP_IP:-127.0.0.1}"
    redudp_port="${REDUDP_PORT:-10053}"
    redudp_dest_ip="${REDUDP_DEST_IP:-8.8.8.8}"
    redudp_dest_port="${REDUDP_DEST_PORT:-53}"

    # REDUDP_PROXY must be in ip:port format
    redudp_proxy_host="${redudp_proxy%:*}"
    redudp_proxy_port="${redudp_proxy##*:}"

    if [ -z "$redudp_proxy_host" ] || [ -z "$redudp_proxy_port" ] || ! [[ "$redudp_proxy_port" =~ ^[0-9]+$ ]] || [ "$redudp_proxy_port" -lt 1 ] || [ "$redudp_proxy_port" -gt 65535 ]; then
        echo "Invalid REDUDP_PROXY: '${redudp_proxy}'. Expected format ip:port." >&2
        exit 1
    fi

    if ! [[ "$redudp_dest_port" =~ ^[0-9]+$ ]] || [ "$redudp_dest_port" -lt 1 ] || [ "$redudp_dest_port" -gt 65535 ]; then
        echo "Invalid REDUDP_DEST_PORT: '${redudp_dest_port}'. Expected value 1-65535." >&2
        exit 1
    fi

    echo "Adding redudp configuration using proxy ${redudp_proxy_host}:${redudp_proxy_port}..."
    sed -e "s|\${redudp_ip}|${redudp_ip}|" \
        -e "s|\${redudp_port}|${redudp_port}|" \
        -e "s|\${redudp_proxy_ip}|${redudp_proxy_host}|" \
        -e "s|\${redudp_proxy_port}|${redudp_proxy_port}|" \
        -e "s|\${redudp_dest_ip}|${redudp_dest_ip}|" \
        -e "s|\${redudp_dest_port}|${redudp_dest_port}|" \
        /etc/redsocks_redudp.tmpl >> /tmp/redsocks.conf
fi

# dnstc is optional, only enabled when DNSTC_PORT is set
dnstc_port="${DNSTC_PORT}"

if [ -n "$dnstc_port" ]; then
    dnstc_ip="${DNSTC_IP:-127.0.0.1}"

    if ! [[ "$dnstc_port" =~ ^[0-9]+$ ]] || [ "$dnstc_port" -lt 1 ] || [ "$dnstc_port" -gt 65535 ]; then
        echo "Invalid DNSTC_PORT: '${dnstc_port}'. Expected value 1-65535." >&2
        exit 1
    fi

    echo "Adding dnstc configuration on ${dnstc_ip}:${dnstc_port}..."
    sed -e "s|\${dnstc_ip}|${dnstc_ip}|" \
        -e "s|\${dnstc_port}|${dnstc_port}|" \
        /etc/redsocks_dnstc.tmpl >> /tmp/redsocks.conf
fi

echo "Generated configuration:"
cat /tmp/redsocks.conf

/fw.sh $redsocks_device $redsocks_port $redsocks_proxy_host $redsocks_proxy_port start

pid=0

# SIGUSR1 handler
usr_handler() {
  echo "usr_handler"
}

# SIGTERM-handler
term_handler() {
    if [ $pid -ne 0 ]; then
        echo "Term signal catched. Shutdown redsocks and disable iptables rules..."
        kill -SIGTERM "$pid"
        wait "$pid"
        /fw.sh $redsocks_device $redsocks_port $redsocks_proxy_host $redsocks_proxy_port stop
    fi
    exit 143; # 128 + 15 -- SIGTERM
}

# setup handlers
trap 'kill ${!}; usr_handler' SIGUSR1
trap 'kill ${!}; term_handler' INT QUIT TERM

echo "Starting redsocks..."
/usr/bin/redsocks -c /tmp/redsocks.conf &
pid="$!"

# wait indefinetely
while true
do
    tail -f /dev/null & wait ${!}
done
