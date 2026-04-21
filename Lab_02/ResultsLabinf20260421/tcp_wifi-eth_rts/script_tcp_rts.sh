#!/bin/bash

NETWORK_SCENARIO="wifi-eth-rts"
REVERSE_MODE="no"
RTS_THRESHOLD=500

# ── SERVER (Mac) ───────────────────────────────────────────────────────────
SERVER_IP="192.168.1.03"        
SERVER_OS="macOS"
SERVER_IFACE="en5"
SERVER_LINK_SPEED="100Mb/s"
SERVER_MTU="1500"

# ── CLIENT (Ubuntu WiFi) ───────────────────────────────────────────────────
CLIENT_IFACE="wlo1"            
CLIENT_LINK_SPEED="433.3Mb/s"

CLIENT_OS=$(lsb_release -ds 2>/dev/null)
IPERF_VERSION=$(iperf3 -v | awk 'NR==1')
CLIENT_IP=$(ip addr show "$CLIENT_IFACE" | grep "inet " | awk '{print $2}' | cut -d/ -f1)
CLIENT_BASE_MTU=$(ip link show "$CLIENT_IFACE" | grep -o "mtu [0-9]*" | awk '{print $2}')

TIMESTAMP=$(date +"%Y%m%d_%H%M%S")
OUT_DIR="Results"
mkdir -p "$OUT_DIR"

OUTPUT_FILE="${OUT_DIR}/tcp_gput_wifi_rts${RTS_THRESHOLD}_${TIMESTAMP}.dat"
INFO_FILE="${OUT_DIR}/tcp_gput_wifi_rts${RTS_THRESHOLD}_${TIMESTAMP}_info.txt"
TMP_FILE="tmp_gput.dat"

MIN_MTU=16
MAX_MTU=1500
STEP_MTU=100

ITERATIONS=10
TEST_DURATION=5
SLEEP_TIME=1

# ── Imposta RTS ────────────────────────────────────────────────────────────
echo "[INFO] Setting RTS threshold to $RTS_THRESHOLD bytes on $CLIENT_IFACE"
sudo iwconfig "$CLIENT_IFACE" rts "$RTS_THRESHOLD"

cat <<EOF > "$INFO_FILE"
========================================
TEST CONFIGURATION METADATA
========================================
Timestamp: $TIMESTAMP
Scenario: $NETWORK_SCENARIO
Reverse Mode (-R): $REVERSE_MODE
RTS Threshold: $RTS_THRESHOLD Bytes

[ TEST PARAMETERS ]
Test Type: TCP (MTU Sweep)
MTU Min: $MIN_MTU Bytes
MTU Max: $MAX_MTU Bytes
MTU Step: $STEP_MTU Bytes
Iterations per Step: $ITERATIONS
Time per Iteration (-t): $TEST_DURATION seconds

[ CLIENT INFO ]
Interface: $CLIENT_IFACE  (WiFi)
IP Address: $CLIENT_IP
OS: $CLIENT_OS
Base MTU: $CLIENT_BASE_MTU
Link Speed: $CLIENT_LINK_SPEED

[ SERVER INFO ]
IP Address: $SERVER_IP
Interface: $SERVER_IFACE  (Ethernet/WiFi Mac)
OS: $SERVER_OS
Base MTU: $SERVER_MTU
Link Speed: $SERVER_LINK_SPEED

[ SOFTWARE ]
Tool: $IPERF_VERSION
========================================
EOF

echo "# MTU(Bytes) Avg(Mbps) Min(Mbps) Max(Mbps) StdDev" > "$OUTPUT_FILE"

for mtu in $(seq $MIN_MTU $STEP_MTU $MAX_MTU); do
    sudo ip link set "$CLIENT_IFACE" mtu "$mtu" 2>/dev/null
    if [ $? -ne 0 ]; then
	    echo "[SKIP] MTU $mtu not supported, skipping ..."
	    continue
    fi
    sleep 3

    rm -f "$TMP_FILE"

    for i in $(seq 1 $ITERATIONS); do
        iperf3 -c "$SERVER_IP" -t "$TEST_DURATION" | \
            grep "receiver" | tr -s ' ' | cut -d ' ' -f 7 >> "$TMP_FILE"
        sleep "$SLEEP_TIME"
    done

    awk -v len="$mtu" '
        BEGIN { max=0; min=9999999999 }
        { x+=$1; y+=$1^2;
          if($1<min) min=$1; if($1>max) max=$1 }
        END { if(NR>0) {
            avg=x/NR; std=sqrt(y/NR-avg^2);
            printf "%d %.2f %.2f %.2f %.2f\n", len, avg, min, max, std
        }}' "$TMP_FILE" >> "$OUTPUT_FILE"
done

rm -f "$TMP_FILE"
sudo ip link set "$CLIENT_IFACE" mtu 1500

# ── Reset RTS al default ───────────────────────────────────────────────────
sudo iwconfig "$CLIENT_IFACE" rts 2347
echo "[INFO] RTS reset to default (2347)"

echo "Plot with:"
echo "gnuplot -p -e 'plot \"$OUTPUT_FILE\" using 1:(\$2-\$5):3:4:(\$2+\$5) with candlesticks'"
