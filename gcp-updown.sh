#!/bin/bash
set -o nounset
set -o errexit

IP=$(which ip)

PLUTO_MARK_OUT_ARR=(${PLUTO_MARK_OUT//// })
PLUTO_MARK_IN_ARR=(${PLUTO_MARK_IN//// })

VTI_TUNNEL_ID=${1}
TUNNEL_STATIC_ROUTE=${2}

LOCAL_IF="${PLUTO_INTERFACE}"
VTI_IF="vti${VTI_TUNNEL_ID}"
# GCP's MTU is 1460, so it's hardcoded
GCP_MTU="1460"
# ipsec overhead is 73 bytes, we need to compute new mtu.
VTI_MTU=$((GCP_MTU-73))

add_route() {
    IFS=',' read -ra route <<< "${TUNNEL_STATIC_ROUTE}"
    for i in "${route[@]}"; do
        ip route add ${i} dev ${VTI_IF}
    done
    iptables -t mangle -A FORWARD -o ${VTI_IF} -p tcp --tcp-flags SYN,RST SYN -j TCPMSS --clamp-mss-to-pmtu
}

case "${PLUTO_VERB}" in
    up-client)
        ${IP} link add ${VTI_IF} type vti local ${PLUTO_ME} remote ${PLUTO_PEER} okey ${PLUTO_MARK_OUT_ARR[0]} ikey ${PLUTO_MARK_IN_ARR[0]}
        ${IP} link set ${VTI_IF} up mtu ${VTI_MTU}

        # Disable IPSEC Policy
        sysctl -w net.ipv4.conf.${VTI_IF}.disable_policy=1

        # Enable loosy source validation, if possible. Otherwise disable validation.
        sysctl -w net.ipv4.conf.${VTI_IF}.rp_filter=2 || sysctl -w net.ipv4.conf.${VTI_IF}.rp_filter=0

        # If you would like to use VTI for policy-based you shoud take care of routing by yourselv, e.x.
        #if [[ "${PLUTO_PEER_CLIENT}" != "0.0.0.0/0" ]]; then
        #    ${IP} r add "${PLUTO_PEER_CLIENT}" dev "${VTI_IF}"
        #fi
        add_route
        ;;
    down-client)
        ${IP} tunnel del "${VTI_IF}"
        ;;
esac

# Enable IPv4 forwarding
sysctl -w net.ipv4.ip_forward=1

# Disable IPSEC Encryption on local net
sysctl -w net.ipv4.conf.${LOCAL_IF}.disable_xfrm=1
sysctl -w net.ipv4.conf.${LOCAL_IF}.disable_policy=1

