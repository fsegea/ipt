#!/bin/bash

# =====================================================================
# CADENA: OUTPUT_ILAN_IOT_ACL_ALLOW
# Conexiones NUEVAS que el propio router inicia hacia la red IoT ($ILAN_IOT)
# Red aislada y restrictiva
# =====================================================================
$IPT -N OUTPUT_ILAN_IOT_ACL_ALLOW

# === DHCP Server (Respuestas a la LAN) ===
# El router (puerto 67) le envía la IP asignada al cliente (puerto 68)
$IPT -A OUTPUT_ILAN_IOT_ACL_ALLOW -p udp --sport 67 --dport 68 -m conntrack --ctstate NEW -m comment --comment "Permitir respuestas DHCP a la red IoT" -j ACCEPT


# === VRRP (Alta Disponibilidad en IoT) ===
# Mantenido sin ctstate por diseño. Unificamos la sintaxis a '-p vrrp'
$IPT -A OUTPUT_ILAN_IOT_ACL_ALLOW -p vrrp -d 224.0.0.18 -m comment --comment "Permitir VRRP en la red IoT" -j ACCEPT

