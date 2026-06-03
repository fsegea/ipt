#!/bin/bash

# =====================================================================
# CADENA: OUTPUT_ILAN_ACL_ALLOW
# Conexiones NUEVAS que el propio router inicia hacia la LAN principal ($ILAN)
# =====================================================================
$IPT -N OUTPUT_ILAN_ACL_ALLOW

# === DHCP Server (Respuestas a la LAN) ===
# El router (puerto 67) le envía la IP asignada al cliente (puerto 68)
$IPT -A OUTPUT_ILAN_ACL_ALLOW -p udp --sport 67 --dport 68 -m conntrack --ctstate NEW -m comment --comment "Permitir respuestas DHCP a la red local" -j ACCEPT

# === VRRP (Alta Disponibilidad en la LAN) ===
# Mantenido sin ctstate por diseño para anuncios multicast continuos
$IPT -A OUTPUT_ILAN_ACL_ALLOW -p vrrp -d 224.0.0.18 -m comment --comment "Permitir VRRP en la red local" -j ACCEPT

# === DNS hacia Pi-hole ===
# Permite al vrouter iniciar consultas DNS (UDP y TCP) hacia el servidor Pi-hole local
$IPT -A OUTPUT_ILAN_ACL_ALLOW -p udp -d 10.10.0.100 --dport 53 -m conntrack --ctstate NEW -m comment --comment "Consultas DNS UDP a Pi-hole" -j ACCEPT
$IPT -A OUTPUT_ILAN_ACL_ALLOW -p tcp -d 10.10.0.100 --dport 53 -m conntrack --ctstate NEW -m comment --comment "Consultas DNS TCP a Pi-hole" -j ACCEPT
