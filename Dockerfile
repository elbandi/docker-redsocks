FROM ubuntu:24.04

MAINTAINER Wheeler Law <whelderwheels613@gmail.com>

RUN apt-get update && apt-get install -y iptables net-tools libevent-2.1-7 libevent-core-2.1-7 redsocks

COPY redsocks.tmpl /etc/redsocks.tmpl
COPY redsocks_redudp.tmpl /etc/redsocks_redudp.tmpl
COPY entrypoint.sh /entrypoint.sh
COPY fw.sh /fw.sh

ENTRYPOINT ["/entrypoint.sh"]
