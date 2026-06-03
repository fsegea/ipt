#!/bin/bash

# Crear y configurar la cadena PORT_FORWARD
$IPT -N PORT_FORWARD


##############################
# Reenvio Puertos Específicos
# Previamente se ha aplicado DNAT al 10.10.0.100:port en la tabla NAT / PREROUTING
##############################

# LOG antes del ACCEPT de WireGuard
#$IPT -I PORT_FORWARD 1 -p udp -i $IWAN -d 10.10.0.100 --dport 51820 -m conntrack --ctstate NEW -j LOG --log-prefix "WG-NEW: " --log-level 4
$IPT -I PORT_FORWARD 1 -p udp -i $IWAN --dport 51820 -j LOG --log-prefix "BLOCK-WG-NEW: " --log-level 4

# LOG solo del tráfico 443 que NO está en la whitelist Alexa (antes del DROP)
$IPT -I PORT_FORWARD 2 -p tcp -i $IWAN -d 10.10.0.100 --dport 443 \
    -m conntrack --ctstate NEW \
    -m set ! --match-set alexa_aws src \
    -j LOG --log-prefix "NPM-BLOQUEADO: " --log-level 4


# =============================================================================
# Reglas para tráfico NEW en HomeAssistant / Alexa Smart Home
# Solo se permite el reenvío al 443 desde rangos IP de Amazon Alexa (eu-west-1)
# Whitelist gestionada en acl/wan_acl_alexa_allow.sh mediante ipset 'alexa_aws'
# =============================================================================

# Aceptar 443 SOLO desde rangos Alexa confirmados
$IPT -A PORT_FORWARD -i $IWAN -o $ILAN -d 10.10.0.100 -p tcp --dport 443 \
    -m conntrack --ctstate NEW \
    -m set --match-set alexa_aws src \
    -j ACCEPT \
    -m comment --comment "NPM-ALEXA: solo rangos Amazon eu-west-1"

# Descartar silenciosamente cualquier otro intento al 443 desde WAN
$IPT -A PORT_FORWARD -i $IWAN -o $ILAN -d 10.10.0.100 -p tcp --dport 443 \
    -m conntrack --ctstate NEW \
    -j DROP \
    -m comment --comment "NPM-ALEXA: DROP no-whitelist"



# Reglas para tráfico NEW en WireGuard
#$IPT -A PORT_FORWARD -i $IWAN -o $ILAN -d 10.10.0.100 -p udp --dport 51820 -m conntrack --ctstate NEW -j ACCEPT -m comment --comment "WG-NEW"
# Reglas para tráfico NEW en HomeAssistant
#$IPT -A PORT_FORWARD -i $IWAN -o $ILAN -d 10.10.0.100 -p tcp --dport 443 -m conntrack --ctstate NEW -j ACCEPT -m comment --comment "NPM-NEW"
# Regla explicita para bloquear el puerto
$IPT -A PORT_FORWARD -i $IWAN -o $ILAN -p udp --dport 51820 -j DROP -m comment --comment "BLOCK-WG-NEW"



##############################
# Bloquear Puertos Específicos
##############################
#echo "Bloquear puertos específicos"
#Esta restriccion afecta a toda la LAN independientemente de si la conexion es legítima
# Bloquear el puerto HTTP3 (puerto 443)
#$IPT -A PORT_FORWARD -p udp --dport 443 -i $ILAN -m comment --comment "Bloquear puerto HTTP/3 443" -j DROP



# Reglas para tráfico MK-775
#$IPT -A PORT_FORWARD -i $IWAN -o $ILAN -d 10.10.0.181 -p udp --dport 5000 -m conntrack --ctstate NEW -j ACCEPT -m comment --comment "MK-775 NEW"