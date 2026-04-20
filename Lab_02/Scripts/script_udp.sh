#!/bin/bash

NETWORK_SCENARIO="eth-eth"
REVERSE_MODE="no"
TARGET_BITRATE="0" # 0 means unlimited for UDP in iperf3

SERVER_IP="192.168.1.49"
SERVER_OS="Ubuntu Linux 22.04"
SERVER_IFACE="enpls0f0"
SERVER_LINK_SPEED="1000Mb/s"

CLIENT_IFACE="en0"
CLIENT_LINK_SPEED="Unknown" 

CLIENT_OS=$(sw_vers -productName 2>/dev/null)" "$(sw_vers -productVersion 2>/dev/null)
IPERF_VERSION=$(iperf3 -v | awk 'NR==1')
CLIENT_IP=$(ipconfig getifaddr "$CLIENT_IFACE")
CLIENT_MTU=$(ifconfig "$CLIENT_IFACE" | grep -o "mtu [0-9]*" | awk '{print $2}')

TIMESTAMP=$(date +"%Y%m%d_%H%M%S")
OUT_DIR="../Results"
mkdir -p "$OUT_DIR"

OUTPUT_FILE="${OUT_DIR}/udp_gput_${TIMESTAMP}.dat"
INFO_FILE="${OUT_DIR}/udp_gput_${TIMESTAMP}_info.txt"
TMP_FILE="tmp_gput.dat"

MIN_LEN=100
MAX_LEN=1472
STEP_LEN=100

ITERATIONS=10
TEST_DURATION=10
SLEEP_TIME=1

cat <<EOF > "$INFO_FILE"
========================================
TEST CONFIGURATION METADATA
========================================
Timestamp: $TIMESTAMP
Scenario: $NETWORK_SCENARIO
Reverse Mode (-R): $REVERSE_MODE

[ TEST PARAMETERS ]
Test Type: UDP (Length Sweep)
Target Bitrate (-b): $TARGET_BITRATE
Length Min: $MIN_LEN Bytes
Length Max: $MAX_LEN Bytes
Length Step: $STEP_LEN Bytes
Iterations per Step: $ITERATIONS
Time per Iteration (-t): $TEST_DURATION seconds

[ CLIENT INFO ]
Interface: $CLIENT_IFACE
IP Address: $CLIENT_IP
OS: $CLIENT_OS
MTU: $CLIENT_MTU
Link Speed: $CLIENT_LINK_SPEED

[ SERVER INFO ]
IP Address: $SERVER_IP
Interface: $SERVER_IFACE
OS: $SERVER_OS
Link Speed: $SERVER_LINK_SPEED

[ SOFTWARE ]
Tool: $IPERF_VERSION
========================================
EOF

echo "# Length(Bytes) Avg(Mbps) Min(Mbps) Max(Mbps) StdDev" > "$OUTPUT_FILE"

for l in $(seq $MIN_LEN $STEP_LEN $MAX_LEN); do
    rm -f "$TMP_FILE"
    
    for i in $(seq 1 $ITERATIONS); do
        iperf3 -c "$SERVER_IP" -l "$l" -u -b "$TARGET_BITRATE" -t "$TEST_DURATION" | \
            grep "receiver" | tr -s ' ' | cut -d ' ' -f 7 >> "$TMP_FILE"
        sleep "$SLEEP_TIME"
    done
    
    awk -v len="$l" '
        BEGIN { max=0; min=9999999999 } 
        {
            x += $1; 
            y += $1^2; 
            if ($1 < min) { min = $1 }
            if ($1 > max) { max = $1 }
        } 
        END {
            if (NR > 0) {
                avg = x / NR;
                std = sqrt(y / NR - (avg^2));
                printf "%d %.2f %.2f %.2f %.2f\n", len, avg, min, max, std
            }
        }' "$TMP_FILE" >> "$OUTPUT_FILE"
done

rm -f "$TMP_FILE"

echo "You can print results with:"
echo "gnuplot -p -e 'plot \"$OUTPUT_FILE\" using 1:(\$2-\$5):3:4:(\$2+\$5) with candlesticks'"
