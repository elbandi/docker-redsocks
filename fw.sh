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

  # dnstc is optional, only set up when dnstc_port is given
  if [ -n "$dnstc_port" ]; then
    iptables -t nat -A REDSOCKS -p udp --dport 53 -j REDIRECT --to-ports $dnstc_port
  fi

  # redudp is optional, only set up when redudp_port is given
  if [ -n "$redudp_port" ]; then
    iptables -t nat -A REDSOCKS -d $redudp_proxy_host -p tcp --dport $redudp_proxy_port -j RETURN

    iptables -t nat -A REDSOCKS -p udp -j REDIRECT --to-ports $redudp_port
  fi

  iptables -t nat -A REDSOCKS -p tcp -j REDIRECT --to-ports $redsocks_port

  # Finally we tell iptables to use the ‘REDSOCKS’ chain for all outgoing connection in the network interface ‘eth0′.
  iptables -t nat -A OUTPUT -o $device -p tcp -j REDSOCKS
  if [ -n "$redudp_port" ] || [ -n "$dnstc_port" ]; then
    iptables -t nat -A OUTPUT -o $device -p udp -j REDSOCKS
  fi

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
  echo "Usage: $0 {device} {redsocks_port} {redsocks_proxy_host} {redsocks_proxy_port} {redudp_port} {redudp_proxy_host} {redudp_proxy_port} {dnstc_port} {start|stop}"
}

if [ $# -ne 9 ]; then
    usage
    exit 1
fi

device="$1"
redsocks_port="$2"
redsocks_proxy_host="$3"
redsocks_proxy_port="$4"
redudp_port="$5"
redudp_proxy_host="$6"
redudp_proxy_port="$7"
dnstc_port="$8"

case "$9" in
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
