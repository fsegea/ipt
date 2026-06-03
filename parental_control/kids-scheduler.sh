#!/bin/bash
# kids-scheduler.sh - Instalador y gestor de horarios de control parental
# Compatible con systemd/journalctl

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
CONFIG_FILE="$PROJECT_DIR/config/config.sh"
CRON_FILE="/etc/cron.d/firewall-kids-control"
source "$PROJECT_DIR/config/config.sh" 

# Colores
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'


# ============================================
# FUNCIÓN: GUARDAR PARÁMETROS EN CONFIG.SH
# ============================================
save_schedule_to_config() {
    local days_cron="$1"
    local days_desc="$2"
    local hour_start="$3"
    local min_start="$4"
    local hour_end="$5"
    local min_end="$6"

    # Actualizar o añadir cada variable en config.sh usando sed
    update_config_var() {
        local key="$1"
        local value="$2"
        if grep -q "^${key}=" "$CONFIG_FILE"; then
            sed -i "s|^${key}=.*|${key}=\"${value}\"|" "$CONFIG_FILE"
        else
            echo "${key}=\"${value}\"" >> "$CONFIG_FILE"
        fi
    }

    update_config_var "DAYS_CRON"         "$days_cron"
    update_config_var "DAYS_DESC"         "$days_desc"
    update_config_var "BLOCK_HOUR_START"  "$hour_start"
    update_config_var "BLOCK_MIN_START"   "$min_start"
    update_config_var "BLOCK_HOUR_END"    "$hour_end"
    update_config_var "BLOCK_MIN_END"     "$min_end"

    echo -e "${GREEN}✅ Configuración guardada en $CONFIG_FILE${NC}"
}

# ============================================
# FUNCIÓN: MOSTRAR IPs de kids
# ============================================
show_kids_ips() {
    echo -e "${CYAN}Dispositivos afectados:${NC}"
    for IP in $KIDS_IPS; do
        case "$IP" in
            10.10.0.62) NAME="iPad_MA" ;;
            10.10.0.13) NAME="Medion_Windows" ;;
            *)          NAME="Desconocido" ;;
        esac
        echo "  • $IP - $NAME"
    done
}

# ============================================
# FUNCIÓN: MENÚ PRINCIPAL
# ============================================
show_main_menu() {
    echo ""
    echo "Opciones:"
    echo "  1. ⚙️  Configurar horario automático"
    echo "  2. 📋 Ver configuración actual"
    echo "  3. ✅ Activar automatización (instalar en cron)"
    echo "  4. ⏸️  Pausar automatización"
    echo "  5. ❌ Desactivar automatización (eliminar de cron)"
    echo "  6. 🔓 Desbloquear ahora (manual)"
    echo "  7. 🔒 Bloquear ahora (manual)"
    echo "  8. 📊 Ver estado actual"
    echo "  9. 📝 Ver logs de cambios"
    echo "  0. 🚪 Salir"
    echo ""
    echo -n "Selecciona opción: "
}

# ============================================
# FUNCIÓN: CONFIGURAR HORARIO
# ============================================
configure_schedule() {
    clear
    echo "=========================================="
    echo "⚙️  Configuración de Horarios"
    echo "=========================================="
    echo ""
    echo "Configuración actual:"
    echo "  📅 Días: $DAYS_DESC"
    echo "  🔒 Bloqueo: ${BLOCK_HOUR_START}:${BLOCK_MIN_START} - ${BLOCK_HOUR_END}:${BLOCK_MIN_END}"
    echo ""
    echo "¿Qué días quieres aplicar el bloqueo?"
    echo "  1. Solo días laborables (Lunes-Viernes)"
    echo "  2. Todos los días (Lunes-Domingo)"
    echo "  3. Personalizado"
    echo ""
    echo -n "Opción (1-3): "
    read days_option

    case $days_option in
        1) NEW_DAYS_CRON="1-5"; NEW_DAYS_DESC="Lunes a Viernes" ;;
        2) NEW_DAYS_CRON="0-6"; NEW_DAYS_DESC="Todos los días" ;;
        3)
            echo ""
            echo "Días (0=Domingo, 1=Lunes, ... 6=Sábado)"
            echo "Ejemplos: 1,2,3,4,5  o  1-5  o  0,6"
            echo -n "Ingresa días: "
            read NEW_DAYS_CRON
            NEW_DAYS_DESC="Días personalizados: $NEW_DAYS_CRON"
            ;;
        *)
            echo "Opción inválida, manteniendo configuración actual"
            NEW_DAYS_CRON="$DAYS_CRON"
            NEW_DAYS_DESC="$DAYS_DESC"
            ;;
    esac

    echo ""
    echo "=========================================="
    echo "🕐 Horario de BLOQUEO"
    echo "=========================================="
    echo ""
    echo "Ejemplos comunes:"
    echo "  • Horario escolar: 08:00 - 16:00"
    echo "  • Horario de estudio: 19:00 - 21:00"
    echo "  • Noche: 22:00 - 07:00"
    echo ""

    echo -n "Hora de inicio del bloqueo (actual: $BLOCK_HOUR_START, formato 24h): "
    read NEW_HOUR_START
    NEW_HOUR_START="${NEW_HOUR_START:-$BLOCK_HOUR_START}"

    echo -n "Minuto de inicio (actual: $BLOCK_MIN_START, 00-59): "
    read NEW_MIN_START
    NEW_MIN_START="${NEW_MIN_START:-$BLOCK_MIN_START}"

    echo -n "Hora de fin del bloqueo (actual: $BLOCK_HOUR_END, formato 24h): "
    read NEW_HOUR_END
    NEW_HOUR_END="${NEW_HOUR_END:-$BLOCK_HOUR_END}"

    echo -n "Minuto de fin (actual: $BLOCK_MIN_END, 00-59): "
    read NEW_MIN_END
    NEW_MIN_END="${NEW_MIN_END:-$BLOCK_MIN_END}"

    # Validar
    local valid=1
    for val in "$NEW_HOUR_START" "$NEW_HOUR_END"; do
        if ! [[ "$val" =~ ^[0-9]{1,2}$ ]] || [ "$val" -gt 23 ]; then
            echo -e "${RED}❌ Hora inválida: $val${NC}"; valid=0; fi
    done
    for val in "$NEW_MIN_START" "$NEW_MIN_END"; do
        if ! [[ "$val" =~ ^[0-9]{1,2}$ ]] || [ "$val" -gt 59 ]; then
            echo -e "${RED}❌ Minuto inválido: $val${NC}"; valid=0; fi
    done

    if [ "$valid" -eq 0 ]; then
        echo "Configuración no guardada por errores de validación."
        read -p "Presiona Enter para continuar..."
        return
    fi

    save_schedule_to_config "$NEW_DAYS_CRON" "$NEW_DAYS_DESC" \
        "$NEW_HOUR_START" "$NEW_MIN_START" \
        "$NEW_HOUR_END"   "$NEW_MIN_END"

    # Recargar config para reflejar cambios en sesión actual
    load_config

    echo ""
    echo -e "${GREEN}Horario configurado:${NC}"
    echo "  📅 Días: $DAYS_DESC"
    echo "  🔒 Bloqueo: ${BLOCK_HOUR_START}:${BLOCK_MIN_START} - ${BLOCK_HOUR_END}:${BLOCK_MIN_END}"
    echo ""
    echo -e "${CYAN}💡 Siguiente paso:${NC} Usa la opción 3 para activar la automatización"
    echo ""
    read -p "Presiona Enter para continuar..."
}

# ============================================
# FUNCIÓN: VER CONFIGURACIÓN ACTUAL
# ============================================
view_config() {
    clear
    echo "=========================================="
    echo "📋 Configuración Actual"
    echo "=========================================="
    echo ""
    echo -e "${BLUE}Fichero:${NC} $CONFIG_FILE"
    echo ""
    echo -e "${BLUE}Horario configurado:${NC}"
    echo "  📅 Días: $DAYS_DESC"
    echo "  🔒 Bloqueo: ${BLOCK_HOUR_START}:${BLOCK_MIN_START} - ${BLOCK_HOUR_END}:${BLOCK_MIN_END}"
    echo ""
    show_kids_ips
    echo ""

    if [ -f "$CRON_FILE" ]; then
        echo -e "${GREEN}Estado: ✅ ACTIVO en cron${NC}"
        echo ""
        echo "Entradas en crontab:"
        grep -v "^#" "$CRON_FILE"
    elif [ -f "${CRON_FILE}.paused" ]; then
        echo -e "${YELLOW}Estado: ⏸️  PAUSADO${NC}"
    else
        echo -e "${YELLOW}Estado: ❌ NO ACTIVO${NC}"
        echo "Usa la opción 3 para activar"
    fi

    echo ""
    read -p "Presiona Enter para continuar..."
}

# ============================================
# FUNCIÓN: ACTIVAR AUTOMATIZACIÓN
# ============================================
activate_automation() {
    clear
    echo "=========================================="
    echo "✅ Activar Automatización"
    echo "=========================================="
    echo ""

    cat > "$CRON_FILE" <<EOF
# Control parental automático - Firewall
# Generado: $(date)
# Días: $DAYS_DESC
# Bloqueo: ${BLOCK_HOUR_START}:${BLOCK_MIN_START} - ${BLOCK_HOUR_END}:${BLOCK_MIN_END}
# Logs: journalctl -t kids-control

# Bloquear (inicio del período de restricción)
${BLOCK_MIN_START} ${BLOCK_HOUR_START} * * ${DAYS_CRON} root ${SCRIPT_DIR}/kids_block.sh 2>&1 | logger -t kids-control

# Desbloquear (fin del período de restricción)
${BLOCK_MIN_END} ${BLOCK_HOUR_END} * * ${DAYS_CRON} root ${SCRIPT_DIR}/kids_unblock.sh 2>&1 | logger -t kids-control
EOF

    chmod 644 "$CRON_FILE"
    systemctl reload cron 2>/dev/null || service cron reload 2>/dev/null

    echo -e "${GREEN}✅ Automatización ACTIVADA${NC}"
    echo ""
    echo "  📅 Días: $DAYS_DESC"
    echo "  🔒 Bloquea a las: ${BLOCK_HOUR_START}:${BLOCK_MIN_START}"
    echo "  🔓 Desbloquea a las: ${BLOCK_HOUR_END}:${BLOCK_MIN_END}"
    echo ""
    echo -e "${CYAN}📝 Ver logs con:${NC}"
    echo "  journalctl -t kids-control -f"
    echo "  journalctl -t kids-control --since today"
    echo ""
    read -p "Presiona Enter para continuar..."
}

# ============================================
# FUNCIÓN: PAUSAR AUTOMATIZACIÓN
# ============================================
pause_automation() {
    clear
    echo "=========================================="
    echo "⏸️  Pausar Automatización"
    echo "=========================================="
    echo ""

    if [ ! -f "$CRON_FILE" ]; then
        echo -e "${YELLOW}⚠️  La automatización no está activa${NC}"
        echo ""
        read -p "Presiona Enter para continuar..."
        return
    fi

    mv "$CRON_FILE" "${CRON_FILE}.paused"
    systemctl reload cron 2>/dev/null || service cron reload 2>/dev/null

    echo -e "${YELLOW}⏸️  Automatización PAUSADA${NC}"
    echo ""
    echo "El estado actual del firewall NO ha cambiado."
    echo "Usa la opción 3 para reactivar."
    echo ""
    read -p "Presiona Enter para continuar..."
}

# ============================================
# FUNCIÓN: DESACTIVAR AUTOMATIZACIÓN
# ============================================
deactivate_automation() {
    clear
    echo "=========================================="
    echo "❌ Desactivar Automatización"
    echo "=========================================="
    echo ""

    if [ ! -f "$CRON_FILE" ] && [ ! -f "${CRON_FILE}.paused" ]; then
        echo -e "${YELLOW}⚠️  No hay automatización activa${NC}"
        echo ""
        read -p "Presiona Enter para continuar..."
        return
    fi

    echo -e "${YELLOW}⚠️  ADVERTENCIA${NC}"
    echo "Esto eliminará las tareas programadas."
    echo "La configuración en config.sh se mantendrá."
    echo ""
    echo -n "¿Confirmar desactivación? (s/n): "
    read confirm

    if [ "$confirm" != "s" ] && [ "$confirm" != "S" ]; then
        echo "Cancelado"
        sleep 1
        return
    fi

    rm -f "$CRON_FILE" "${CRON_FILE}.paused"
    systemctl reload cron 2>/dev/null || service cron reload 2>/dev/null

    echo -e "${GREEN}✅ Automatización desactivada${NC}"
    echo ""
    echo "El estado actual del firewall NO ha cambiado."
    echo ""
    read -p "Presiona Enter para continuar..."
}

# ============================================
# FUNCIÓN: DESBLOQUEAR MANUALMENTE
# ============================================
manual_unblock() {
    clear
    echo "=========================================="
    echo "🔓 Desbloqueo Manual"
    echo "=========================================="
    echo ""

    if [ ! -f "$SCRIPT_DIR/kids_unblock.sh" ]; then
        echo -e "${RED}❌ Error: Script kids_unblock.sh no encontrado${NC}"
        sleep 2
        return
    fi

    bash "$SCRIPT_DIR/kids_unblock.sh" 2>&1 | logger -t kids-control-manual

    echo -e "${GREEN}✅ Dispositivos desbloqueados${NC}"
    echo ""
    show_kids_ips
    echo ""

    if $IPT -L KIDS_ACCESS -n 2>/dev/null | grep -qE "RETURN|ACCEPT"; then
        echo -e "${GREEN}Verificado: acceso permitido${NC}"
    else
        echo -e "${YELLOW}⚠️  No se pudo verificar el estado${NC}"
    fi

    echo ""
    echo -e "${CYAN}Registro guardado en journald (tag: kids-control-manual)${NC}"
    echo ""
    read -p "Presiona Enter para continuar..."
}

# ============================================
# FUNCIÓN: BLOQUEAR MANUALMENTE
# ============================================
manual_block() {
    clear
    echo "=========================================="
    echo "🔒 Bloqueo Manual"
    echo "=========================================="
    echo ""

    if [ ! -f "$SCRIPT_DIR/kids_block.sh" ]; then
        echo -e "${RED}❌ Error: Script kids_block.sh no encontrado${NC}"
        sleep 2
        return
    fi

    bash "$SCRIPT_DIR/kids_block.sh" 2>&1 | logger -t kids-control-manual

    echo -e "${RED}🔒 Dispositivos bloqueados${NC}"
    echo ""
    show_kids_ips
    echo ""

    if $IPT -L KIDS_ACCESS -n 2>/dev/null | grep -q "DROP"; then
        echo -e "${GREEN}Verificado: acceso bloqueado${NC}"
    else
        echo -e "${YELLOW}⚠️  No se pudo verificar el estado${NC}"
    fi

    echo ""
    echo -e "${CYAN}Registro guardado en journald (tag: kids-control-manual)${NC}"
    echo ""
    read -p "Presiona Enter para continuar..."
}

# ============================================
# FUNCIÓN: VER ESTADO ACTUAL
# ============================================
view_status() {
    clear
    echo "=========================================="
    echo "📊 Estado Actual del Control Parental"
    echo "=========================================="
    echo ""

    echo -e "${CYAN}Estado del Firewall:${NC}"
    if $IPT -L KIDS_ACCESS -n 2>/dev/null | grep -q "DROP"; then
        echo -e "  ${RED}🔒 BLOQUEADO${NC} - Los dispositivos NO tienen acceso"
    elif $IPT -L KIDS_ACCESS -n 2>/dev/null | grep -qE "RETURN|ACCEPT"; then
        echo -e "  ${GREEN}🔓 PERMITIDO${NC} - Los dispositivos tienen acceso"
    else
        echo -e "  ${YELLOW}⚠️  Estado desconocido${NC}"
    fi

    echo ""
    echo -e "${CYAN}Reglas activas (KIDS_ACCESS):${NC}"
    $IPT -L KIDS_ACCESS -nv --line-numbers 2>/dev/null | head -10

    echo ""
    echo -e "${CYAN}Dispositivos monitorizados:${NC}"
    $IPT -L FORWARD -nv 2>/dev/null | grep "KIDS_ACCESS" | while read line; do
        ip=$(echo "$line" | grep -oP '10\.10\.0\.\d+')
        pkts=$(echo "$line" | awk '{print $1}')
        bytes=$(echo "$line" | awk '{print $2}')
        echo "  • IP: $ip - Paquetes: $pkts - Bytes: $bytes"
    done

    echo ""
    echo -e "${CYAN}Estado de automatización:${NC}"
    if [ -f "$CRON_FILE" ]; then
        echo -e "  ${GREEN}✅ ACTIVA${NC}"
        echo "  Horario: ${BLOCK_HOUR_START}:${BLOCK_MIN_START} - ${BLOCK_HOUR_END}:${BLOCK_MIN_END}"
        echo "  Días: $DAYS_DESC"
    elif [ -f "${CRON_FILE}.paused" ]; then
        echo -e "  ${YELLOW}⏸️  PAUSADA${NC}"
    else
        echo -e "  ${YELLOW}❌ INACTIVA${NC}"
    fi

    echo ""
    read -p "Presiona Enter para continuar..."
}

# ============================================
# FUNCIÓN: VER LOGS
# ============================================
view_logs() {
    clear
    echo "=========================================="
    echo "📝 Logs de Control Parental (journald)"
    echo "=========================================="
    echo ""
    echo -e "${CYAN}Selecciona qué logs ver:${NC}"
    echo "  1. Últimas 20 entradas (automáticas)"
    echo "  2. Últimas 20 entradas (manuales)"
    echo "  3. Últimas 20 entradas (todas)"
    echo "  4. Logs de hoy"
    echo "  5. Logs de última hora"
    echo "  6. Logs en tiempo real (Ctrl+C para salir)"
    echo ""
    echo -n "Opción (1-6): "
    read log_option

    case $log_option in
        1) journalctl -t kids-control -n 20 --no-pager ;;
        2) journalctl -t kids-control-manual -n 20 --no-pager ;;
        3) journalctl -t kids-control -t kids-control-manual -n 20 --no-pager ;;
        4) journalctl -t kids-control -t kids-control-manual --since today --no-pager ;;
        5) journalctl -t kids-control -t kids-control-manual --since "1 hour ago" --no-pager ;;
        6) journalctl -t kids-control -t kids-control-manual -f ;;
        *) echo "Opción inválida"; sleep 1; return ;;
    esac

    echo ""
    read -p "Presiona Enter para continuar..."
}

# ============================================
# MAIN
# ============================================
main() {
    if [ "$EUID" -ne 0 ]; then
        echo -e "${RED}❌ Este script debe ejecutarse como root${NC}"
        exit 1
    fi

    if [ ! -f "$SCRIPT_DIR/kids_block.sh" ] || [ ! -f "$SCRIPT_DIR/kids_unblock.sh" ]; then
        echo -e "${RED}❌ Error: Scripts kids_block.sh o kids_unblock.sh no encontrados en $SCRIPT_DIR${NC}"
        exit 1
    fi


    while true; do
        clear
        echo "=========================================="
        echo "🎓 Control Parental Automático"
        echo "=========================================="
        echo ""

        if $IPT -L KIDS_ACCESS -n 2>/dev/null | grep -q "DROP"; then
            echo -e "Estado actual: ${RED}🔒 BLOQUEADO${NC}"
        elif $IPT -L KIDS_ACCESS -n 2>/dev/null | grep -qE "RETURN|ACCEPT"; then
            echo -e "Estado actual: ${GREEN}🔓 PERMITIDO${NC}"
        else
            echo -e "Estado actual: ${YELLOW}⚠️  DESCONOCIDO${NC}"
        fi

        if [ -f "$CRON_FILE" ]; then
            echo -e "Automatización: ${GREEN}✅ ACTIVA${NC} (${BLOCK_HOUR_START}:${BLOCK_MIN_START} - ${BLOCK_HOUR_END}:${BLOCK_MIN_END})"
        elif [ -f "${CRON_FILE}.paused" ]; then
            echo -e "Automatización: ${YELLOW}⏸️  PAUSADA${NC}"
        else
            echo -e "Automatización: ${YELLOW}❌ INACTIVA${NC}"
        fi

        show_main_menu
        read option

        case $option in
            1) configure_schedule ;;
            2) view_config ;;
            3) activate_automation ;;
            4) pause_automation ;;
            5) deactivate_automation ;;
            6) manual_unblock ;;
            7) manual_block ;;
            8) view_status ;;
            9) view_logs ;;
            0) echo ""; echo "👋 ¡Hasta luego!"; exit 0 ;;
            *) echo "Opción inválida"; sleep 1 ;;
        esac
    done
}

main