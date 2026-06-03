#!/bin/bash
# Script: block-ip.sh
# Bloquea manualmente una IP añadiéndola a la lista de scanners

if [ -z "$1" ]; then
    echo "❌ Error: Debes proporcionar una IP"
    echo "Uso: $0 <IP>"
    echo "Ejemplo: $0 1.2.3.4"
    exit 1
fi

IP="$1"

# Validar formato IP (básico)
if ! echo "$IP" | grep -qE '^[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}$'; then
    echo "❌ Error: Formato de IP inválido"
    exit 1
fi

# Añadir a la lista
echo "+$IP" > /proc/net/xt_recent/scanners 2>/dev/null

if grep -q "src=$IP" /proc/net/xt_recent/scanners 2>/dev/null; then
    echo "✅ IP $IP bloqueada por 24 horas"
    echo "   Se bloqueará automáticamente en futuros intentos de conexión"
else
    echo "❌ Error al bloquear la IP $IP"
    echo "   ¿El módulo recent está cargado?"
    exit 1
fi
