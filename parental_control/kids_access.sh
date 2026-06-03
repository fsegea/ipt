#!/bin/bash

# ============================================
# CONFIGURACIÓN - PUNTO ÚNICO DE EDICIÓN
# ============================================

# Cargar configuración automáticamente
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
source "$PROJECT_DIR/config/config.sh"

# ============================================
# FUNCIÓN: CARGAR IPs DE KIDS
# ============================================
load_kids_ips() {
    echo "=========================================="
    echo "📋 Cargando IPs de dispositivos infantiles"
    echo "=========================================="
    
    # Crear ipset si no existe
    ipset create "$IPSET_NAME" hash:ip timeout 86400 -exist 2>/dev/null || \
        ipset create "$IPSET_NAME" hash:ip timeout 86400
    
    # Limpiar ipset actual
    ipset flush "$IPSET_NAME" 2>/dev/null
    
    # Cargar cada IP de la lista
    for IP in $KIDS_IPS; do
        # Validar formato básico
        if echo "$IP" | grep -qE '^[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}$'; then
            ipset add "$IPSET_NAME" "$IP" 2>/dev/null
            logger -t firewall "Kids IP cargada: $IP"
        else
            echo "⚠️  IP inválida ignorada: $IP"
        fi
    done
    
    # Contar IPs cargadas
    COUNT=$(ipset list "$IPSET_NAME" | grep -c '^[0-9]')
    echo "✅ IPs cargadas: $COUNT"
    echo "   ipset: $IPSET_NAME"
    echo "   Fuente: KIDS_IPS variable"
}

# ============================================
# FUNCIÓN: CONFIGURAR REGLAS DE KIDS
# ============================================
configure_kids_access() {
    echo "=========================================="
    echo "🔐 Configurando KIDS_ACCESS"
    echo "=========================================="
    
    # Crear cadena KIDS_ACCESS si no existe
    $IPT -N KIDS_ACCESS 2>/dev/null || true
    
    # Default: Permitir todo (puede ajustarse después)
    $IPT -A KIDS_ACCESS -j RETURN
    
    # Redirigir tráfico de IPs de kids a KIDS_ACCESS
    for IP in $KIDS_IPS; do
        $IPT -A FORWARD -s "$IP" -i $ILAN -o $IWAN \
            -m comment --comment "Kids Access: $IP" \
            -j KIDS_ACCESS
    done
    
    echo "✅ Reglas de enrutamiento aplicadas"
}

# ============================================
# EJECUCIÓN PRINCIPAL
# ============================================
echo ""
load_kids_ips
configure_kids_access
