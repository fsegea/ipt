#!/bin/bash
# Script: daily-security-report.sh
# Genera y envía reportes diarios de seguridad (Versión IPSet)
export PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin:/root/scripts/

# Rutas automáticas basadas en ubicación del script
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
ALERT_SCRIPT="$PROJECT_DIR/monitoring/email_alert.sh"
CONFIG_FILE="$PROJECT_DIR/config/.firewall_email_config"

# Verificar configuración
if [ ! -f "$CONFIG_FILE" ]; then
    echo "Error: Configuración de email no encontrada: $CONFIG_FILE"
    exit 1
fi

source "$CONFIG_FILE"

# Obtener estadísticas
HOSTNAME=$(hostname)
TIMESTAMP=$(date '+%Y-%m-%d %H:%M:%S')
UPTIME=$(uptime -p)

# Contadores basados en logs del Journal (24 horas)
SCANNERS_24H=$(journalctl -k --no-pager --since "24 hours ago" | grep -c "SCANNER-SIGNATURE:" 2>/dev/null) || SCANNERS_24H=0
SUSPICIOUS_TTL_24H=$(journalctl -k --no-pager --since "24 hours ago" | grep -c "SUSPICIOUS-TTL:" 2>/dev/null) || SUSPICIOUS_TTL_24H=0
PORT_SCANNERS_24H=$(journalctl -k --no-pager --since "24 hours ago" | grep -c "PORT-SCANNER:" 2>/dev/null) || PORT_SCANNERS_24H=0
FAST_SCANS_24H=$(journalctl -k --no-pager --since "24 hours ago" | grep -c "FAST-SCAN:" 2>/dev/null) || FAST_SCANS_24H=0
SYN_FLOODS_24H=$(journalctl -k --no-pager --since "24 hours ago" | grep -c "SYN-FLOOD:" 2>/dev/null) || SYN_FLOODS_24H=0
UDP_FLOODS_24H=$(journalctl -k --no-pager --since "24 hours ago" | grep -c "UDP-FLOOD:" 2>/dev/null) || UDP_FLOODS_24H=0
FRAG_ATTACKS_24H=$(journalctl -k --no-pager --since "24 hours ago" | grep -c "FRAG-ATTACK:" 2>/dev/null) || FRAG_ATTACKS_24H=0
INPUT_DROPS_24H=$(journalctl -k --no-pager --since "24 hours ago" | grep -c "INPUT-DROP:" 2>/dev/null) || INPUT_DROPS_24H=0
FORWARD_DROPS_24H=$(journalctl -k --no-pager --since "24 hours ago" | grep -c "FORWARD-DROP:" 2>/dev/null) || FORWARD_DROPS_24H=0

# IPs y Redes bloqueadas en tiempo real (¡MIGRADO A IPSET!)
SCANNERS_BLOCKED=$(ipset list scanners 2>/dev/null | sed -n '/Members:/,$p' | tail -n +2 | wc -l) || SCANNERS_BLOCKED=0
SYNFLOODERS_BLOCKED=$(ipset list synflooders 2>/dev/null | sed -n '/Members:/,$p' | tail -n +2 | wc -l) || SYNFLOODERS_BLOCKED=0
UDPFLOODERS_BLOCKED=$(ipset list udpflooders 2>/dev/null | sed -n '/Members:/,$p' | tail -n +2 | wc -l) || UDPFLOODERS_BLOCKED=0
FRAG_BLOCKED=$(ipset list fragattackers 2>/dev/null | sed -n '/Members:/,$p' | tail -n +2 | wc -l) || FRAG_BLOCKED=0
NETS_BLOCKED=$(ipset list scanner_nets 2>/dev/null | sed -n '/Members:/,$p' | tail -n +2 | wc -l) || NETS_BLOCKED=0

# Total de elementos únicos baneados en la memoria del Firewall
TOTAL_BLOCKED_NOW=$((SCANNERS_BLOCKED + SYNFLOODERS_BLOCKED + UDPFLOODERS_BLOCKED + FRAG_BLOCKED + NETS_BLOCKED))

# Total de ataques registrados
TOTAL_ATTACKS=$((SCANNERS_24H + SUSPICIOUS_TTL_24H + PORT_SCANNERS_24H + FAST_SCANS_24H + SYN_FLOODS_24H + UDP_FLOODS_24H + FRAG_ATTACKS_24H))

# Sanitizar: forzar que todas las variables sean enteras
for var in SCANNERS_24H SUSPICIOUS_TTL_24H PORT_SCANNERS_24H FAST_SCANS_24H \
           SYN_FLOODS_24H UDP_FLOODS_24H FRAG_ATTACKS_24H INPUT_DROPS_24H \
           FORWARD_DROPS_24H SCANNERS_BLOCKED SYNFLOODERS_BLOCKED \
           UDPFLOODERS_BLOCKED FRAG_BLOCKED NETS_BLOCKED; do
    printf -v "$var" '%d' "${!var}" 2>/dev/null || printf -v "$var" '0'
done

# Determinar nivel de severidad
if [ $TOTAL_ATTACKS -gt 100 ]; then
    SEVERITY="🔴 ALTO"
    SEVERITY_COLOR="#d32f2f"
elif [ $TOTAL_ATTACKS -gt 20 ]; then
    SEVERITY="🟡 MEDIO"
    SEVERITY_COLOR="#f57c00"
else
    SEVERITY="🟢 BAJO"
    SEVERITY_COLOR="#4CAF50"
fi

# Top 10 IPs atacantes extraídas del log
TOP_ATTACKERS=$(journalctl -k --no-pager --since "24 hours ago" | 
    grep -oP 'SRC=\K[0-9.]+' | 
    sort | uniq -c | sort -rn | head -10 | 
    awk '{printf "    <tr><td>%s</td><td>%s eventos</td></tr>\n", $2, $1}')

if [ -z "$TOP_ATTACKERS" ]; then
    TOP_ATTACKERS="    <tr><td colspan='2' style='text-align:center;'>Sin actividad de ataque</td></tr>"
fi

# Últimos eventos significativos
RECENT_EVENTS=$(journalctl -k --no-pager --since "24 hours ago" | 
    grep -E "SCANNER-SIGNATURE:|FAST-SCAN:|SYN-FLOOD:|UDP-FLOOD:|FRAG-ATTACK:" | 
    tail -10 | 
    sed 's/</\&lt;/g; s/>/\&gt;/g' |
    sed 's/^/            /')

if [ -z "$RECENT_EVENTS" ]; then
    RECENT_EVENTS="            Sin eventos significativos en las últimas 24 horas"
fi

# Crear email HTML con soporte para todas tus nuevas listas
EMAIL_BODY=$(cat <<EOF
<!DOCTYPE html>
<html>
<head>
    <style>
        body { font-family: Arial, sans-serif; line-height: 1.6; color: #333; }
        .container { max-width: 700px; margin: 0 auto; padding: 20px; background: #f9f9f9; }
        .header { background: linear-gradient(135deg, #667eea 0%, #764ba2 100%); color: white; padding: 20px; border-radius: 8px; text-align: center; }
        .stats-grid { display: grid; grid-template-columns: repeat(2, 1fr); gap: 15px; margin: 20px 0; }
        .stat-box { background: white; padding: 15px; border-radius: 8px; box-shadow: 0 2px 4px rgba(0,0,0,0.1); }
        .stat-box h4 { margin: 0 0 10px 0; color: #666; font-size: 14px; }
        .stat-box .number { font-size: 32px; font-weight: bold; color: #667eea; }
        .severity { background: $SEVERITY_COLOR; color: white; padding: 10px 20px; border-radius: 20px; display: inline-block; font-weight: bold; }
        .section { background: white; padding: 20px; margin: 15px 0; border-radius: 8px; box-shadow: 0 2px 4px rgba(0,0,0,0.1); }
        table { width: 100%; border-collapse: collapse; margin: 15px 0; }
        th, td { padding: 10px; text-align: left; border-bottom: 1px solid #eee; }
        th { background: #f5f5f5; font-weight: bold; }
        .logs { background: #f5f5f5; padding: 15px; border-radius: 4px; font-family: monospace; font-size: 11px; overflow-x: auto; max-height: 300px; overflow-y: auto; }
        .footer { margin-top: 30px; padding-top: 20px; border-top: 2px solid #ddd; text-align: center; font-size: 12px; color: #666; }
        .alert-icon { font-size: 48px; margin-bottom: 10px; }
    </style>
</head>
<body>
    <div class="container">
        <div class="header">
            <div class="alert-icon">🛡️</div>
            <h1>Reporte Diario de Seguridad</h1>
            <p>VRouter - $HOSTNAME</p>
            <p>$TIMESTAMP</p>
        </div>
        
        <div class="section">
            <h2>📊 Resumen Ejecutivo</h2>
            <p><strong>Nivel de Actividad:</strong> <span class="severity">$SEVERITY</span></p>
            <p><strong>Total de intentos de ataque:</strong> $TOTAL_ATTACKS eventos</p>
            <p><strong>Elementos baneados en IPSet:</strong> $TOTAL_BLOCKED_NOW (IPs/Subredes)</p>
            <p><strong>Uptime del sistema:</strong> $UPTIME</p>
        </div>
        
        <div class="section">
            <h2>🎯 Estadísticas Detalladas (24h)</h2>
            <div class="stats-grid">
                <div class="stat-box">
                    <h4>🎯 Scanners con Firma</h4>
                    <div class="number">$SCANNERS_24H</div>
                    <small>Masscan/ZMap detectados</small>
                </div>
                <div class="stat-box">
                    <h4>⚠️  TTL Sospechoso</h4>
                    <div class="number">$SUSPICIOUS_TTL_24H</div>
                    <small>TTL anómalos detectados</small>
                </div>
                <div class="stat-box">
                    <h4>🚨 Port Scanners</h4>
                    <div class="number">$PORT_SCANNERS_24H</div>
                    <small>Escaneo moderado (6+ SYN/60s)</small>
                </div>
                <div class="stat-box">
                    <h4>⚡ Fast Scans</h4>
                    <div class="number">$FAST_SCANS_24H</div>
                    <small>Escaneo rápido (10+ SYN/60s)</small>
                </div>
                <div class="stat-box">
                    <h4>🔥 SYN Floods</h4>
                    <div class="number">$SYN_FLOODS_24H</div>
                    <small>Ataques de inundación TCP</small>
                </div>
                <div class="stat-box">
                    <h4>💥 UDP Floods</h4>
                    <div class="number">$UDP_FLOODS_24H</div>
                    <small>Ataques de inundación UDP</small>
                </div>
                <div class="stat-box">
                    <h4>💣 Frag Attacks</h4>
                    <div class="number">$FRAG_ATTACKS_24H</div>
                    <small>Fragmentación maliciosa</small>
                </div>
                <div class="stat-box">
                    <h4>🚫 Total Drops</h4>
                    <div class="number">$((INPUT_DROPS_24H + FORWARD_DROPS_24H))</div>
                    <small>Paquetes bloqueados</small>
                </div>
            </div>
        </div>
        
        <div class="section">
            <h2>🎭 Top 10 IPs Atacantes</h2>
            <table>
                <thead>
                    <tr>
                        <th>Dirección IP</th>
                        <th>Frecuencia</th>
                    </tr>
                </thead>
                <tbody>
$TOP_ATTACKERS
                </tbody>
            </table>
        </div>
        
        <div class="section">
            <h2>🔒 Estado de Listas IPSet Activas</h2>
            <table>
                <thead>
                    <tr>
                        <th>Nombre del Conjunto</th>
                        <th>Elementos Activos</th>
                    </tr>
                </thead>
                <tbody>
                    <tr><td><strong>scanners</strong> (Firma/TTL/Puerto/Slow):</td><td>$SCANNERS_BLOCKED IPs</td></tr>
                    <tr><td><strong>synflooders</strong> (TCP Flood):</td><td>$SYNFLOODERS_BLOCKED IPs</td></tr>
                    <tr><td><strong>udpflooders</strong> (UDP Flood):</td><td>$UDPFLOODERS_BLOCKED IPs</td></tr>
                    <tr><td><strong>fragattackers</strong> (Fragmentación):</td><td>$FRAG_BLOCKED IPs</td></tr>
                    <tr><td><strong>scanner_nets</strong> (Bloqueos de Rango /24):</td><td>$NETS_BLOCKED Subredes</td></tr>
                </tbody>
            </table>
        </div>
        
        <div class="section">
            <h2>📝 Últimos Eventos Significativos</h2>
            <div class="logs">
$RECENT_EVENTS
            </div>
        </div>
        
        <div class="section">
            <h2>💡 Recomendaciones</h2>
            <ul>
$(if [ "$TOTAL_ATTACKS" -gt 100 ]; then
    echo "                <li>⚠️  <strong>Actividad muy alta detectada</strong> - Considera revisar las reglas del firewall</li>"
    echo "                <li>🔍 Analiza los patrones de ataque para identificar amenazas persistentes</li>"
fi)
$(if [ "$SCANNERS_BLOCKED" -gt 1000 ]; then
    echo "                <li>📋 Lista de scanners muy poblada ($SCANNERS_BLOCKED IPs) - Considera purgar elementos viejos</li>"
fi)
                <li>✅ Mantén el sistema actualizado regularmente</li>
                <li>📊 Revisa este reporte y ajusta umbrales si es necesario</li>
                <li>🔐 Considera implementar herramientas de correlación si los Floods persisten</li>
            </ul>
        </div>
        
        <div class="footer">
            <p><strong>🛡️  VRouter Security System</strong></p>
            <p>Este es un reporte automático generado diariamente</p>
            <p>Para más información: <code>journalctl -k | grep -E "SCANNER|FLOOD"</code></p>
            <p>Fecha de generación: $TIMESTAMP</p>
        </div>
    </div>
</body>
</html>
EOF
)

# Crear archivo temporal
TEMP_EMAIL="/tmp/daily_report_$$.html"
echo "$EMAIL_BODY" > "$TEMP_EMAIL"

# Enviar email usando msmtp
SUBJECT="📊 [VROUTER] Reporte Diario de Seguridad - $SEVERITY"

if [ -x "/usr/bin/msmtp" ]; then
    (
        echo "To: $EMAIL_TO"
        echo "From: $EMAIL_FROM"
        echo "Subject: $SUBJECT"
        echo "Content-Type: text/html; charset=UTF-8"
        echo ""
        cat "$TEMP_EMAIL"
    ) | /usr/bin/msmtp "$EMAIL_TO"
    
    if [ $? -eq 0 ]; then
        echo "✅ Reporte diario enviado correctamente a $EMAIL_TO"
        logger -t firewall-report "Reporte diario enviado: $TOTAL_ATTACKS ataques detectados"
    else
        echo "❌ Error al enviar reporte diario"
        logger -t firewall-report "ERROR: No se pudo enviar reporte diario"
    fi
else
    echo "❌ msmtp no está instalado"
    exit 1
fi

# Limpiar
rm -f "$TEMP_EMAIL"
