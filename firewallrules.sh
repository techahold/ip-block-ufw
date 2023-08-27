#!/bin/bash

apt-get install ipset -y
yum install ipset -y

ipset create blacklist hash:ip hashsize 4096
ipset create dcblacklist nethash

iptables -I INPUT -m set --match-set blacklist src -j DROP
iptables -I FORWARD -m set --match-set blacklist src -j DROP
iptables -I INPUT -m set --match-set dcblacklist src -j DROP
iptables -I FORWARD -m set --match-set dcblacklist src -j DROP


echo -e "\n\tGetting Tor node list from dan.me.uk\n"
wget -q -O - https://www.dan.me.uk/torlist/ > /tmp/tor.txt
CMD=$(cat /tmp/tor.txt | uniq | sort)
for IP in $CMD; do
    let COUNT=COUNT+1
    ipset add blacklist $IP
done
echo -e "\n\Now blocking TOR connections !\n"

echo -e "\n\tGetting DC & VPN node list from X4BNet/lists_vpn\n"
wget -q -O - https://raw.githubusercontent.com/X4BNet/lists_vpn/main/output/datacenter/ipv4.txt > /tmp/dcip.txt
CMD=$(cat /tmp/dcip.txt | uniq | sort)
for IP in $CMD; do
    let COUNT=COUNT+1
    ipset add dcblacklist $IP
done
echo -e "\n\Now blocking DC & VPN connections !\n"
