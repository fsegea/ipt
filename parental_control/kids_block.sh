#!/bin/bash
export PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
source "$PROJECT_DIR/config/config.sh"

# Fallback por si $IPT sigue vacío
IPT="${IPT:-/usr/sbin/iptables}"

$IPT -F KIDS_ACCESS
$IPT -A KIDS_ACCESS -j DROP


# Cerrar todas las conexiones TCP/UDP activas
for IP in $KIDS_IPS; do
    /usr/sbin/conntrack -D -s $IP 2>/dev/null
    /usr/sbin/conntrack -D -d $IP 2>/dev/null
done

logger "Acceso a internet bloqueado para dispositivos infantiles - Conexiones activas cerradas"
