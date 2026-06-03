#!/bin/bash
# Script: analyze_scanners.sh
# Analiza patrones de scanning automáticamente

echo "=========================================="
echo "Análisis de Scanners Detectados"
echo "=========================================="
echo ""

SCANNER_FILE="/proc/net/xt_recent/scanners"

if [ ! -f "$SCANNER_FILE" ]; then
    echo "❌ No hay scanners detectados o módulo recent no activo"
    exit 1
fi

TOTAL=$(wc -l < "$SCANNER_FILE")
echo "📊 Total de IPs bloqueadas: $TOTAL"
echo ""

echo "🌐 Subnets con más IPs detectadas:"
cat "$SCANNER_FILE" | awk '{print $1}' | cut -d= -f2 | \
    awk -F. '{print $1"."$2"."$3".0/24"}' | \
    sort | uniq -c | sort -rn | head -10 | \
    awk '{printf "   %2d IPs - %s\n", $1, $2}'
echo ""

echo "🔍 TTL predominante:"
cat "$SCANNER_FILE" | awk '{print $3}' | cut -d: -f2 | \
    sort | uniq -c | sort -rn | \
    awk '{printf "   TTL %s: %d IPs\n", $2, $1}'
echo ""

echo "⏰ Última actividad:"
LAST_SEEN=$(cat "$SCANNER_FILE" | awk '{print $5}' | sort -rn | head -1)
LAST_IP=$(cat "$SCANNER_FILE" | grep "$LAST_SEEN" | awk '{print $1}' | cut -d= -f2)
echo "   IP: $LAST_IP"
echo "   Timestamp: $LAST_SEEN (jiffies del kernel)"
echo ""

echo "🚨 IPs sospechosas (TTL != 249):"
cat "$SCANNER_FILE" | grep -v "ttl: 249" | \
    awk '{printf "   %s (TTL: %s)\n", $1, $3}' | cut -d= -f2 | \
    awk '{print "   "$0}' || echo "   Ninguna"
echo ""

echo "=========================================="
echo "💡 SUGERENCIAS:"
echo "=========================================="

# Generar comandos ipset
echo "Ejecuta esto para bloquear las subnets completas:"
echo ""
cat "$SCANNER_FILE" | awk '{print $1}' | cut -d= -f2 | \
    awk -F. '{print $1"."$2"."$3".0/24"}' | \
    sort -u | while read subnet; do
        count=$(cat "$SCANNER_FILE" | grep -c "${subnet%.*}")
        if [ "$count" -gt 2 ]; then
            echo "ipset add scanner_nets $subnet  # ($count IPs detectadas)"
        fi
    done
