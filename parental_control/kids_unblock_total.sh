#!/bin/bash
export PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
source "$PROJECT_DIR/config/config.sh"
IPT="${IPT:-/usr/sbin/iptables}"

$IPT -F KIDS_ACCESS
$IPT -A KIDS_ACCESS -j ACCEPT
logger "Acceso a internet total permitido para dispositivos infantiles"