#!/bin/bash
# Script: list-blocked.sh
# Lista todas las IPs bloqueadas con información detallada

SCANNER_FILE="/proc/net/xt_recent/scanners"

if [ ! -f "$SCANNER_FILE" ]; then
    echo "❌ No hay scanners detectados o módulo recent no activo"
    exit 1
fi

TOTAL=$(wc -l < "$SCANNER_FILE")

echo "=========================================="
echo "IPs Bloqueadas por Scanning"
echo "=========================================="
echo "Total: $TOTAL IPs"
echo ""

# Ordenar por última actividad (más reciente primero)
cat "$SCANNER_FILE" | sort -t: -k2 -rn | while read line; do
    IP=$(echo "$line" | awk '{print $1}' | cut -d= -f2)
    TTL=$(echo "$line" | awk '{print $3}' | cut -d: -f2)
    LAST_SEEN=$(echo "$line" | awk '{print $5}')
    
    # Calcular subnet
    SUBNET=$(echo "$IP" | awk -F. '{print $1"."$2"."$3".0/24"}')
    
    printf "%-18s TTL:%-4s Subnet: %s\n" "$IP" "$TTL" "$SUBNET"
done

echo ""
echo "Subnets más problemáticas:"
cat "$SCANNER_FILE" | awk '{print $1}' | cut -d= -f2 | \
    awk -F. '{print $1"."$2"."$3".0/24"}' | \
    sort | uniq -c | sort -rn | head -5 | \
    awk '{printf "   %2d IPs - %s\n", $1, $2}'
