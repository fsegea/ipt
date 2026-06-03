#!/bin/bash

# Configuración
# Configuración automática
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIG_DIR="$(dirname "$SCRIPT_DIR")"
source "$CONFIG_DIR/config/config.sh"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"

################======================================
# 🔥 IPS: BLOQUEOS DINÁMICOS (CORREGIDO: ORDEN SELECCIONADO)
################======================================
echo "Aplicando filtros dinámicos IPSET..."
# Inicialización limpia en memoria RAM
ipset create scanners hash:ip timeout 3600 -exist
ipset create scanner_nets hash:net timeout 86400 -exist
ipset create synflooders hash:ip timeout 86400 -exist
ipset create udpflooders hash:ip timeout 86400 -exist
ipset create fragattackers hash:ip timeout 86400 -exist


echo "=== Inicializando Firewall ==="

# Limpiar reglas existentes
echo "Limpiando reglas anteriores..."
$IPT -F
$IPT -X
$IPT -t nat -F
$IPT -t nat -X
$IPT -t mangle -F
$IPT -t mangle -X

# Política por defecto
echo "Estableciendo política DROP por defecto..."
$IPT -P INPUT DROP
$IPT -P FORWARD DROP
$IPT -P OUTPUT DROP

######################
# LOOPBACK (Primera regla - más frecuente)
######################
echo "Configurando loopback..."
$IPT -A INPUT -i lo -j ACCEPT
$IPT -A OUTPUT -o lo -j ACCEPT

######################
# ESTADOS ESTABLECIDOS Y RELACIONADOS (Global)
######################
echo "Permitiendo tráfico establecido global..."
$IPT -A INPUT -m conntrack --ctstate ESTABLISHED,RELATED -j ACCEPT
$IPT -A OUTPUT -m conntrack --ctstate ESTABLISHED,RELATED -j ACCEPT
$IPT -A FORWARD -m conntrack --ctstate ESTABLISHED,RELATED -j ACCEPT

# Descartar estados inválidos temprano
$IPT -A INPUT -m conntrack --ctstate INVALID -j DROP
$IPT -A FORWARD -m conntrack --ctstate INVALID -j DROP


# Nota: Usamos -A. Solo llegarán aquí paquetes NEW (nuevas conexiones).
# Si una IP ya bloqueada insiste, primero refresca su tiempo de castigo en el kernel:
$IPT -A INPUT -m set --match-set scanners src -j SET --add-set scanners src
# Y luego es destruida:
$IPT -A INPUT -m set --match-set scanners src -j DROP
# El resto de los sets unificados que procesará tu alert-monitor.sh:
$IPT -A INPUT -m set --match-set scanner_nets src -j DROP
$IPT -A INPUT -m set --match-set synflooders src -j DROP
$IPT -A INPUT -m set --match-set udpflooders src -j DROP
$IPT -A INPUT -m set --match-set fragattackers src -j DROP


######################
# CARGAR MÓDULOS (PRESERVADOS AL 100%)
######################
echo "Cargando módulos personalizados..."
source "$PROJECT_DIR/acl/output_iwan_acl_allow.sh"
source "$PROJECT_DIR/acl/output_ilan_acl_allow.sh"
source "$PROJECT_DIR/acl/output_ilan_iot_acl_allow.sh"
source "$PROJECT_DIR/acl/wan_acl_alexa_allow.sh"
source "$PROJECT_DIR/rules/port_redirect.sh"
source "$PROJECT_DIR/rules/port_forward.sh"
source "$PROJECT_DIR/rules/input_wan_services.sh"
source "$PROJECT_DIR/rules/input_lan_services.sh"
source "$PROJECT_DIR/rules/input_security.sh"
source "$PROJECT_DIR/acl/lan_acl_port_allow.sh"
source "$PROJECT_DIR/acl/lan_acl_mac_drop.sh"
source "$PROJECT_DIR/acl/lan_acl_ip_allow.sh"
source "$PROJECT_DIR/acl/lan_acl_port_drop.sh"
source "$PROJECT_DIR/parental_control/kids_access.sh"

######################
# CADENA INPUT
######################
echo "Configurando INPUT..."

$IPT -A INPUT -i $IWAN -m conntrack --ctstate NEW -j DROP
# Seguridad WAN (antes que servicios LAN)
$IPT -A INPUT -i $IWAN -j INPUT_SECURITY
$IPT -A INPUT -i $IWAN -j INPUT_WAN_SERVICES
# Servicios LAN / IoT
$IPT -A INPUT -j INPUT_LAN_SERVICES
# Log limitado antes de DROP final
$IPT -A INPUT -m limit --limit 2/min --limit-burst 5 -j LOG --log-prefix "INPUT-DROP: " --log-level 4
$IPT -A INPUT -j DROP

######################
# CADENA OUTPUT
######################
echo "Configurando OUTPUT..."

$IPT -A OUTPUT -o $IWAN -j OUTPUT_IWAN_ACL_ALLOW
$IPT -A OUTPUT -o $ILAN -j OUTPUT_ILAN_ACL_ALLOW
$IPT -A OUTPUT -o $ILAN_IOT -j OUTPUT_ILAN_IOT_ACL_ALLOW

$IPT -A OUTPUT -o wg0 -p icmp -m conntrack --ctstate NEW -j ACCEPT

# Log limitado antes de DROP final
$IPT -A OUTPUT -m limit --limit 2/min --limit-burst 5 -j LOG --log-prefix "OUTPUT-DROP: " --log-level 4
$IPT -A OUTPUT -j DROP

######################
# NAT - PREROUTING
######################
echo "Configurando NAT PREROUTING..."
$IPT -t nat -A PREROUTING -j PORT_REDIRECT

######################
# CADENA FORWARD
######################
echo "Configurando FORWARD..."

# 1. Port forwarding (WAN->LAN)
$IPT -A FORWARD -j PORT_FORWARD

# 2. Bloqueos globales y restricciones (Se evalúan antes de dar accesos)
$IPT -A FORWARD -j LAN_PORT_DROP
$IPT -A FORWARD -j LAN_MAC_DROP

# =====================================================================
# 3. Reglas de aislamiento: RED DE INVITADOS (Solo tráfico NEW)
# =====================================================================
$IPT -A FORWARD -i $ILAN_INVITADOS -o $ILAN -j DROP
$IPT -A FORWARD -i $ILAN_INVITADOS -o $ILAN_IOT -j DROP
$IPT -A FORWARD -i $ILAN_INVITADOS -o $IWAN -m conntrack --ctstate NEW -j ACCEPT

# =====================================================================
# 4. Reglas de aislamiento: RED IOT (Bloqueo estricto de salidas)
# =====================================================================
echo "Aplicando restricciones estrictas a LAN_IOT..."

# A) Denegar explícitamente los accesos requeridos:
$IPT -A FORWARD -i $ILAN_IOT -o $IWAN -j DROP  # No puede salir a WAN (Internet)
$IPT -A FORWARD -i $ILAN_IOT -o $ILAN -j DROP  # No puede acceder a tu LAN principal
$IPT -A FORWARD -i $ILAN_IOT -o wg0 -j DROP   # No puede acceder a la VPN WireGuard

# B) Permitir que la LAN principal controle los dispositivos IoT:
$IPT -A FORWARD -i $ILAN -o $ILAN_IOT -m conntrack --ctstate NEW -j ACCEPT

# 5. Listas de acceso genéricas
$IPT -A FORWARD -j LAN_ACL_IP_ALLOW
$IPT -A FORWARD -j LAN_ACL_PORT_ALLOW

# 6. VPN WireGuard (Solo tráfico NEW)
$IPT -A FORWARD -i $ILAN -o wg0 -s 10.10.0.0/24 -d 192.168.18.0/24 -m conntrack --ctstate NEW -j ACCEPT
$IPT -A FORWARD -i wg0 -o $ILAN -s 192.168.18.0/24 -d 10.10.0.0/24 -m conntrack --ctstate NEW -j ACCEPT

# Log limitado antes de DROP final
$IPT -A FORWARD -m limit --limit 2/min --limit-burst 5 -j LOG --log-prefix "FORWARD-DROP: " --log-level 4
$IPT -A FORWARD -j DROP

######################
# NAT - POSTROUTING
######################
echo "Configurando MASQUERADE y SNAT..."
$IPT -t nat -A POSTROUTING -s 10.10.0.0/24 -o $ILAN_IOT -j MASQUERADE

# Enmascaramiento hacia el exterior
$IPT -t nat -A POSTROUTING -o $IWAN -j MASQUERADE
$IPT -t nat -A POSTROUTING -o wg0 -j MASQUERADE

######################
# MOSTRAR REGLAS
######################
echo ""
echo "=== Reglas NAT ==="
$IPT -t nat -L -nv --line-numbers

echo ""
echo "=== Reglas FILTER ==="
$IPT -L -nv --line-numbers

# Guardar reglas
echo ""
echo "Guardando reglas..."
iptables-save > /etc/iptables/rules.v4

echo ""
echo "=== Firewall configurado correctamente ==="
exit 0
