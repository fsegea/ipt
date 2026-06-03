#!/bin/bash

# Crear y configurar la cadena LAN_ACL_PORT_ALLOW
$IPT -N LAN_ACL_PORT_ALLOW

# Permitir solo tráfico HTTPS desde la LAN
#$IPT -A LAN_ACL_PORT_ALLOW -p tcp --dport 443 -j ACCEPT


##############################
# Permitir Reenvío entre Interfaces
##############################
#echo "Permitir reenvío entre interfaces"

# Permitir reenvío de paquetes desde ILAN a IWAN con LOG
$IPT -A LAN_ACL_PORT_ALLOW -i $ILAN -o $IWAN -p tcp --dport 22 -m conntrack --ctstate NEW -m comment --comment "Permite conexiones al puerto ssh" -j ACCEPT
$IPT -A LAN_ACL_PORT_ALLOW -i $ILAN -o $IWAN -p udp --dport 53 -m conntrack --ctstate NEW -m comment --comment "Permite dns manuales" -j ACCEPT
$IPT -A LAN_ACL_PORT_ALLOW -i $ILAN -o $IWAN -p tcp --dport 80 -m conntrack --ctstate NEW -m comment --comment "Permite conexiones al puerto http" -j ACCEPT
$IPT -A LAN_ACL_PORT_ALLOW -i $ILAN -o $IWAN -p udp --dport 123 -m conntrack --ctstate NEW -m comment --comment "Permite conexiones NTP" -j ACCEPT
$IPT -A LAN_ACL_PORT_ALLOW -i $ILAN -o $IWAN -p tcp --dport 443 -m conntrack --ctstate NEW -m comment --comment "Permitir conexiones al puerto 443" -j ACCEPT
$IPT -A LAN_ACL_PORT_ALLOW -i $ILAN -o $IWAN -p tcp --dport 993 -m conntrack --ctstate NEW -m comment --comment "Permitir la conexion imap sobre ssl correo seguro" -j ACCEPT
$IPT -A LAN_ACL_PORT_ALLOW -i $ILAN -o $IWAN -p udp --dport 51820 -m conntrack --ctstate NEW -m comment --comment "Permitir conexiones al puerto 51820 udp wireguar" -j ACCEPT
$IPT -A LAN_ACL_PORT_ALLOW -i $ILAN -o $IWAN -p tcp --dport 5223 -m conntrack --ctstate NEW -m comment --comment "IBKR" -j ACCEPT
$IPT -A LAN_ACL_PORT_ALLOW -i $ILAN -o $IWAN -p tcp --dport 4001 -m conntrack --ctstate NEW -m comment --comment "IBKR" -j ACCEPT
$IPT -A LAN_ACL_PORT_ALLOW -i $ILAN -o $IWAN -p tcp --dport 4000 -m conntrack --ctstate NEW -m comment --comment "IBKR" -j ACCEPT
$IPT -A LAN_ACL_PORT_ALLOW -i $ILAN -o $IWAN -p tcp --dport 1883 -d 34.240.81.189 -m conntrack --ctstate NEW -m comment --comment "ALEXA" -j ACCEPT
$IPT -A LAN_ACL_PORT_ALLOW -i $ILAN -o $IWAN -p tcp --dport 5228 -s 10.10.0.41 -m conntrack --ctstate NEW -m comment --comment "Permite a la tele conectarse a google para que funcione la alexa" -j ACCEPT
$IPT -A LAN_ACL_PORT_ALLOW -i $ILAN -o $IWAN -p icmp -m conntrack --ctstate NEW -m comment --comment "Permite conexiones icmp" -j ACCEPT
