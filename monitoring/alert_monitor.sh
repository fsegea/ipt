#!/bin/bash
# Script: alert_monitor.sh (Versión de Producción Corregida)

RAM_DIR="/dev/shm/ips_monitor"
mkdir -p "$RAM_DIR"

# ==========================================
#  CONFIGURACIÓN POR CATEGORÍAS (SOPORTE IPTABLES)
# ==========================================
CAT_SCANNER_SET="scanners"
CAT_SCANNER_TIMEOUT=3600
CAT_SCANNER_THRESHOLD=2

CAT_TTL_SET="scanners"          
CAT_TTL_TIMEOUT=1800            
CAT_TTL_THRESHOLD=1

CAT_FAST_SET="scanners"         
CAT_FAST_TIMEOUT=86400          
CAT_FAST_THRESHOLD=1

CAT_SYN_SET="synflooders"
CAT_SYN_TIMEOUT=86400
CAT_SYN_THRESHOLD=1

CAT_UDP_SET="udpflooders"
CAT_UDP_TIMEOUT=86400          
CAT_UDP_THRESHOLD=1

CAT_FRAG_SET="fragattackers"
CAT_FRAG_TIMEOUT=86400
CAT_FRAG_THRESHOLD=1

CAT_SUBNET_SET="scanner_nets"   
CAT_SUBNET_TIMEOUT=86400
CAT_SUBNET_THRESHOLD=3
SUBNET_WINDOW=1800

# ==========================================
#  VARIABLES DE CONTROL DEL RECOLECTOR (GC)
# ==========================================
LAST_CLEANUP=$(date +%s)
CLEANUP_INTERVAL=300       # Ejecutar limpieza cada 5 minutos
MAX_SUBNET_AGE_MINUTES=720 # Recordar subredes por 12 horas (detección lenta)
CAT_WINDOW_LIMIT=3600      # Ventana de 1 hora (3600s) para acumular hits individuales

is_internal_ip() {
    local ip="$1"
    [[ "$ip" =~ ^10\. ]]          && return 0
    [[ "$ip" =~ ^192\.168\. ]]    && return 0
    [[ "$ip" =~ ^172\.(1[6-9]|2[0-9]|3[01])\. ]] && return 0
    [[ "$ip" =~ ^127\. ]]         && return 0
    return 1
}

block_element() {
    local set_name="$1"
    local element="$2"  
    local timeout="$3"
    local type="hash:ip"

    [ -z "$element" ] && return 0
    [[ "$element" == */* ]] && type="hash:net"

    if ! ipset list "$set_name" >/dev/null 2>&1; then
        echo "$(date '+%H:%M:%S') ⚠️ Creando set '$set_name' (Tipo: $type, Timeout: $timeout s)..."
        ipset create "$set_name" "$type" timeout "$timeout" -exist 2>/dev/null
    fi
    
    if ipset add "$set_name" "$element" timeout "$timeout" -exist 2>/dev/null; then
        echo "$(date '+%H:%M:%S') 🛑 Bloqueado/Refrescado: $element en set '$set_name' por $timeout s"
    else
        echo "$(date '+%H:%M:%S') ❌ Error interactuando con ipset para $element"
    fi
}

echo "🔎 IPS Simplificado Corriendo en RAM (Recolector Activo)..."

journalctl -kf | grep --line-buffered -E "SCANNER-SIGNATURE:|SUSPICIOUS-TTL:|SYN-FLOOD:|UDP-FLOOD:|PORT-SCANNER:|FAST-SCAN:|FRAG-ATTACK:|INPUT-DROP:" | while read -r line; do

    # RECOLECTOR DE BASURA (GC) - REPARADO
    NOW=$(date +%s)
    if [ $((NOW - LAST_CLEANUP)) -gt $CLEANUP_INTERVAL ]; then
        # 1. Limpia archivos de contadores normales que tengan más de 1 hora
        find "$RAM_DIR" -type f -not -name "sub_*" -mmin +"$((CAT_WINDOW_LIMIT / 60))" -delete 2>/dev/null
        # 2. Limpia registros de subredes que tengan más de 12 horas
        find "$RAM_DIR" -type f -name "sub_*" -mmin +"$MAX_SUBNET_AGE_MINUTES" -delete 2>/dev/null
        LAST_CLEANUP=$NOW
    fi

    IP=$(echo "$line" | grep -oP 'SRC=\K[0-9.]+' | head -1)
    [ -z "$IP" ] && continue
    if is_internal_ip "$IP"; then continue; fi

    CATEGORY=""
    if echo "$line" | grep -qE "SCANNER-SIGNATURE:|PORT-SCANNER:"; then
        CATEGORY="SCANNER"
        SET_NAME=$CAT_SCANNER_SET; TIMEOUT=$CAT_SCANNER_TIMEOUT; THRESHOLD=$CAT_SCANNER_THRESHOLD
    elif echo "$line" | grep -q "SUSPICIOUS-TTL:"; then
        CATEGORY="TTL"
        SET_NAME=$CAT_TTL_SET; TIMEOUT=$CAT_TTL_TIMEOUT; THRESHOLD=$CAT_TTL_THRESHOLD
    elif echo "$line" | grep -q "FAST-SCAN:"; then
        CATEGORY="FAST"
        SET_NAME=$CAT_FAST_SET; TIMEOUT=$CAT_FAST_TIMEOUT; THRESHOLD=$CAT_FAST_THRESHOLD
    elif echo "$line" | grep -q "SYN-FLOOD:"; then
        CATEGORY="SYN"
        SET_NAME=$CAT_SYN_SET; TIMEOUT=$CAT_SYN_TIMEOUT; THRESHOLD=$CAT_SYN_THRESHOLD
    elif echo "$line" | grep -q "UDP-FLOOD:"; then
        CATEGORY="UDP"
        SET_NAME=$CAT_UDP_SET; TIMEOUT=$CAT_UDP_TIMEOUT; THRESHOLD=$CAT_UDP_THRESHOLD
    elif echo "$line" | grep -q "FRAG-ATTACK:"; then
        CATEGORY="FRAG"
        SET_NAME=$CAT_FRAG_SET; TIMEOUT=$CAT_FRAG_TIMEOUT; THRESHOLD=$CAT_FRAG_THRESHOLD
    
    # === CATCHALL CON FILTRO DE SEGURIDAD ANTI-FALSOS POSITIVOS (TU LÓGICA INTEGRADAS) ===
    elif echo "$line" | grep -q "INPUT-DROP:"; then
        if echo "$line" | grep -q "SYN"; then
            CATEGORY="CATCHALL_DROP"
            SET_NAME="scanners"         
            TIMEOUT=7200                # Castigo de 2 horas
            THRESHOLD=5                 # 5 intentos SYN en puertos cerrados = Baneo
        fi
    fi

    # Procesar hits por categoría
    if [ -n "$CATEGORY" ]; then
        COUNTER_FILE="$RAM_DIR/${IP}_${CATEGORY}"
        current_hits=$(cat "$COUNTER_FILE" 2>/dev/null || echo "0")
        new_hits=$((current_hits + 1))
        echo "$new_hits" > "$COUNTER_FILE"

        if [ "$new_hits" -ge "$THRESHOLD" ]; then
            block_element "$SET_NAME" "$IP" "$TIMEOUT"
            rm -f "$COUNTER_FILE" 
        fi
    fi
    
    # LÓGICA DE SUBRED
    SUBNET=$(echo "$IP" | awk -F. '{print $1"."$2"."$3".0/24"}')
    SUBNET_SAFE="${SUBNET/\//-}"
    SUBNET_FILE="$RAM_DIR/sub_${SUBNET_SAFE}_${IP}"
    
    if [ ! -f "$SUBNET_FILE" ]; then
        echo "$NOW" > "$SUBNET_FILE"
    fi

    distinct_ips=$(find "$RAM_DIR" -name "sub_${SUBNET_SAFE}_*" -mmin -"$((SUBNET_WINDOW / 60))" 2>/dev/null | wc -l)

    if [ "$distinct_ips" -ge "$CAT_SUBNET_THRESHOLD" ]; then
        block_element "$CAT_SUBNET_SET" "$SUBNET" "$CAT_SUBNET_TIMEOUT"
        rm -f "$RAM_DIR"/sub_"${SUBNET_SAFE}"_*
    fi
done