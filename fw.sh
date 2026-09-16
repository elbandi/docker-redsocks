#!/bin/sh

##########################
# Setup the Firewall rules
##########################
fw_setup() {
  # First we added a new chain called 'REDSOCKS' to the 'nat' table.
  iptables -t nat -N REDSOCKS

  iptables -t nat -A REDSOCKS -o lo -j RETURN

  # Next we used "-j RETURN" rules for the networks we don’t want to use a proxy.
  while read item; do
    iptables -t nat -A REDSOCKS -d $item -j RETURN
  done < /etc/redsocks-whitelist.txt

  iptables -t nat -A REDSOCKS -d $redsocks_proxy_host -p tcp --dport $redsocks_proxy_port -j RETURN

  iptables -t nat -A REDSOCKS -p tcp -j REDIRECT --to-ports $redsocks_port

  # Finally we tell iptables to use the ‘REDSOCKS’ chain for all outgoing connection in the network interface ‘eth0′.
  iptables -t nat -A OUTPUT -o $device -p tcp -j REDSOCKS
}

##########################
# Clear the Firewall rules
##########################
fw_clear() {
  iptables-save | grep -v REDSOCKS | iptables-restore
  #iptables -L -t nat --line-numbers
  #iptables -t nat -D PREROUTING 2
}

usage() {
  echo "Usage: $0 {device} {port} {proxy_host} {proxy_port} {start|stop}"
}

if [ $# -ne 5 ]; then
    usage
    exit 1
fi

device="$1"
redsocks_port="$2"
redsocks_proxy_host="$3"
redsocks_proxy_port="$4"

case "$5" in
    start)
        echo -n "Setting REDSOCKS firewall rules for interface $device -> $redsocks_port... "
        fw_clear
        fw_setup
        echo "done."
        ;;
    stop)
        echo -n "Cleaning REDSOCKS firewall rules for interface $device -> $redsocks_port... "
        fw_clear
        echo "done."
        ;;
    *)
        usage
        exit 1
        ;;
esac
exit 0
