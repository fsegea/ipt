#!/bin/bash
# Script: whitelist-ip.sh
# Añade una IP a una whitelist permanente en iptables
# Rutas dinámicas
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
source "$PROJECT_DIR/config/config.sh"

# Validación de permisos
if [ "$EUID" -ne 0 ]; then
    echo "❌ Este script requiere privilegios de root"
    exit 1
fi


if [ -z "$1" ]; then
    echo "❌ Error: Debes proporcionar una IP"
    echo "Uso: $0 <IP> [comentario]"
    echo "Ejemplo: $0 185.218.160.130 'Servidor WireGuard'"
    exit 1
fi

IP="$1"
COMMENT="${2:-IP de confianza}"

# Verificar si ya existe
if $IPT -C INPUT_SECURITY -s "$IP" -j ACCEPT 2>/dev/null; then
    echo "⚠️  La IP $IP ya está en whitelist"
    exit 0
fi

# Añadir al inicio de INPUT_SECURITY
$IPT -I INPUT_SECURITY 1 -s "$IP" -j ACCEPT -m comment --comment "$COMMENT"

if $IPT -C INPUT_SECURITY -s "$IP" -j ACCEPT 2>/dev/null; then
    echo "✅ IP $IP añadida a whitelist permanente"
    echo "   Comentario: $COMMENT"
    echo ""
    echo "⚠️  IMPORTANTE: Esta regla se perderá al reiniciar"
    echo "   Guarda la configuración con: iptables-save > /etc/iptables/rules.v4"
else
    echo "❌ Error al añadir la IP a whitelist"
    exit 1
fi
