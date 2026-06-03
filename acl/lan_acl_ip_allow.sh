#!/bin/bash

echo "Crear y configurar la cadena LAN_ACL_IP_ALLOW"
$IPT -N LAN_ACL_IP_ALLOW

for IP in $PRIVILEGED_IPS; do
    $IPT -A LAN_ACL_IP_ALLOW -s $IP -i $ILAN -o $IWAN \
        -m comment --comment "IP privilegiada: $IP" -j ACCEPT
done
