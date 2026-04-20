#!/bin/bash

SERVER_IP="192.168.1.49"
IFACE="en5" 

TIMESTAMP=$(date +"%Y%m%d_%H%M%S")
OUT_DIR="../Results"
mkdir -p "$OUT_DIR"

OUTPUT_FILE="${OUT_DIR}/tcp_gput_${TIMESTAMP}.dat"
TMP_FILE="tmp_tcp_gput.dat"

MIN_MTU=500
MAX_MTU=1500
STEP_MTU=200

ITERATIONS=5
TEST_DURATION=1
SLEEP_TIME=1

echo "# MTU(Bytes) Avg(Mbps) Min(Mbps) Max(Mbps) StdDev" > "$OUTPUT_FILE"

for mtu in $(seq $MIN_MTU $STEP_MTU $MAX_MTU); do
    sudo ifconfig "$IFACE" mtu "$mtu" > /dev/null 2>&1
    sleep 3 
    
    rm -f "$TMP_FILE"
    
    for i in $(seq 1 $ITERATIONS); do
        iperf3 -c "$SERVER_IP" -t "$TEST_DURATION" | \
            grep "receiver" | tr -s ' ' | cut -d ' ' -f 7 >> "$TMP_FILE"
        
        sleep "$SLEEP_TIME"
    done
    
    awk -v len="$mtu" '
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
sudo ifconfig "$IFACE" mtu 1500 > /dev/null 2>&1

echo "You can print results with:"
echo "gnuplot -p -e 'plot \"$OUTPUT_FILE\" using 1:(\$2-\$5):3:4:(\$2+\$5) with candlesticks'"
