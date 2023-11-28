#!/bin/bash

set -e

init_nftables() {
    echo "Init nftables with all drop ..."
    nft flush ruleset
    nft create table ip nat
    nft create chain ip nat destnat { type nat hook prerouting priority dstnat \; }
    nft create chain ip nat sourcenat { type nat hook postrouting priority srcnat \; }
    nft create table ip filter
    nft create chain ip filter input { type filter hook input priority filter \; policy drop \; }
    nft create chain ip filter forward { type filter hook forward priority filter \; policy drop \; }
    nft create chain ip filter output { type filter hook output priority filter \; policy drop \; }
    echo "Init nftables with all drop ... DONE"
}

init_nftables_wg(){
    echo "Configure nftables for wireguard ..."
    nft add set ip filter localipranges { type ipv4_addr \; flags interval \; }
    nft add element ip filter localipranges { 10.0.0.0/8, 172.16.0.0/12, 192.168.0.0/16 }
    #DNAT dns to local dns server
    nft add rule ip nat destnat ip daddr $WG_DNS_SERVER ip protocol udp udp dport 53 dnat to $DNS_SERVER
    #Masquerade outgoing
    nft add rule ip nat sourcenat oif eth0 masquerade
    #Allow forward established
    nft add rule ip filter forward iif eth0 oif wg0 ct state vmap { established: accept, related: accept, invalid: drop }
    #Allow wg external traffic
    nft add rule ip filter input iif eth0 ip protocol udp udp dport $WG_PORT accept
    nft add rule ip filter output oif eth0 ip protocol udp udp sport $WG_PORT accept
    #Allow dns forward
    nft add rule ip filter forward iif wg0 oif eth0 ip daddr $DNS_SERVER ip protocol udp udp dport 53 accept
    #Allow webtraffic
    nft add rule ip filter forward iif wg0 oif eth0 ip daddr != @localipranges ip protocol tcp tcp dport { 80, 443 } ct state { new,established } accept
    echo "Configure nftables for wireguard ... DONE"
}

init_wg(){
    echo "Setting up wg0 interface ..."
    ip link add wg0 type wireguard
    wg set wg0 listen-port $WG_PORT private-key /etc/wireguard/privatekey
    wg set wg0 peer $WG_PEER_PUBKEY allowed-ips $WG_PEER_IP
    ip link set up dev wg0
    ip route add $WG_PEER_IP dev wg0
    echo "Setting up wg0 interface ... DONE"
}

remove_wg() {
    echo "Removing wg0 ..."
    ip link del wg0
    echo "Removing wg0 ... DONE"
}

finish() {
    echo "Shutting down ..."
    remove_wg
    exit 0
}
echo "Starting ..."
init_nftables
init_wg
init_nftables_wg
echo "Starting ... DONE"

trap finish TERM INT QUIT

sleep infinity &
wait $!
