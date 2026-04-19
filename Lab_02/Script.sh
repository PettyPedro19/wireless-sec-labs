#!/bin/bash

# --- PARAMETRI ---
ITERATIONS=10
TARGET_IP="192.168.1.49" # DA MODIFICARE CON L'IP DEL CLIENT
RAW_DAT="/tmp/iperf_raw.dat"

# Chiede il nome dello scenario per non sovrascrivere i file
read -p "Inserisci il nome dello scenario fisico (es. Eth-WiFi, WiFi-WiFi): " SCENARIO_NAME
OUTPUT_FILE="$HOME/Desktop/Risultati_${SCENARIO_NAME}.txt"

> "$OUTPUT_FILE"
echo "=========================================" >> "$OUTPUT_FILE"
echo " SCENARIO: $SCENARIO_NAME" >> "$OUTPUT_FILE"
echo " DATA: $(date)" >> "$OUTPUT_FILE"
echo "=========================================" >> "$OUTPUT_FILE"

# Funzione core per eseguire i test ed estrarre statistiche matematiche
run_iperf_test() {
    local test_name=$1
    local iperf_args=$2
    
    echo -e "\n--- Esecuzione: $test_name ---" | tee -a "$OUTPUT_FILE"
    > "$RAW_DAT"

    for ((i=1; i<=ITERATIONS; i++))
    do
        echo -n " Iterazione $i... "
        # Usa awk per estrarre con precisione il 7° campo (il valore della banda) dalla riga "receiver"
        # --format m forza l'output in megabit per secondo
        iperf3 -c "$TARGET_IP" $iperf_args --format m | awk '/receiver/ {print $7}' >> "$RAW_DAT"
        echo "Completata."
    done

    # Calcolo statistico (Media, Min, Max, Deviazione Standard)
    awk -v name="$test_name" '
    BEGIN {max=0; min=99999999; sum=0; sumsq=0; count=0}
    {
        count++;
        sum += $1; 
        sumsq += ($1^2); 
        if ($1 < min) {min = $1}; 
        if ($1 > max) {max = $1}
    }
    END {
        if (count > 0) {
            avg = sum / count;
            stddev = sqrt((sumsq / count) - (avg^2));
            printf "RISULTATI %s:\n", name;
            printf "  Media : %.2f Mbits/sec\n", avg;
            printf "  Min   : %.2f Mbits/sec\n", min;
            printf "  Max   : %.2f Mbits/sec\n", max;
            printf "  StdDev: %.2f Mbits/sec\n", stddev;
        } else {
            print "ERRORE: Nessun dato valido registrato. Controlla la connessione."
        }
    }' "$RAW_DAT" | tee -a "$OUTPUT_FILE"
}

# --- PIANO DI ESECUZIONE DEI TEST ---

# 1. TCP Standard
run_iperf_test "TCP (Client -> Server)" ""
run_iperf_test "TCP REVERSE (Server -> Client)" "-R"

# 2. UDP Standard (Saturazione a 1 Gbps per forzare il limite fisico)
run_iperf_test "UDP Base (Client -> Server)" "-u -b 0"
run_iperf_test "UDP Base REVERSE (Server -> Client)" "-u -b 0 -R"

# 3. UDP Ottimizzato per MTU (Nessuna frammentazione)
run_iperf_test "UDP 1472B (Client -> Server)" "-u -b 0 -l 1472"
run_iperf_test "UDP 1472B REVERSE (Server -> Client)" "-u -b 0 -l 1472 -R"

# 4. UDP Frammentato (Disastro prestazionale garantito)
run_iperf_test "UDP 1473B Frammentato (Client -> Server)" "-u -b 0 -l 1473"
run_iperf_test "UDP 1473B Frammentato REVERSE (Server -> Client)" "-u -b 0 -l 1473 -R"

echo -e "\nTest completato. Risultati salvati in: $OUTPUT_FILE"
