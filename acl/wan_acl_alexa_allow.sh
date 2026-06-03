#!/bin/bash
IPSET_NAME="alexa_aws"

echo "Configurando whitelist Alexa Smart Home (ipset: $IPSET_NAME)..."

# Crear si no existe y vaciar siempre
ipset create "$IPSET_NAME" hash:net maxelem 64 comment -exist
ipset flush "$IPSET_NAME"

# Añadir rangos
ipset add $IPSET_NAME 54.239.99.0/24  -exist comment "AMAZON eu-west-1"
ipset add $IPSET_NAME 3.248.0.0/13    -exist comment "EC2    eu-west-1"
ipset add $IPSET_NAME 54.240.0.0/12   -exist comment "AMAZON servicios globales"
ipset add $IPSET_NAME 108.128.0.0/10  -exist comment "AMAZON eu-west-1"
ipset add $IPSET_NAME 34.240.0.0/13   -exist comment "AMAZON eu-west-1"
ipset add $IPSET_NAME 54.72.0.0/13 -exist comment "AMAZON eu-west-1"
ipset add $IPSET_NAME 18.200.0.0/15 -exist comment "AMAZON eu-west-1"
ipset add $IPSET_NAME 18.202.0.0/15 -exist comment "AMAZON eu-west-1"
ipset add $IPSET_NAME 34.248.0.0/13 -exist comment "AMAZON eu-west-1"
ipset add $IPSET_NAME 54.216.0.0/15   -exist comment "AMAZON servicios globales"
ipset add $IPSET_NAME 54.194.0.0/15    -exist comment "AMAZON servicios globales"
ipset add $IPSET_NAME 46.222.124.0/24   -exist comment "PEPEPHONE 1"


COUNT=$(ipset list $IPSET_NAME | grep -E "^[0-9]+\." | wc -l)
echo "  -> ipset '$IPSET_NAME' listo con $COUNT entradas."
