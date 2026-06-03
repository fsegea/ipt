#!/bin/bash

# Crear y configurar la cadena PORT_FORWARD
$IPT -N LAN_PORT_DROP

##############################
# Bloquear Puertos Específicos
##############################
echo "Bloquear puertos específicos"
#Esta restriccion afecta a toda la LAN independientemente de si la conexion es legítima
# Bloquear el puerto HTTP3 (puerto 443)
$IPT -A LAN_PORT_DROP -p udp --dport 443 -i $ILAN -m comment --comment "Bloquear puerto HTTP/3 443" -j DROP
# Bloquear el puerto dot (puerto 853)
$IPT -A LAN_PORT_DROP -p udp --dport 853 -i $ILAN -m comment --comment "Bloquear puerto DOT 853 (UDP)" -j DROP
$IPT -A LAN_PORT_DROP -p tcp --dport 853 -i $ILAN -m comment --comment "Bloquear puerto DOT 853 (TCP)" -j DROP



