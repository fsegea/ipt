#!/bin/bash
# Script: install-firewall-service.sh
# Instala el firewall personalizado como servicio systemd

# Colores
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Rutas dinámicas
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
FIREWALL_SCRIPT="$PROJECT_DIR/core/main.sh"
SERVICE_FILE="/etc/systemd/system/firewall.service"
SERVICE_NAME="firewall"

# Validaciones previas
if [ "$EUID" -ne 0 ]; then
    echo -e "${RED}❌ Este script debe ejecutarse como root${NC}"
    exit 1
fi

if [ ! -f "$FIREWALL_SCRIPT" ]; then
    echo -e "${RED}❌ Error: Script principal no encontrado en $FIREWALL_SCRIPT${NC}"
    exit 1
fi

# Función para mostrar el menú
show_menu() {
    clear
    echo "=========================================="
    echo -e "${BLUE}🔧 Instalador de Servicio Firewall${NC}"
    echo "=========================================="
    echo ""
    echo "Ubicación del script: $FIREWALL_SCRIPT"
    echo "Servicio systemd: $SERVICE_FILE"
    echo ""
    echo "Elige el tipo de servicio:"
    echo ""
    echo "1. 🚀 Oneshot (ejecuta una sola vez al arrancar)"
    echo "   - Descripción: El firewall se inicializa al boot"
    echo "   - RemainAfterExit=yes (permanece 'activo' después)"
    echo "   - Recomendado: ✅ Para firewalls estándar"
    echo ""
    echo "2. 🔄 Continuous (siempre activo con reintentos)"
    echo "   - Descripción: Intenta ejecutar de forma continua"
    echo "   - Restart=always (reinicia si falla)"
    echo "   - Recomendado: Para daemons de monitoreo"
    echo ""
    echo "3. 📋 Ver configuración actual"
    echo "4. ❌ Salir"
    echo ""
    echo -n "Selecciona una opción (1-4): "
}

# Función para instalar servicio Oneshot
install_oneshot() {
    echo ""
    echo -e "${YELLOW}⚠️  Instalando servicio Oneshot...${NC}"
    echo ""
    
    cat > "$SERVICE_FILE" <<SERVICEEOF
[Unit]
Description=Firewall personalizado
After=network-online.target
Wants=network-online.target

[Service]
Type=oneshot
WorkingDirectory=$PROJECT_DIR
ExecStart=$FIREWALL_SCRIPT
RemainAfterExit=yes

[Install]
WantedBy=multi-user.target
SERVICEEOF

    echo -e "${GREEN}✅ Archivo de servicio creado${NC}"
    enable_and_start_service
}

# Función para instalar servicio Continuous
install_continuous() {
    echo ""
    echo -e "${YELLOW}⚠️  Instalando servicio Continuous...${NC}"
    echo ""
    
    cat > "$SERVICE_FILE" <<SERVICEEOF
[Unit]
Description=Firewall personalizado
After=network-online.target
Wants=network-online.target

[Service]
Type=simple
WorkingDirectory=$PROJECT_DIR
ExecStart=$FIREWALL_SCRIPT
Restart=always
RestartSec=10
StandardOutput=journal
StandardError=journal
SyslogIdentifier=$SERVICE_NAME

[Install]
WantedBy=multi-user.target
SERVICEEOF

    echo -e "${GREEN}✅ Archivo de servicio creado${NC}"
    enable_and_start_service
}

# Función para habilitar e iniciar el servicio
enable_and_start_service() {
    echo ""
    echo -e "${BLUE}Recargando configuración de systemd...${NC}"
    systemctl daemon-reload
    
    if systemctl enable "$SERVICE_NAME.service" 2>/dev/null; then
        echo -e "${GREEN}✅ Servicio habilitado para arranque automático${NC}"
    else
        echo -e "${RED}❌ Error al habilitar el servicio${NC}"
        return 1
    fi
    
    echo ""
    echo -e "${BLUE}Iniciando servicio...${NC}"
    if systemctl start "$SERVICE_NAME.service" 2>/dev/null; then
        echo -e "${GREEN}✅ Servicio iniciado correctamente${NC}"
    else
        echo -e "${RED}❌ Error al iniciar el servicio${NC}"
        return 1
    fi
    
    # Verificar estado
    echo ""
    echo -e "${BLUE}Estado del servicio:${NC}"
    systemctl status "$SERVICE_NAME.service" --no-pager
    
    # Mostrar instrucciones
    show_usage_instructions
}

# Función para mostrar la configuración actual
view_current_config() {
    echo ""
    echo "=========================================="
    echo -e "${BLUE}📋 Configuración Actual${NC}"
    echo "=========================================="
    echo ""
    
    if [ ! -f "$SERVICE_FILE" ]; then
        echo -e "${YELLOW}⚠️  No hay servicio instalado${NC}"
        read -p "Presiona Enter para continuar..."
        return
    fi
    
    echo -e "${CYAN}Contenido de $SERVICE_FILE:${NC}"
    echo ""
    cat "$SERVICE_FILE"
    echo ""
    echo -e "${CYAN}Estado actual:${NC}"
    systemctl status "$SERVICE_NAME.service" --no-pager 2>/dev/null || echo "Servicio no está corriendo"
    echo ""
    echo -e "${CYAN}Logs recientes:${NC}"
    journalctl -u "$SERVICE_NAME.service" -n 10 --no-pager 2>/dev/null || echo "Sin logs disponibles"
    echo ""
    read -p "Presiona Enter para continuar..."
}

# Función para mostrar instrucciones de uso
show_usage_instructions() {
    echo ""
    echo "=========================================="
    echo -e "${GREEN}✅ Instalación Completada${NC}"
    echo "=========================================="
    echo ""
    echo -e "${CYAN}Comandos útiles:${NC}"
    echo ""
    echo "  🔍 Ver estado:"
    echo "    systemctl status firewall"
    echo ""
    echo "  📝 Ver logs en tiempo real:"
    echo "    journalctl -u firewall -f"
    echo ""
    echo "  📋 Ver últimos 50 registros:"
    echo "    journalctl -u firewall -n 50 --no-pager"
    echo ""
    echo "  🔄 Reiniciar servicio:"
    echo "    systemctl restart firewall"
    echo ""
    echo "  ⏹️  Detener servicio:"
    echo "    systemctl stop firewall"
    echo ""
    echo "  ▶️  Iniciar servicio:"
    echo "    systemctl start firewall"
    echo ""
    echo "  ⚙️  Habilitar/Deshabilitar arranque automático:"
    echo "    systemctl enable firewall    # Habilitar"
    echo "    systemctl disable firewall   # Deshabilitar"
    echo ""
    echo "  🔧 Ver configuración del servicio:"
    echo "    systemctl cat firewall"
    echo ""
    echo "  🧪 Probar configuración:"
    echo "    $FIREWALL_SCRIPT --help"
    echo ""
    read -p "Presiona Enter para salir..."
}

# Función para desinstalar
uninstall_service() {
    echo ""
    echo -e "${YELLOW}⚠️  DESINSTALACIÓN${NC}"
    echo ""
    echo "Esto eliminará el servicio systemd pero NO afectará la configuración del firewall."
    echo -n "¿Estás seguro? (s/n): "
    read confirm
    
    if [ "$confirm" = "s" ] || [ "$confirm" = "S" ]; then
        echo ""
        echo "Deteniendo servicio..."
        systemctl stop "$SERVICE_NAME.service" 2>/dev/null
        
        echo "Deshabilitando servicio..."
        systemctl disable "$SERVICE_NAME.service" 2>/dev/null
        
        echo "Eliminando archivo..."
        rm -f "$SERVICE_FILE"
        
        systemctl daemon-reload
        
        echo -e "${GREEN}✅ Servicio desinstalado${NC}"
    else
        echo "Cancelado"
    fi
    
    read -p "Presiona Enter para continuar..."
}

# Menú principal
main() {
    while true; do
        show_menu
        read option
        
        case $option in
            1) install_oneshot ;;
            2) install_continuous ;;
            3) view_current_config ;;
            4) echo ""; echo -e "${GREEN}👋 Hasta luego!${NC}"; exit 0 ;;
            *)
                echo -e "${RED}Opción no válida${NC}"
                sleep 1
                ;;
        esac
    done
}

# Ejecutar menú principal
main
