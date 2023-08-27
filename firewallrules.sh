#!/bin/bash
ARCH=$(uname -m)


# Identify OS
if [ -f /etc/os-release ]; then
    # freedesktop.org and systemd
    . /etc/os-release
    OS=$NAME
    VER=$VERSION_ID
    UPSTREAM_ID=${ID_LIKE,,}

    # Fallback to ID_LIKE if ID was not 'ubuntu' or 'debian'
    if [ "${UPSTREAM_ID}" != "debian" ] && [ "${UPSTREAM_ID}" != "ubuntu" ]; then
        UPSTREAM_ID="$(echo ${ID_LIKE,,} | sed s/\"//g | cut -d' ' -f1)"
    fi

elif type lsb_release >/dev/null 2>&1; then
    # linuxbase.org
    OS=$(lsb_release -si)
    VER=$(lsb_release -sr)
elif [ -f /etc/lsb-release ]; then
    # For some versions of Debian/Ubuntu without lsb_release command
    . /etc/lsb-release
    OS=$DISTRIB_ID
    VER=$DISTRIB_RELEASE
elif [ -f /etc/debian_version ]; then
    # Older Debian, Ubuntu, etc.
    OS=Debian
    VER=$(cat /etc/debian_version)
elif [ -f /etc/SuSE-release ]; then
    # Older SuSE, etc.
    OS=SuSE
    VER=$(cat /etc/SuSE-release)
elif [ -f /etc/redhat-release ]; then
    # Older Red Hat, CentOS, etc.
    OS=RedHat
    VER=$(cat /etc/redhat-release)
else
    # Fall back to uname, e.g. "Linux <version>", also works for BSD, etc.
    OS=$(uname -s)
    VER=$(uname -r)
fi


# Output debugging info if $DEBUG set
if [ "$DEBUG" = "true" ]; then
    echo "OS: $OS"
    echo "VER: $VER"
    echo "UPSTREAM_ID: $UPSTREAM_ID"
    exit 0
fi

# Setup prereqs for server
# Common named prereqs
PREREQ="ipset"

echo "Installing prerequisites"
if [ "${ID}" = "debian" ] || [ "$OS" = "Ubuntu" ] || [ "$OS" = "Debian" ] || [ "${UPSTREAM_ID}" = "ubuntu" ] || [ "${UPSTREAM_ID}" = "debian" ]; then
    sudo apt-get update
    sudo apt-get install -y ${PREREQ} # git
elif [ "$OS" = "CentOS" ] || [ "$OS" = "RedHat" ] || [ "${UPSTREAM_ID}" = "rhel" ] ; then
# openSUSE 15.4 fails to run the relay service and hangs waiting for it
# Needs more work before it can be enabled
# || [ "${UPSTREAM_ID}" = "suse" ]
    sudo yum update -y
    sudo yum install -y ${PREREQ} # git
elif [ "${ID}" = "arch" ] || [ "${UPSTREAM_ID}" = "arch" ]; then
    sudo pacman -Syu
    sudo pacman -S ${PREREQ}
else
    echo "Unsupported OS"
    # Here you could ask the user for permission to try and install anyway
    # If they say yes, then do the install
    # If they say no, exit the script
    exit 1
fi

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
