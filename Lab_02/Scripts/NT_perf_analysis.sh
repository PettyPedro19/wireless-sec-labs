#!/bin/bash

# Initialize data file
rm -f gput.dat

# Loop through buffer sizes from 16 to 1000 in steps of 100
for l in $(seq 16 100 1000); do
    # Execute iperf and extract the 7th field (bitrate) from the receiver line
    iperf3 -c 192.168.1.3 -l $l -u --time 1 | \
    grep "receiver" | \
    tr -s ' ' | \
    cut -d ' ' -f 7 >> gput.dat
    sleep 1
done

# Statistical processing
awk '
BEGIN {max=0; min=99999999}
{
    x += $1; 
    y += $1^2; 
    if ($1 < min) min = $1; 
    if ($1 > max) max = $1
}
END {
    if (NR > 0) 
        printf "avg=%.2f\nmin=%.2f\nmax=%.2f\nstd=%.2f\n", x/NR, min, max, sqrt(y/NR - (x/NR)^2)
}' gput.dat

# Plotting
gnuplot -p << EOF
set title "Throughput vs Buffer Size"
set xlabel "Test Iteration"
set ylabel "Throughput (bits/sec)"
plot "gput.dat" with linespoints title "Throughput"
EOF
