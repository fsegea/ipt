# ipt — Firewall Modular para Linux

> Sistema de firewall avanzado basado en iptables/netfilter con detección de amenazas, control parental y monitoreo en tiempo real.

---

## 📋 Descripción

`ipt` es un proyecto de firewall modular diseñado para servidores linux que requieren protección de red avanzada.

Yo lo empleo dentro de una maquina virtual que practicamente es lo único que hace.

### Características Principales

| Categoría | Descripción |
|-----------|-------------|
| **Monitoreo** | Detección de escáneres, ataques SYN/UDP flood, fragmentación maliciosa |
| **ACLs** | Control granular por IP, MAC y puertos en LAN/WAN |
| **Control Parental** | Bloqueo programable de dispositivos infantiles |
| **Reportes** | Alertas por email y reportes diarios automáticos |
| **Gestión** | Herramientas CLI para administración en tiempo real |

---

## 📁 Estructura del Proyecto

```
ipt/
├── acl/              # Listas de Control de Acceso
│   ├── lan_acl_ip_allow.sh     # Whitelist de IPs privilegiadas
│   ├── lan_acl_mac_drop.sh    # Bloqueo por MAC
│   ├── lan_acl_port_allow.sh   # Permisos de puertos
│   ├── lan_acl_port_drop.sh   # Bloqueo de puertos
│   ├── output_ilan_acl_allow.sh # Reglas de salida LAN
│   ├── output_ilan_iot_acl_allow.sh # Reglas de salida IoT
│   ├── output_iwan_acl_allow.sh    # Reglas de salida WAN
│   └── wan_acl_alexa_allow.sh      # Reglas específicas para Alexa
│
├── config/           # Configuración central
│   ├── config.sh               # Variables de red e interfaces
│   ├── config.sh.example       # Plantilla de configuración
│   ├── es-aggregated.zone       # Configuración de zonas
│   └── firewall_email_config.example # Plantilla email
│
├── core/             # Módulo principal
│   └── main.sh         # Inicialización del firewall
│
├── ip_management/    # Gestión manual de IPs
│   ├── block_ip.sh         # Bloqueo manual (24h)
│   ├── clear_scanners.sh   # Limpieza de blocklist
│   ├── list_blocked.sh     # Listado de bloqueados
│   ├── unblock_ip.sh      # Desbloqueo manual
│   └── whitelist_ip.sh     # Whitelist permanente
│
├── monitoring/       # Detección y alertas
│   ├── alert_monitor.sh    # Motor IDS/IPS en tiempo real
│   ├── analyze_scanners.sh # Análisis de patrones
│   ├── arpwatch_monitor.sh # Monitoreo ARP
│   ├── daily_security_report.sh # Reportes diarios
│   ├── email_alert.sh      # Notificaciones por email
│   └── monitor_security.sh # Dashboard interactivo
│
├── parental_control/  # Control parental
│   ├── kids_access.sh     # Carga de IPs infantiles
│   ├── kids_block.sh       # Bloqueo inmediato
│   ├── kids_unblock.sh     # Desbloqueo restringido
│   ├── kids_unblock_total.sh # Desbloqueo total
│   └── kids-scheduler.sh   # Programación automática
│
├── rules/            # Reglas de filtrado
│   ├── input_lan_services.sh  # Servicios LAN permitidos
│   ├── input_security.sh      # Capas de protección (7-layer)
│   ├── input_wan_services.sh    # Política WAN por defecto
│   ├── port_forward.sh        # Redirección de puertos (DNAT)
│   └── port_redirect.sh       # NAT configurado
│
└── utils/            # Herramientas de mantenimiento
    ├── install-alert-service.sh # Instalación systemd
    ├── install-firewall-service.sh # Instalación service
    └── security-manager.sh      # Gestión interactiva de IPSet
```

---

## 🚀 Instalación Rápida

### 1. Clonar el repositorio

```bash
cd /ruta/deseada/
git clone https://github.com/fsegea/ipt.git
cd ipt
```

### 2. Configurar variables de red

Edita `config/config.sh`:

```bash
# Interfaces de red
IWAN="eth0"      # WAN / Internet
ILAN="eth1"     # LAN principal
ILAN_IOT="eth2"  # LAN IoT

# Servidores DNS
DNS_SERVER1="1.1.1.3"
DNS_SERVER2="1.0.0.3"

# IPs privilegiadas (acceso completo a WAN)
PRIVILEGED_IPS="10.10.0.15 10.10.0.43"
```

### 3. Configurar email (opcional)

Crea `config/.firewall_email_config`:

```bash
EMAIL_FROM="firewall@localhost"
EMAIL_TO="admin@tu-dominio.com"
SMTP_SERVER="smtp.tu-proveedor.com"
SMTP_PORT="587"
EMAIL_USER="tu-usuario@tu-proveedor.com"
EMAIL_PASS="tu-contraseña-o-token"
```

### 4. Inicializar el firewall

```bash
sudo ./core/main.sh
```

---

## 📖 Uso

### Inicialización Manual

```bash
# Cargar todas las reglas del firewall
sudo ./core/main.sh
```

### Monitoreo en Tiempo Real

```bash
# Dashboard interactivo (actualiza cada 10s)
sudo ./monitoring/monitor_security.sh
```

### Gestión de IPs

```bash
# Bloquear IP manualmente por 24 horas
sudo ./ip_management/block_ip.sh <IP>

# Añadir IP a whitelist permanente
sudo ./ip_management/whitelist_ip.sh <IP>

# Ver IPs bloqueadas
sudo ./ip_management/list_blocked.sh
```

### Control Parental

```bash
# Bloquear internet para dispositivos infantiles
sudo ./parental_control/kids_block.sh

# Programar horarios automáticos
sudo ./parental_control/kids-scheduler.sh
```

---

## 🔧 Configuración Avanzada

### IPSet (Bloqueo Dinámico)

El sistema utiliza `ipset` para bloqueo eficiente:

| Nombre | Tipo | Timeout | Uso |
|--------|------|---------|-----|
| `scanners` | hash:ip | 3600s | Escáneres detectados |
| `scanner_nets` | hash:net | 86400s | Subnets problemáticas |
| `synflooders` | hash:ip | 3600s | Ataques SYN flood |
| `udpflooders` | hash:ip | 3600s | Ataques UDP flood |
| `fragattackers` | hash:ip | 3600s | Ataques de fragmentación |

### Servicios Permitidos (INPUT_LAN_SERVICES)

```bash
# SSH (22) - Administración remota
# DHCP (67/68) - Asignación de IPs
# DNS (53) - Resolución de nombres
# ICMP (8) - Diagnostics (ping)
# NTP (123) - Sincronización de hora
# VRRP (112) - Redundancia de router
```

---

## 🐛 Solución de Problemas

### Firewall no inicia correctamente

1. Verifica que `iptables` esté instalado:
   ```bash
   which iptables
   ```

2. Revisa los logs del sistema:
   ```bash
   journalctl -u firewall-alerts.service --no-pager
   ```

3. Comprueba que `ipset` esté disponible:
   ```bash
   ipset list
   ```

### Alertas de email no se envían

- Verifica las credenciales en `config/.firewall_email_config`
- Prueba el servidor SMTP manualmente:
  ```bash
  telnet smtp.tu-proveedor.com 587
  ```

### Reglas no se aplican

- Asegúrate de ejecutar `main.sh` con `sudo`
- Verifica que no haya conflictos con reglas del sistema existentes

---

## 📄 Licencia

Este proyecto es software libre. Utiliza las reglas de licencia MIT.

---

## 📞 Contribuciones

Las contribuciones son bienvenidas. Por favor, sigue estas pautas:

1. Crea una rama para cada característica o bugfix
2. Comenta el código claramente
3. Mantén la consistencia con el estilo existente
4. Abre un Pull Request con una descripción detallada

---

**Versión:** 2.2.0  
**Última actualización:** Mayo 2026
