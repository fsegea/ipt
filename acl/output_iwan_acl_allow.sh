#!/bin/bash

# =====================================================================
# CADENA: OUTPUT_IWAN_ACL_ALLOW
# Control de conexiones NUEVAS iniciadas por el propio router hacia la WAN (Internet)
# =====================================================================

# 1. Crear la cadena si no existe
$IPT -N OUTPUT_IWAN_ACL_ALLOW

# ---------------------------------------------------------------------
# SECCIÓN A: Servicios de Red Críticos (DNS, NTP, DHCP)
# ---------------------------------------------------------------------

# === Consultas DNS UDP (Solo a servidores autorizados/ISP) ===
$IPT -A OUTPUT_IWAN_ACL_ALLOW -p udp -d $DNS_SERVER1 --dport 53 -m conntrack --ctstate NEW -m comment --comment "Permitir consultas DNS UDP a $DNS_SERVER1" -j ACCEPT
$IPT -A OUTPUT_IWAN_ACL_ALLOW -p udp -d $DNS_SERVER2 --dport 53 -m conntrack --ctstate NEW -m comment --comment "Permitir consultas DNS UDP a $DNS_SERVER2" -j ACCEPT

# === Sincronización de Hora (NTP) ===
$IPT -A OUTPUT_IWAN_ACL_ALLOW -p udp --dport 123 -m conntrack --ctstate NEW -m comment --comment "Permitir conexiones NTP" -j ACCEPT

# === Cliente DHCP de la WAN ===
# Nota: Como explicamos en INPUT, el DHCP del router hacia el ISP necesita estar abierto de destinos debido a su naturaleza dinámica
$IPT -A OUTPUT_IWAN_ACL_ALLOW -p udp --sport 68 --dport 67 -m conntrack --ctstate NEW -m comment --comment "Permitir peticiones DHCP" -j ACCEPT


# ---------------------------------------------------------------------
# SECCIÓN B: Aplicaciones y Gestión Externa (HTTP, Correo, VPN)
# ---------------------------------------------------------------------

# === Conexiones HTTP (Navegación/Actualizaciones de repositorios del sistema) ===
$IPT -A OUTPUT_IWAN_ACL_ALLOW -p tcp --dport 80 -m conntrack --ctstate NEW -m comment --comment "Permitir conexiones HTTP" -j ACCEPT

# === Envío de Alertas por Correo (SMTP Seguro / Puerto 587) ===
$IPT -A OUTPUT_IWAN_ACL_ALLOW -p tcp --dport 587 -m conntrack --ctstate NEW -m comment --comment "Permitir alertas correo" -j ACCEPT

# === Tunelización WireGuard hacia la Sede Central (HO) ===
$IPT -A OUTPUT_IWAN_ACL_ALLOW -p udp -d $HO --dport 51820 -m conntrack --ctstate NEW -m comment --comment "Permitir conexión WireGuard a HO" -j ACCEPT


# ---------------------------------------------------------------------
# SECCIÓN C: Diagnóstico y Control de Red
# ---------------------------------------------------------------------

# === Pings ICMP ejecutados desde el CLI del router ===
$IPT -A OUTPUT_IWAN_ACL_ALLOW -p icmp -m conntrack --ctstate NEW -m comment --comment "Permitir pings ICMP desde el router por IWAN" -j ACCEPT
