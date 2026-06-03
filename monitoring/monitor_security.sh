#!/bin/bash
# Script: monitor-security.sh
# Monitoreo en tiempo real de INPUT_SECURITY con journalctl

# Rutas dinámicas
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
source "$PROJECT_DIR/config/config.sh"

# Validación de permisos
if [ "$EUID" -ne 0 ]; then
    echo "❌ Este script requiere privilegios de root"
    exit 1
fi

clear

# Función para obtener estadísticas
get_stats() {
    echo "=========================================="
    echo "Monitor de Seguridad INPUT_SECURITY"
    echo "🕒 $(date '+%d/%m/%Y %H:%M:%S')"
    echo "=========================================="
    echo ""
    
    echo "📊 Estadísticas de INPUT_SECURITY:"
    $IPT -L INPUT_SECURITY -v -n -x | head -20
    echo ""
    
    echo "🚨 Scanners en lista negra (24h):"
    if [ -f /proc/net/xt_recent/scanners ]; then
        SCANNERS=$(wc -l < /proc/net/xt_recent/scanners)
        echo "   Total: $SCANNERS IPs bloqueadas"
        
        if [ "$SCANNERS" -gt 0 ]; then
            echo ""
            echo "   Últimas 5 IPs bloqueadas:"
            tail -5 /proc/net/xt_recent/scanners | \
                awk '{print $1}' | cut -d= -f2 | \
                awk '{printf "      - %s\n", $0}'
        fi
    else
        echo "   Lista no disponible"
    fi
    echo ""
    
    echo "📝 Últimos eventos (últimos 5 minutos):"
    journalctl -k --no-pager --since "5 minutes ago" | \
        grep -E "PORT SCANNER:|SYN FLOOD:|INPUT DROP:" | \
        tail -10 | \
        awk '{print "   "$0}' || echo "   Sin eventos recientes"
    echo ""
    
    echo "=========================================="
    echo "Actualizando cada 10 segundos... (Ctrl+C para salir)"
}

# Loop infinito
while true; do
    clear
    get_stats
    sleep 10
done
