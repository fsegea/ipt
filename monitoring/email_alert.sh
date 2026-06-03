#!/bin/bash
# Script: email_alert.sh
# Envía alertas de seguridad por email

# ============================================
# CONFIGURACIÓN - EDITA ESTOS VALORES
# ============================================
# Cargar configuración desde archivo protegido
# Cargar configuración automáticamente
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
CONFIG_FILE="$PROJECT_DIR/config/.firewall_email_config"
if [ -f "$CONFIG_FILE" ]; then
    source "$CONFIG_FILE"
else
    echo "❌ Archivo de configuración no encontrado: $CONFIG_FILE"
    exit 1
fi
# ============================================

# Tipo de alerta
ALERT_TYPE="${1:-UNKNOWN}"
ALERT_IP="${2:-N/A}"
ALERT_DETAILS="${3:-Sin detalles}"

# Generar timestamp
TIMESTAMP=$(date '+%Y-%m-%d %H:%M:%S')
HOSTNAME=$(hostname)

# Asunto del email según tipo de alerta
case "$ALERT_TYPE" in
    SCANNER)
        SUBJECT="🚨 [VROUTER] Port Scanner Detectado"
        PRIORITY="High"
        ;;
    SYNFLOOD)
        SUBJECT="⚠️ [VROUTER] SYN Flood Detectado"
        PRIORITY="High"
        ;;
    MULTIPLE)
        SUBJECT="🔥 [VROUTER] Múltiples Ataques Detectados"
        PRIORITY="Critical"
        ;;
    WIREGUARD)
        SUBJECT="⚠️ [VROUTER] Actividad Sospechosa en WireGuard"
        PRIORITY="Medium"
        ;;
    *)
        SUBJECT="ℹ️ [VROUTER] Alerta de Seguridad"
        PRIORITY="Normal"
        ;;
esac

# Obtener información adicional
SCANNERS_COUNT=$(cat /proc/net/xt_recent/scanners 2>/dev/null | wc -l)
DROPS_LAST_HOUR=$(journalctl -k --no-pager --since "1 hour ago" | grep -c "INPUT-DROP:")

# Crear cuerpo del email en HTML
EMAIL_BODY=$(cat <<EOF
<!DOCTYPE html>
<html>
<head>
    <style>
        body { font-family: Arial, sans-serif; line-height: 1.6; color: #333; }
        .container { max-width: 600px; margin: 0 auto; padding: 20px; }
        .header { background: #d32f2f; color: white; padding: 15px; border-radius: 5px; }
        .alert-box { background: #fff3cd; border-left: 4px solid #ffc107; padding: 15px; margin: 20px 0; }
        .info-box { background: #e3f2fd; border-left: 4px solid #2196f3; padding: 15px; margin: 20px 0; }
        .details { background: #f5f5f5; padding: 10px; font-family: monospace; font-size: 12px; overflow-x: auto; }
        .footer { margin-top: 30px; padding-top: 20px; border-top: 1px solid #ddd; font-size: 12px; color: #666; }
        table { width: 100%; border-collapse: collapse; margin: 15px 0; }
        td { padding: 8px; border-bottom: 1px solid #ddd; }
        td:first-child { font-weight: bold; width: 150px; }
        .critical { color: #d32f2f; font-weight: bold; }
    </style>
</head>
<body>
    <div class="container">
        <div class="header">
            <h2>🚨 Alerta de Seguridad - VRouter</h2>
            <p>$TIMESTAMP</p>
        </div>
        
        <div class="alert-box">
            <h3>⚠️ Tipo de Amenaza: $ALERT_TYPE</h3>
            <p class="critical">IP Detectada: $ALERT_IP</p>
        </div>
        
        <div class="info-box">
            <h3>📊 Estado del Sistema</h3>
            <table>
                <tr>
                    <td>Hostname:</td>
                    <td>$HOSTNAME</td>
                </tr>
                <tr>
                    <td>Timestamp:</td>
                    <td>$TIMESTAMP</td>
                </tr>
                <tr>
                    <td>IPs Bloqueadas (24h):</td>
                    <td>$SCANNERS_COUNT IPs</td>
                </tr>
                <tr>
                    <td>Drops última hora:</td>
                    <td>$DROPS_LAST_HOUR paquetes</td>
                </tr>
            </table>
        </div>
        
        <div class="info-box">
            <h3>📝 Detalles de la Amenaza</h3>
            <div class="details">
$ALERT_DETAILS
            </div>
        </div>
        
        <div class="info-box">
            <h3>🔍 Últimos Logs Relacionados</h3>
            <div class="details">
$(journalctl -k --no-pager --since "5 minutes ago" | grep "$ALERT_IP" | tail -10)
            </div>
        </div>
        
        <div class="footer">
            <p>Esta es una alerta automática generada por el sistema de seguridad de VRouter.</p>
            <p>Para más información, accede al servidor y ejecuta: <code>fw-logs</code></p>
        </div>
    </div>
</body>
</html>
EOF
)

# Crear email temporal
TEMP_EMAIL="/tmp/alert_email_$$.html"
echo "$EMAIL_BODY" > "$TEMP_EMAIL"

# Enviar email usando diferentes métodos
send_email() {
    # Método 1: mailx (si está instalado)
    if command -v mailx >/dev/null 2>&1; then
        cat "$TEMP_EMAIL" | mailx -s "$SUBJECT" \
            -a "Content-Type: text/html" \
            "$EMAIL_TO"
        return $?
    fi
    
    # Método 2: sendmail (si está instalado)
    if command -v sendmail >/dev/null 2>&1; then
        (
            echo "To: $EMAIL_TO"
            echo "From: $EMAIL_FROM"
            echo "Subject: $SUBJECT"
            echo "Content-Type: text/html; charset=UTF-8"
            echo "X-Priority: 1"
            echo ""
            cat "$TEMP_EMAIL"
        ) | sendmail -t
        return $?
    fi
    
    # Método 3: msmtp (recomendado)
    if command -v msmtp >/dev/null 2>&1; then
        (
            echo "To: $EMAIL_TO"
            echo "From: $EMAIL_FROM"
            echo "Subject: $SUBJECT"
            echo "Content-Type: text/html; charset=UTF-8"
            echo ""
            cat "$TEMP_EMAIL"
        ) | msmtp "$EMAIL_TO"
        return $?
    fi
    
    # Método 4: curl + API de email (ej: Mailgun, SendGrid)
    # Descomentar y configurar si usas un servicio externo
    # curl -s --user "api:YOUR-API-KEY" \
    #     https://api.mailgun.net/v3/YOUR-DOMAIN/messages \
    #     -F from="$EMAIL_FROM" \
    #     -F to="$EMAIL_TO" \
    #     -F subject="$SUBJECT" \
    #     -F html="$(cat $TEMP_EMAIL)"
    # return $?
    
    echo "❌ No se encontró ningún método de envío de email instalado"
    echo "   Instala: apt install msmtp msmtp-mta"
    return 1
}

# Intentar enviar
if send_email; then
    echo "✅ Email enviado correctamente a $EMAIL_TO"
    echo "   Asunto: $SUBJECT"
    logger -t firewall-alert "Email de alerta enviado: $ALERT_TYPE - IP: $ALERT_IP"
else
    echo "❌ Error al enviar email"
    logger -t firewall-alert "ERROR: No se pudo enviar email de alerta"
fi

# Limpiar
rm -f "$TEMP_EMAIL"
