#!/bin/bash

# --- PARAMETRI ---
ITERATIONS=10
TARGET_IP="192.168.1.4"
RAW_DAT="/tmp/iperf_raw.dat"

# Chiede i parametri necessari per le cartelle e per Wireshark
read -p "Inserisci l'interfaccia di rete per Wireshark (es. eth0, wlan0, en0): " INTERFACE
read -p "Inserisci il nome dello scenario fisico (es. Eth-WiFi, WiFi-WiFi): " SCENARIO_NAME

# Creazione della cartella macro sulla Scrivania
MACRO_DIR="$HOME/Desktop/${SCENARIO_NAME}"
mkdir -p "$MACRO_DIR"

echo "========================================="
echo " SCENARIO: $SCENARIO_NAME"
echo " INTERFACCIA: $INTERFACE"
echo " DATA: $(date)"
echo " CARTELLA DESTINAZIONE: $MACRO_DIR"
echo "========================================="

# Funzione core per eseguire i test ed estrarre statistiche matematiche
run_iperf_test() {
    local test_name=$1
    local iperf_args=$2
    
    # Pulizia del nome del test per creare una cartella valida (sostituisce spazi con underscore e rimuove parentesi)
    local safe_test_name=$(echo "$test_name" | tr ' ' '_' | tr -d '()><')
    local test_dir="$MACRO_DIR/$safe_test_name"
    mkdir -p "$test_dir"

    local output_file="$test_dir/risultati_statistici.txt"
    
    > "$output_file"
    echo "=========================================" >> "$output_file"
    echo " TEST: $test_name" >> "$output_file"
    echo " DATA: $(date)" >> "$output_file"
    echo "=========================================" >> "$output_file"
    
    echo -e "\n--- Esecuzione: $test_name ---"
    > "$RAW_DAT"

    for ((i=1; i<=ITERATIONS; i++))
    do
        echo -n " Iterazione $i... "
        
        local pcap_file="$test_dir/cattura_iterazione_${i}.pcap"
        local iperf_txt="$test_dir/iperf_iterazione_${i}.txt"

        # Avvio di tshark (Wireshark CLI) in background
        tshark -i "$INTERFACE" -w "$pcap_file" -q &
        local tshark_pid=$!

        # Pausa di sicurezza per permettere a tshark di avviare la cattura
        sleep 1

        # Esecuzione di iperf3 con salvataggio dell'intero output nel file .txt specifico
        iperf3 -c "$TARGET_IP" $iperf_args --format m > "$iperf_txt"

        # Chiusura del processo di cattura tshark
        kill $tshark_pid
        wait $tshark_pid 2>/dev/null

        # Estrazione del 7° campo dalla riga "receiver" per il calcolo statistico
        awk '/receiver/ {print $7}' "$iperf_txt" >> "$RAW_DAT"
        
        echo "Completata."
    done

    # Calcolo statistico (Media, Min, Max, Deviazione Standard) salvato nel file di riepilogo
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
    }' "$RAW_DAT" | tee -a "$output_file"
}

# --- PIANO DI ESECUZIONE DEI TEST ---

# 1. TCP Standard
run_iperf_test "TCP Client_Server" ""
run_iperf_test "TCP REVERSE Server_Client" "-R"

# 2. UDP Standard (Saturazione a 1 Gbps per forzare il limite fisico)
run_iperf_test "UDP Base Client_Server" "-u -b 1000M"
run_iperf_test "UDP Base REVERSE Server_Client" "-u -b 1000M -R"

# 3. UDP Ottimizzato per MTU (Nessuna frammentazione)
run_iperf_test "UDP 1472B Client_Server" "-u -b 1000M -l 1472"
run_iperf_test "UDP 1472B REVERSE Server_Client" "-u -b 1000M -l 1472 -R"

# 4. UDP Frammentato (Disastro prestazionale garantito)
run_iperf_test "UDP 1473B Frammentato Client_Server" "-u -b 1000M -l 1473"
run_iperf_test "UDP 1473B Frammentato REVERSE Server_Client" "-u -b 1000M -l 1473 -R"

echo -e "\nTest completato. Risultati e catture di traffico salvati in: $MACRO_DIR"