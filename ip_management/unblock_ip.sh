#!/bin/bash
# Script: unblock-ip.sh
# Desbloquea una IP de la lista de scanners

if [ -z "$1" ]; then
    echo "❌ Error: Debes proporcionar una IP"
    echo "Uso: $0 <IP>"
    echo "Ejemplo: $0 185.218.160.130"
    exit 1
fi

IP="$1"

# Verificar si existe el archivo
if [ ! -f /proc/net/xt_recent/scanners ]; then
    echo "❌ Error: El módulo recent no está activo o no hay scanners"
    exit 1
fi

# Verificar si la IP está en la lista
if ! grep -q "src=$IP" /proc/net/xt_recent/scanners; then
    echo "⚠️  La IP $IP no está en la lista de scanners bloqueadas"
    echo ""
    echo "IPs actualmente bloqueadas:"
    cat /proc/net/xt_recent/scanners | awk '{print "   - "$1}' | cut -d= -f2
    exit 0
fi

# Desbloquear
echo "-$IP" > /proc/net/xt_recent/scanners

if ! grep -q "src=$IP" /proc/net/xt_recent/scanners; then
    echo "✅ IP $IP desbloqueada correctamente"
else
    echo "❌ Error al desbloquear la IP $IP"
    exit 1
fi
