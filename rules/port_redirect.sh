#!/bin/bash

# Crear y configurar la cadena PORT_REDIRECT
$IPT -t nat -N PORT_REDIRECT
# Redirigir tráfico de puertos específicos al servidor interno usando DNAT
echo "Configurar DNAT"

# Redirigir tráfico WireGuard desde el puerto 51820 al servidor interno 10.10.0.100
$IPT -t nat -A PORT_REDIRECT -p udp --dport 51820 -i $IWAN -m comment --comment "DNAT WireGuard" -j DNAT --to-destination 10.10.0.100:51820

# Redirigir tráfico HomeAssistant desde el puerto 443 al servidor interno 10.10.0.100
$IPT -t nat -A PORT_REDIRECT -p tcp --dport 443 -i $IWAN -m comment --comment "NGINX PROXY MANAGER" -j DNAT --to-destination 10.10.0.100:443

# Redirigir tráfico Transmission desde el puerto 51413 al servidor interno 10.10.0.20
$IPT -t nat -A PORT_REDIRECT -p udp --dport 51413 -i $IWAN -m comment --comment "Transmission" -j DNAT --to-destination 10.10.0.20:51413
$IPT -t nat -A PORT_REDIRECT -p tcp --dport 51413 -i $IWAN -m comment --comment "Transmission" -j DNAT --to-destination 10.10.0.20:51413


