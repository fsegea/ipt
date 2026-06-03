#!/bin/bash
# input_security.sh - Submódulo Sensor de Intrusiones desacoplado

$IPT -N INPUT_SECURITY

echo "=========================================="
echo "🛡️  Configurando INPUT_SECURITY"
echo "=========================================="

##############################
# NIVEL 0: ANTI-SPOOFING (CONSERVADO COMPLETO)
##############################
echo "[0/6] Configurando anti-spoofing..."

# Bloquear IPs privadas desde WAN (RFC 1918)
$IPT -A INPUT_SECURITY -i $IWAN -s 10.0.0.0/8 \
    -j LOG --log-prefix "SPOOF-10: " --log-level 4
$IPT -A INPUT_SECURITY -i $IWAN -s 10.0.0.0/8 -j DROP

$IPT -A INPUT_SECURITY -i $IWAN -s 172.16.0.0/12 \
    -j LOG --log-prefix "SPOOF-172: " --log-level 4
$IPT -A INPUT_SECURITY -i $IWAN -s 172.16.0.0/12 -j DROP

$IPT -A INPUT_SECURITY -i $IWAN -s 192.168.0.0/16 \
    -j LOG --log-prefix "SPOOF-192: " --log-level 4
$IPT -A INPUT_SECURITY -i $IWAN -s 192.168.0.0/16 -j DROP

# Bloquear localhost desde WAN
$IPT -A INPUT_SECURITY -i $IWAN -s 127.0.0.0/8 \
    -j LOG --log-prefix "SPOOF-LOCALHOST: " --log-level 4
$IPT -A INPUT_SECURITY -i $IWAN -s 127.0.0.0/8 -j DROP

# Bloquear multicast y broadcast desde WAN
$IPT -A INPUT_SECURITY -i $IWAN -s 224.0.0.0/4 -j DROP
$IPT -A INPUT_SECURITY -i $IWAN -d 224.0.0.0/4 -j DROP
$IPT -A INPUT_SECURITY -i $IWAN -s 240.0.0.0/5 -j DROP

# Bloquear IP 0.0.0.0
$IPT -A INPUT_SECURITY -i $IWAN -s 0.0.0.0/8 -j DROP

##############################
# NIVEL 1: BLOQUEOS RÁPIDOS (O(1))
##############################
echo "[1/6] Configurando bloqueos inmediatos..."

# Bloquear estados de conexión inválidos
$IPT -A INPUT_SECURITY -m conntrack --ctstate INVALID -j DROP

##############################
# NIVEL 2: DETECCIÓN DE FIRMAS (SENSORES PUROS)
##############################
echo "[2/6] Configurando detección de firmas de red..."

# 2.1 Detectar scanners automáticos (Masscan/ZMap: TTL=249, WINDOW=1024, SYN de 40 bytes)
$IPT -A INPUT_SECURITY -p tcp --syn \
    -m length --length 40 \
    -m ttl --ttl-eq 249 \
    -j LOG --log-prefix "SCANNER-SIGNATURE: " --log-level 4
$IPT -A INPUT_SECURITY -p tcp --syn \
    -m length --length 40 \
    -m ttl --ttl-eq 249 \
    -j DROP

# 2.2 Detectar otros patrones sospechosos (TTL anómalos < 32)
$IPT -A INPUT_SECURITY -p tcp --syn \
    -m ttl --ttl-lt 32 \
    -j LOG --log-prefix "SUSPICIOUS-TTL: " --log-level 4
$IPT -A INPUT_SECURITY -p tcp --syn \
    -m ttl --ttl-lt 32 \
    -j DROP

##############################
# NIVEL 3: ANÁLISIS DE COMPORTAMIENTO (RÁFAGAS CORTO PLAZO)
##############################
echo "[3/6] Configurando análisis de comportamiento en ráfagas..."

# Registrar todos los nuevos intentos SYN para tracking instantáneo en la tabla del kernel
$IPT -A INPUT_SECURITY -p tcp --syn \
    -m recent --name syntracker --set --rsource

# 3.1 Detectar escaneo rápido (>= 8 SYN en 60 segundos) -> Loguea para el IDS y mitiga ráfaga
$IPT -A INPUT_SECURITY -p tcp --syn \
    -m recent --name syntracker --rcheck --seconds 60 --hitcount 8 --rsource \
    -j LOG --log-prefix "FAST-SCAN: " --log-level 4
$IPT -A INPUT_SECURITY -p tcp --syn \
    -m recent --name syntracker --rcheck --seconds 60 --hitcount 8 --rsource \
    -j DROP

# 3.2 Detectar escaneo moderado (>= 6 SYN en 60 segundos) -> Loguea para el IDS y mitiga ráfaga
$IPT -A INPUT_SECURITY -p tcp --syn \
    -m recent --name syntracker --rcheck --seconds 60 --hitcount 6 --rsource \
    -j LOG --log-prefix "PORT-SCANNER: " --log-level 4
$IPT -A INPUT_SECURITY -p tcp --syn \
    -m recent --name syntracker --rcheck --seconds 60 --hitcount 6 --rsource \
    -j DROP

##############################
# NIVEL 4: PROTECCIÓN TCP MALFORMADO
##############################
echo "[4/6] Configurando protección contra paquetes malformados..."

# Bloquear combinaciones de flags TCP inválidas
$IPT -A INPUT_SECURITY -p tcp --tcp-flags ALL NONE -j DROP       # NULL scan
$IPT -A INPUT_SECURITY -p tcp --tcp-flags ALL ALL -j DROP        # XMAS scan
$IPT -A INPUT_SECURITY -p tcp --tcp-flags SYN,FIN SYN,FIN -j DROP
$IPT -A INPUT_SECURITY -p tcp --tcp-flags SYN,RST SYN,RST -j DROP
$IPT -A INPUT_SECURITY -p tcp --tcp-flags FIN,RST FIN,RST -j DROP
$IPT -A INPUT_SECURITY -p tcp --tcp-flags ACK,FIN FIN -j DROP
$IPT -A INPUT_SECURITY -p tcp --tcp-flags ACK,URG URG -j DROP
$IPT -A INPUT_SECURITY -p tcp --tcp-flags ACK,PSH PSH -j DROP

# Bloquear XMAS y FIN scans específicos
$IPT -A INPUT_SECURITY -p tcp --tcp-flags ALL FIN,PSH,URG -j DROP

# Protección contra fragmentación maliciosa (FRAG-ATTACK)
$IPT -A INPUT_SECURITY -f \
    -m limit --limit 1/min --limit-burst 3 \
    -j LOG --log-prefix "FRAG-ATTACK: " --log-level 4
$IPT -A INPUT_SECURITY -f -j DROP

##############################
# NIVEL 5: RATE LIMITING GLOBAL (FLOODS)
##############################
echo "[5/6] Configurando rate limiting global contra Floods..."

# 5.1 Rate limiting para nuevas conexiones SYN (Protección nativa)
$IPT -A INPUT_SECURITY -p tcp --syn \
    -m limit --limit 10/s --limit-burst 15 \
    -j RETURN

# 5.2 Log de SYN flood (Limitado para proteger el almacenamiento)
$IPT -A INPUT_SECURITY -p tcp --syn \
    -m limit --limit 1/s --limit-burst 3 \
    -j LOG --log-prefix "SYN-FLOOD: " --log-level 4

# 5.3 Bloquear exceso de SYN flood
$IPT -A INPUT_SECURITY -p tcp --syn -j DROP

# 5.4 Protección contra SYN-ACK floods
#$IPT -A INPUT_SECURITY -p tcp --tcp-flags SYN,ACK SYN,ACK \
#    -m limit --limit 100/s --limit-burst 200 -j RETURN
#$IPT -A INPUT_SECURITY -p tcp --tcp-flags SYN,ACK SYN,ACK \
#    -j LOG --log-prefix "SYNACK-FLOOD: " --log-level 4
#$IPT -A INPUT_SECURITY -p tcp --tcp-flags SYN,ACK SYN,ACK -j DROP

# 5.5 Rate limiting ICMP (Prevenir ping floods)
$IPT -A INPUT_SECURITY -p icmp --icmp-type echo-request \
    -m limit --limit 5/s --limit-burst 10 \
    -j RETURN
$IPT -A INPUT_SECURITY -p icmp --icmp-type echo-request -j DROP

# 5.6 Rate limiting UDP por IP (Prevenir UDP floods sin falsos positivos)
$IPT -A INPUT_SECURITY -p udp \
    -m hashlimit --hashlimit-name udp_flood_limit --hashlimit-mode srcip \
    --hashlimit-upto 15/sec --hashlimit-burst 30 \
    -j RETURN

# EXPLICACIÓN: Si una IP legítima envía menos de 15 p/s, la regla anterior hace RETURN.
# Solo los atacantes reales que superen SU PROPIO límite individual llegarán aquí abajo:
$IPT -A INPUT_SECURITY -p udp \
    -m limit --limit 1/s --limit-burst 3 \
    -j LOG --log-prefix "UDP-FLOOD: " --log-level 4
$IPT -A INPUT_SECURITY -p udp -j DROP

##############################
# CONFIGURACIÓN COMPLETA
##############################
echo "=========================================="
echo "✅ SUBMÓDULO INPUT_SECURITY SINCRONIZADO"
echo "=========================================="
