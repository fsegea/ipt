#!/bin/bash
# security-manager.sh - Herramientas para gestionar la seguridad del firewall (Versión IPSet)

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"

# Colores para output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Listas IPSet dinámicas basadas en tus nuevas reglas
SETS_IP="scanners synflooders udpflooders fragattackers"
SETS_NET="scanner_nets"
ALL_SETS="$SETS_IP $SETS_NET"

show_menu() {
    clear
    echo "=========================================="
    echo "🛡️  Security Manager - IPSet Edition"
    echo "=========================================="
    echo ""
    echo "1. 📊 Ver estadísticas de conjuntos IPSet"
    echo "2. 🔍 Ver IPs y Redes bloqueadas"
    echo "3. 🧹 Limpiar un conjunto específico (Flush)"
    echo "4. ❌ Remover IP/Red específica de un conjunto"
    echo "5. ➕ Añadir IP/Red manualmente"
    echo "6. 📈 Ver métricas en tiempo real"
    echo "7. 🧪 Test de protección IPSet"
    echo "8. 📋 Exportar conjuntos a archivo"
    echo "9. 💾 Backup de configuración de IPSet/IPTables"
    echo "0. ❌ Salir"
    echo ""
    echo -n "Selecciona una opción: "
}

# 1. Ver estadísticas
show_stats() {
    echo ""
    echo "=========================================="
    echo "📊 Estadísticas de Conjuntos IPSet"
    echo "=========================================="
    echo ""
    
    for set_name in $ALL_SETS; do
        if ipset list "$set_name" >/dev/null 2>&1; then
            # Contar miembros reales excluyendo las cabeceras
            count=$(ipset list "$set_name" | sed -n '/Members:/,$p' | tail -n +2 | wc -l)
            echo -e "${BLUE}Conjunto: $set_name${NC}"
            echo "  Entradas activas: $count"
            
            if [ "$count" -gt 0 ]; then
                echo "  Primeras 5 entradas:"
                ipset list "$set_name" | sed -n '/Members:/,$p' | tail -n +2 | head -5 | while read -r line; do
                    echo "    • $line"
                done
            fi
            echo ""
        else
            echo -e "${YELLOW}Conjunto '$set_name' no existe en IPSet${NC}"
        fi
    done
    
    echo "Presiona Enter para continuar..."
    read
}

# 2. Ver IPs bloqueadas
show_blocked() {
    echo ""
    echo "=========================================="
    echo "🔍 Elementos Bloqueados Activos"
    echo "=========================================="
    echo ""
    
    for set_name in $ALL_SETS; do
        echo -e "${RED}Conjunto: $set_name${NC}"
        if ipset list "$set_name" >/dev/null 2>&1; then
            count=$(ipset list "$set_name" | sed -n '/Members:/,$p' | tail -n +2 | wc -l)
            if [ "$count" -gt 0 ]; then
                ipset list "$set_name" | sed -n '/Members:/,$p' | tail -n +2 | awk '{print "  " $0}'
            else
                echo "  (ninguno)"
            fi
        else
            echo "  (conjunto no existe)"
        fi
        echo ""
    done
    
    echo "Presiona Enter para continuar..."
    read
}

# 3. Limpiar lista (Flush)
clear_list() {
    echo ""
    echo "Conjuntos disponibles:"
    echo "  1. scanners"
    echo "  2. synflooders"
    echo "  3. udpflooders"
    echo "  4. fragattackers"
    echo "  5. scanner_nets"
    echo "  6. todos"
    echo ""
    echo -n "¿Qué conjunto vaciar? (1-6): "
    read choice
    
    case $choice in
        1) set_name="scanners" ;;
        2) set_name="synflooders" ;;
        3) set_name="udpflooders" ;;
        4) set_name="fragattackers" ;;
        5) set_name="scanner_nets" ;;
        6) set_name="all" ;;
        *) echo "Opción inválida"; return ;;
    esac
    
    if [ "$set_name" = "all" ]; then
        for s in $ALL_SETS; do
            if ipset list "$s" >/dev/null 2>&1; then
                ipset flush "$s"
                echo -e "${GREEN}✓ Conjunto '$s' vaciado (Flush)${NC}"
            fi
        done
    else
        if ipset list "$set_name" >/dev/null 2>&1; then
            ipset flush "$set_name"
            echo -e "${GREEN}✓ Conjunto '$set_name' vaciado (Flush)${NC}"
        else
            echo -e "${RED}✗ El conjunto '$set_name' no existe${NC}"
        fi
    fi
    
    echo ""
    echo "Presiona Enter para continuar..."
    read
}

# 4. Remover IP/Red específica
remove_ip() {
    echo ""
    echo -n "IP o Red a remover (ej: 88.210.63.69 o 104.255.152.0/24): "
    read target
    
    echo "Selecciona el conjunto o escribe 'all':"
    echo "($ALL_SETS)"
    echo -n "Conjunto: "
    read set_choice
    
    if [ "$set_choice" = "all" ]; then
        for s in $ALL_SETS; do
            ipset del "$s" "$target" >/dev/null 2>&1
            if [ $? -eq 0 ]; then
                echo -e "${GREEN}✓ Removido de '$s'${NC}"
            fi
        done
    else
        ipset del "$set_choice" "$target" 2>/dev/null
        if [ $? -eq 0 ]; then
            echo -e "${GREEN}✓ '$target' removido con éxito de $set_choice.${NC}"
        else
            echo -e "${RED}✗ Error al remover o no se encontró en '$set_choice'.${NC}"
        fi
    fi
    
    echo ""
    echo "Presiona Enter para continuar..."
    read
}

# 5. Añadir IP manualmente
add_ip() {
    echo ""
    echo -n "IP o Red a añadir: "
    read target
    
    echo "Conjuntos válidos: $ALL_SETS"
    echo -n "Destino: "
    read set_choice
    
    # Validar si el conjunto existe
    if ipset list "$set_choice" >/dev/null 2>&1; then
        echo -n "Timeout opcional (en segundos, Enter para usar por defecto del set): "
        read user_timeout
        
        if [ -n "$user_timeout" ]; then
            ipset add "$set_choice" "$target" timeout "$user_timeout" 2>/dev/null
        else
            ipset add "$set_choice" "$target" 2>/dev/null
        fi
        
        if [ $? -eq 0 ]; then
            echo -e "${GREEN}✓ Añadido correctamente a '$set_choice'${NC}"
        else
            echo -e "${RED}✗ Error al añadir. Revisa la sintaxis o si ya existe.${NC}"
        fi
    else
        echo -e "${RED}✗ El conjunto '$set_choice' no existe.${NC}"
    fi
    
    echo ""
    echo "Presiona Enter para continuar..."
    read
}

# 6. Métricas en tiempo real
real_time_metrics() {
    echo ""
    echo "=========================================="
    echo "📈 Métricas en Tiempo Real (IPSet)"
    echo "=========================================="
    echo "Presiona Ctrl+C para salir"
    echo ""
    sleep 1
    
    while true; do
        clear
        echo "🕐 $(date '+%Y-%m-%d %H:%M:%S')"
        echo "=========================================="
        
        # Contador de paquetes por regla IPTables que usen ipset
        echo ""
        echo "📦 Paquetes interceptados por IPSet en IPTables:"
        iptables -L -v -n 2>/dev/null | grep -E "match-set|scanners|flooder" | \
            awk '{printf "  %-25s: %10s paquetes\n", $3, $1}'
        
        # Volumen de IPSet
        echo ""
        echo "📋 Elementos en listas IPSet:"
        for s in $ALL_SETS; do
            if ipset list "$s" >/dev/null 2>&1; then
                count=$(ipset list "$s" | sed -n '/Members:/,$p' | tail -n +2 | wc -l)
                printf "  %-20s: %5d elementos\n" "$s" "$count"
            fi
        done
        
        # Eventos del Kernel / Firewall
        echo ""
        echo "🚨 Últimos registros de bloqueo (30s):"
        journalctl -k --no-pager --since "30 seconds ago" 2>/dev/null | \
            grep -E "SCANNER|FLOOD|DROP|REJECT" | tail -5 | \
            awk '{print "  " substr($0, 1, 100)}'
        
        # Servidor
        echo ""
        echo "💻 Recursos:"
        echo "  Load: $(uptime | awk -F'load average:' '{print $2}')"
        echo "  Mem:  $(free -h | grep Mem | awk '{print $3 "/" $2}')"
        
        sleep 5
    done
}

# 7. Test de protección IPSet
test_protection() {
    echo ""
    echo "=========================================="
    echo "🧪 Test de Componentes IPSet"
    echo "=========================================="
    echo ""
    
    # Test 1: Comando disponible
    echo -n "Test 1: Binario ipset instalado... "
    if which ipset >/dev/null 2>&1; then
        echo -e "${GREEN}✓ OK${NC}"
    else
        echo -e "${RED}✗ FAIL (Instala ipset: apt install ipset / yum install ipset)${NC}"
    fi
    
    # Test 2: Existencia de las listas actualizadas
    echo "Test 2: Verificación de conjuntos creados:"
    for s in $ALL_SETS; do
        echo -n "  • Conjunto '$s'... "
        if ipset list "$s" >/dev/null 2>&1; then
            echo -e "${GREEN}✓ OK${NC}"
        else
            echo -e "${YELLOW}⚠ NO DETECTADO${NC}"
        fi
    done
    
    # Test 3: Integración IPTables + IPSet
    echo -n "Test 3: Vinculación con IPTables... "
    if iptables -L -n 2>/dev/null | grep -q "match-set"; then
        echo -e "${GREEN}✓ OK (Existen reglas llamando a conjuntos)${NC}"
    else
        echo -e "${YELLOW}⚠ WARNING (No se ven reglas activas usando match-set)${NC}"
    fi
    
    echo ""
    echo "Presiona Enter para continuar..."
    read
}

# 8. Exportar listas
export_lists() {
    echo ""
    echo "=========================================="
    echo "📋 Exportar Conjuntos IPSet"
    echo "=========================================="
    echo ""
    
    timestamp=$(date +%Y%m%d_%H%M%S)
    export_dir="$PROJECT_DIR/exports"
    mkdir -p "$export_dir"
    
    echo "Exportando datos a: $export_dir"
    echo ""
    
    # Guardar la estructura cruda de IPSet para restauraciones rápidas
    ipset save > "$export_dir/ipset_raw_${timestamp}.set"
    echo -e "${GREEN}✓ Volcado completo estructurado guardado.${NC}"
    
    # Guardar en texto plano limpio para auditoría humana
    for s in $ALL_SETS; do
        if ipset list "$s" >/dev/null 2>&1; then
            output="$export_dir/${s}_clean_${timestamp}.txt"
            ipset list "$s" | sed -n '/Members:/,$p' | tail -n +2 > "$output"
            count=$(wc -l < "$output")
            echo -e "  • $s: $count elementos → $output"
        fi
    done
    
    echo ""
    echo "Presiona Enter para continuar..."
    read
}

# 9. Backup de configuración integral
backup_config() {
    echo ""
    echo "=========================================="
    echo "💾 Backup de Seguridad Completo"
    echo "=========================================="
    echo ""
    
    timestamp=$(date +%Y%m%d_%H%M%S)
    backup_dir="$PROJECT_DIR/backups"
    backup_file="$backup_dir/ipset_iptables_backup_${timestamp}.tar.gz"
    
    mkdir -p "$backup_dir"
    
    echo "Procesando componentes..."
    tmp_dir=$(mktemp -d)
    
    # 1. Volcar IPTables clásico
    iptables-save > "$tmp_dir/iptables.rules"
    ip6tables-save > "$tmp_dir/ip6tables.rules" 2>/dev/null
    
    # 2. Volcar IPSet estructurado (Reglas + Miembros)
    ipset save > "$tmp_dir/ipset.sets"
    
    # 3. Copiar directorio de scripts de control si existe
    if [ -d "$PROJECT_DIR" ]; then
        cp -r "$PROJECT_DIR" "$tmp_dir/scripts"
    fi
    
    # empaquetar todo
    tar -czf "$backup_file" -C "$tmp_dir" .
    rm -rf "$tmp_dir"
    
    size=$(du -h "$backup_file" | awk '{print $1}')
    echo -e "${GREEN}✓ Copia de seguridad consolidada: $backup_file ($size)${NC}"
    echo ""
    
    # Limpieza inteligente automática
    backup_count=$(ls -1 "$backup_dir"/*.tar.gz 2>/dev/null | wc -l)
    if [ "$backup_count" -gt 10 ]; then
        echo -e "${YELLOW}⚠ Se encontraron $backup_count backups almacenados.${NC}"
        echo -n "¿Quieres purgar los que tengan más de 30 días? (s/n): "
        read cleanup
        if [ "$cleanup" = "s" ]; then
            find "$backup_dir" -name "*.tar.gz" -mtime +30 -delete
            echo -e "${GREEN}✓ Backups obsoletos purgados.${NC}"
        fi
    fi
    
    echo ""
    echo "Presiona Enter para continuar..."
    read
}

# Menú principal
main() {
    while true; do
        show_menu
        read -r option
        
        case $option in
            1) show_stats ;;
            2) show_blocked ;;
            3) clear_list ;;
            4) remove_ip ;;
            5) add_ip ;;
            6) real_time_metrics ;;
            7) test_protection ;;
            8) export_lists ;;
            9) backup_config ;;
            0) echo ""; echo "👋 ¡Protección activa! Saliendo del gestor."; exit 0 ;;
            *) echo "Opción no válida"; sleep 1 ;;
        esac
    done
}

# Forzar Root
if [ "$EUID" -ne 0 ]; then
    echo "❌ Error extremo: Este panel requiere privilegios administrativos (root)"
    exit 1
fi

# Iniciar Loop
main
