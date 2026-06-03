#!/bin/bash
# Script: clear-scanners.sh
# Limpia toda la lista de scanners bloqueados

SCANNER_FILE="/proc/net/xt_recent/scanners"

if [ ! -f "$SCANNER_FILE" ]; then
    echo "❌ El archivo de scanners no existe"
    exit 1
fi

TOTAL=$(wc -l < "$SCANNER_FILE")

if [ "$TOTAL" -eq 0 ]; then
    echo "ℹ️  La lista ya está vacía"
    exit 0
fi

echo "⚠️  Vas a limpiar $TOTAL IPs bloqueadas"
read -p "¿Estás seguro? (s/N): " -n 1 -r
echo

if [[ $REPLY =~ ^[Ss]$ ]]; then
    echo / > "$SCANNER_FILE"
    echo "✅ Lista de scanners limpiada"
    echo "   Las IPs volverán a ser detectadas si intentan escanear de nuevo"
else
    echo "❌ Operación cancelada"
fi
