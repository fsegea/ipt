#!/bin/bash
# Script: install-alert-service.sh
# Instala el servicio de alertas como systemd

cat > /etc/systemd/system/firewall-alerts.service <<'EOF'
[Unit]
Description=Firewall Alert Monitor
After=network.target iptables.service

[Service]
Type=simple
ExecStart=/root/ipt/monitoring/alert-monitor.sh
Restart=always
RestartSec=10
StandardOutput=journal
StandardError=journal
SyslogIdentifier=firewall-alerts

[Install]
WantedBy=multi-user.target
EOF

# Recargar systemd
systemctl daemon-reload

# Habilitar y arrancar el servicio
systemctl enable firewall-alerts.service
systemctl start firewall-alerts.service

echo "✅ Servicio instalado y arrancado"
echo ""
echo "Comandos útiles:"
echo "  systemctl status firewall-alerts   # Ver estado"
echo "  systemctl stop firewall-alerts     # Detener"
echo "  systemctl restart firewall-alerts  # Reiniciar"
echo "  journalctl -u firewall-alerts -f   # Ver logs en tiempo real"
