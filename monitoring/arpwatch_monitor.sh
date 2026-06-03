#!/bin/bash
# Script: arp_monitor.sh
# Monitorea eventos de arpwatch en la interfaz enp0s3 y envía alertas

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
ALERT_SCRIPT="$PROJECT_DIR/monitoring/email-alert.sh"
LAST_ALERT_FILE="/tmp/last_arp_alert"
MIN_ALERT_INTERVAL=300  # 5 minutos entre alertas del mismo tipo

echo "=========================================="
echo "🔎 Monitor de ARPWatch en enp0s3 Iniciado"
echo "=========================================="
echo "$(date '+%Y-%m-%d %H:%M:%S') - Monitoreando eventos de arpwatch..."
echo ""

should_alert() {
    local alert_type="$1"
    local current_time=$(date +%s)

    if [ -f "$LAST_ALERT_FILE" ]; then
        local last_time=$(grep "^$alert_type:" "$LAST_ALERT_FILE" 2>/dev/null | cut -d: -f2)
        if [ -n "$last_time" ]; then
            local diff=$((current_time - last_time))
            if [ $diff -lt $MIN_ALERT_INTERVAL ]; then
                return 1
            fi
        fi
    fi

    sed -i "/^$alert_type:/d" "$LAST_ALERT_FILE" 2>/dev/null
    echo "$alert_type:$current_time" >> "$LAST_ALERT_FILE"
    return 0
}

send_alert() {
    local type="$1"
    local ip="$2"
    local mac="$3"
    local details="$4"

    if should_alert "$type"; then
        echo "📧 Enviando alerta: $type - IP: $ip - MAC: $mac"
        "$ALERT_SCRIPT" "$type" "$ip" "$details" &
    else
        echo "⏳ Alerta $type omitida (cooldown activo)"
    fi
}

# Monitorear logs de arpwatch por identificador de programa (-t)
journalctl -f -t arpwatch | grep --line-buffered -E "new station|changed ethernet address|flip flop|bogon|reaper" | while read -r line; do
    IP=$(echo "$line" | grep -oP '([0-9]{1,3}\.){3}[0-9]{1,3}' | head -1)
    MAC=$(echo "$line" | grep -oP '([0-9A-Fa-f]{2}:){5}[0-9A-Fa-f]{2}' | head -1)

    if echo "$line" | grep -q "new station"; then
        DETAILS="Nuevo dispositivo detectado en enp0s3: IP=$IP, MAC=$MAC"
        send_alert "ARP-NEW" "$IP" "$MAC" "$DETAILS"
    elif echo "$line" | grep -q "changed ethernet address"; then
        DETAILS="Cambio de MAC para IP=$IP, nueva MAC=$MAC"
        send_alert "ARP-CHANGE" "$IP" "$MAC" "$DETAILS"
    elif echo "$line" | grep -q "flip flop"; then
        DETAILS="Flip-flop ARP detectado en enp0s3: IP=$IP alterna entre MACs"
        send_alert "ARP-FLIPFLOP" "$IP" "$MAC" "$DETAILS"
    elif echo "$line" | grep -q "bogon"; then
        DETAILS="Bogon detectado en enp0s3: IP=$IP, MAC=$MAC"
        send_alert "ARP-BOGON" "$IP" "$MAC" "$DETAILS"
    elif echo "$line" | grep -q "reaper"; then
        DETAILS="Evento reaper reportado por arpwatch (exit status detectado)"
        send_alert "ARP-REAPER" "$IP" "$MAC" "$DETAILS"
    fi
done
