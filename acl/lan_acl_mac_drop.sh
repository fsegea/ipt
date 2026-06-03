#!/bin/bash

##############################
# Crear y configurar la cadena LAN_IP_DROP
##############################
echo "Crear y configurar la cadena LAN_IP_DROP"
$IPT -N LAN_MAC_DROP  # Crear la cadena personalizada

##############################
# Bloquear por Medio de MAC
##############################
echo "Bloquear por medio de MAC"

# Ejemplo: Bloquear la dirección MAC 84:ab:1a:b4:3e:e5 en la interfaz ILAN (iPhone)
#$IPT -A LAN_MAC_DROP -m mac --mac-source 84:ab:1a:b4:3e:e5 -i $ILAN -m comment --comment "Bloquear MAC aa:bb:cc:dd:ee:ff" -j DROP
#$IPT -A LAN_MAC_DROP -m mac --mac-source cc:98:8b:b4:ad:78 -i $ILAN -m comment --comment "Bloquear MAC aa:bb:cc:dd:ee:ff" -j DROP

