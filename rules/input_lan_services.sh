#!/bin/bash

# =====================================================================
# CADENA: INPUT_LAN_SERVICES (CORREGIDA)
# =====================================================================
$IPT -N INPUT_LAN_SERVICES

# ---------------------------------------------------------------------
# SECCIÓN A.1: Excepciones Legítimas de Broadcast (¡¡ARRIBA DEL TODO!!)
# ---------------------------------------------------------------------
# Permitimos el DHCP Discover/Request antes de que el filtro de ruido lo mate.
# Como el destino original de estos paquetes es 255.255.255.255, deben ir AQUÍ.

# DHCP para LAN principal ($ILAN)
$IPT -A INPUT_LAN_SERVICES -i $ILAN -p udp --sport 68 --dport 67 -m conntrack --ctstate NEW -m comment --comment "Permitir peticiones DHCP de la LAN" -j ACCEPT

# DHCP para red de Domótica ($ILAN_IOT)
$IPT -A INPUT_LAN_SERVICES -i $ILAN_IOT -p udp --sport 68 --dport 67 -m conntrack --ctstate NEW -m comment --comment "Permitir peticiones DHCP de IoT" -j ACCEPT


# ---------------------------------------------------------------------
# SECCIÓN A.2: Mitigación de Ruido y Bloqueos Explícitos (Filtro previo)
# Ahora sí, cualquier OTRO broadcast que no sea DHCP se descarta silenciosamente.
# ---------------------------------------------------------------------

# Filtro de Ruido para Red Principal ($ILAN)
$IPT -A INPUT_LAN_SERVICES -i $ILAN -d 255.255.255.255 -j DROP 
$IPT -A INPUT_LAN_SERVICES -i $ILAN -d 10.10.0.255 -j DROP 
$IPT -A INPUT_LAN_SERVICES -i $ILAN -p tcp --dport 853 -j DROP 

# Filtro de Ruido para Red de Domótica ($ILAN_IOT)
$IPT -A INPUT_LAN_SERVICES -i $ILAN_IOT -d 255.255.255.255 -j DROP 
$IPT -A INPUT_LAN_SERVICES -i $ILAN_IOT -d $IP_LAN_IOT_BROADCAST -j DROP 
$IPT -A INPUT_LAN_SERVICES -i $ILAN_IOT -p tcp --dport 853 -j DROP 


# ---------------------------------------------------------------------
# SECCIÓN B: Resto de Servicios Permitidos - Red Local Principal ($ILAN) 
# ---------------------------------------------------------------------

# === SSH (Gestión del Nodo) ===
$IPT -A INPUT_LAN_SERVICES -i $ILAN -p tcp --dport 22 -d $IP_LAN_FISICA -m conntrack --ctstate NEW -j ACCEPT

# === DNS (dnsmasq) ===
$IPT -A INPUT_LAN_SERVICES -i $ILAN -p udp --dport 53 -d $IP_LAN_VIP -m conntrack --ctstate NEW -j ACCEPT
$IPT -A INPUT_LAN_SERVICES -i $ILAN -p udp --dport 53 -d $IP_LAN_FISICA -m conntrack --ctstate NEW -j ACCEPT
$IPT -A INPUT_LAN_SERVICES -i $ILAN -p tcp --dport 53 -d $IP_LAN_VIP -m conntrack --ctstate NEW -j ACCEPT
$IPT -A INPUT_LAN_SERVICES -i $ILAN -p tcp --dport 53 -d $IP_LAN_FISICA -m conntrack --ctstate NEW -j ACCEPT

# === ICMP (Ping de diagnóstico) ===
$IPT -A INPUT_LAN_SERVICES -i $ILAN -p icmp -d $IP_LAN_VIP -m conntrack --ctstate NEW -j ACCEPT
$IPT -A INPUT_LAN_SERVICES -i $ILAN -p icmp -d $IP_LAN_FISICA -m conntrack --ctstate NEW -j ACCEPT

# === NTP Local ===
$IPT -A INPUT_LAN_SERVICES -i $ILAN -p udp --dport 123 -d $IP_LAN_FISICA -m conntrack --ctstate NEW -j ACCEPT


# ---------------------------------------------------------------------
# SECCIÓN C: Resto de Servicios Permitidos - Red de Domótica/IoT ($ILAN_IOT) 
# ---------------------------------------------------------------------

# === DNS (dnsmasq) ===
$IPT -A INPUT_LAN_SERVICES -i $ILAN_IOT -p udp --dport 53 -d $IP_LAN_IOT_VIP -m conntrack --ctstate NEW -j ACCEPT
$IPT -A INPUT_LAN_SERVICES -i $ILAN_IOT -p udp --dport 53 -d $IP_LAN_IOT_FISICA -m conntrack --ctstate NEW -j ACCEPT
$IPT -A INPUT_LAN_SERVICES -i $ILAN_IOT -p tcp --dport 53 -d $IP_LAN_IOT_VIP -m conntrack --ctstate NEW -j ACCEPT
$IPT -A INPUT_LAN_SERVICES -i $ILAN_IOT -p tcp --dport 53 -d $IP_LAN_IOT_FISICA -m conntrack --ctstate NEW -j ACCEPT

# === NTP Local ===
$IPT -A INPUT_LAN_SERVICES -i $ILAN_IOT -p udp --dport 123 -d $IP_LAN_IOT_FISICA -m conntrack --ctstate NEW -j ACCEPT 


# ---------------------------------------------------------------------
# SECCIÓN D: Protocolos de Alta Disponibilidad / Enrutamiento 
# ---------------------------------------------------------------------
$IPT -A INPUT_LAN_SERVICES -i $ILAN     -p vrrp -d 224.0.0.18 -j ACCEPT 
$IPT -A INPUT_LAN_SERVICES -i $ILAN_IOT -p vrrp -d 224.0.0.18 -j ACCEPT