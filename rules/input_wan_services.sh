#!/bin/bash

$IPT -N INPUT_WAN_SERVICES

# Todo lo demás desde WAN al router: LOG + DROP
$IPT -A INPUT_WAN_SERVICES \
    -m limit --limit 5/min --limit-burst 10 \
    -j LOG --log-prefix "INPUT-DROP: " --log-level 4
$IPT -A INPUT_WAN_SERVICES -j DROP
