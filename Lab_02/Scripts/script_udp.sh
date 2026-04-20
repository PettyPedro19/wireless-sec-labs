#!/bin/bash

# ==========================================
# Configuration Variables
# ==========================================
SERVER_IP=192.168.1.49
TIMESTAMP=$(date +"%Y%m%d_%H%M%S")

OUT_DIR="../Results"

mkdir -p "$OUT_DIR"

OUTPUT_FILE="${OUT_DIR}/gput_${TIMESTAMP}.dat"
TMP_FILE="tmp_gput.dat"

MIN_LEN=100
MAX_LEN=1400
STEP_LEN=100
ITERATIONS=10
TEST_DURATION=10
SLEEP_TIME=1

# ==========================================
# Execution
# ==========================================

# Scrive l'intestazione nel nuovo file
echo "# Length(Bytes) Avg(Mbps) Min(Mbps) Max(Mbps) StdDev" > "$OUTPUT_FILE"
echo "Starting tests. Results will be saved in: $OUTPUT_FILE"

for l in $(seq $MIN_LEN $STEP_LEN $MAX_LEN); do
    rm -f "$TMP_FILE"
    
    for i in $(seq 1 $ITERATIONS); do
        iperf3 -c "$SERVER_IP" -R -l "$l" -u -b 0 -t "$TEST_DURATION" | \
            grep "receiver" | tr -s ' ' | cut -d ' ' -f 7 >> "$TMP_FILE"
        
        sleep "$SLEEP_TIME"
    done
    
    # Calculate statistics and append to the output file
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

# Clean up temporary file
rm -f "$TMP_FILE"

echo ""
echo "You can print results with:"
echo "gnuplot -p -e 'plot \"$OUTPUT_FILE\" using 1:(\$2-\$5):3:4:(\$2+\$5) with candlesticks'"
