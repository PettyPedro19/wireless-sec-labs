# Wireless & Device-to-Device Communication Security Lab
## Performance Test — Goodput Measurement Scripts

**Course:** Wireless and Device-to-Device Communication Security  
**Institution:** Politecnico di Torino — Dipartimento di Automatica ed Informatica  
**Date:** April 2026

---

## Overview

This folder contains the automation scripts used to measure the **goodput as a function of frame/segment size** using `iperf3`, following the methodology described in the lab assignment. The goal is to compare empirical goodput curves with the theoretical model from Jun et al. (2003) under different network configurations.

Goodput is defined as the useful data received at the application layer divided by the total transfer time, and is distinct from raw throughput which includes protocol overhead, retransmissions, and signalling traffic.

---

## Testbed

| Role | Device | OS | Interface | Link Speed |
|---|---|---|---|---|
| Client | MacBook Air | macOS | en0 (WiFi) / en5 (ETH) | 866 Mbps (WiFi) / 100 Mbps (ETH) |
| Server | HP Pavilion | Ubuntu 22.04 | eno1 | 100 Mbps (ETH, Full Duplex) |

The **bottleneck link is always the server-side Ethernet at 100 Mbps**, regardless of the scenario. The two hosts are connected through a local LAN via a common access point.

---

## Scenarios

Four scenarios are explored, combining transport protocol (TCP/UDP) and physical link type (Ethernet/WiFi):

| # | Script | Client Link | Server Link | Transport |
|---|---|---|---|---|
| 1 | `script_tcp.sh` | Ethernet (100 Mbps) | Ethernet (100 Mbps) | TCP |
| 2 | `script_udp.sh` | Ethernet (100 Mbps) | Ethernet (100 Mbps) | UDP |
| 3 | `script_tcp.sh` | WiFi 802.11ac (866 Mbps) | Ethernet (100 Mbps) | TCP |
| 4 | `script_udp.sh` | WiFi 802.11ac (866 Mbps) | Ethernet (100 Mbps) | UDP |

---

## Script Parameters

### TCP (`script_tcp.sh`)

The script sweeps the MTU of the client interface using `ifconfig`, then runs `iperf3` for each MTU value. Statistics (average, min, max, standard deviation) are computed across iterations using `awk`.

| Parameter | eth-eth | wifi-eth |
|---|---|---|
| `CLIENT_IFACE` | `en5` | `en0` |
| `MIN_MTU` | 100 | 100 |
| `MAX_MTU` | 1500 | 1500 |
| `STEP_MTU` | 200 | 200 |
| `ITERATIONS` | 5 | 5 |
| `TEST_DURATION` | 10s | 10s |
| `SLEEP_TIME` | 1s | 1s |
| MTU points | 8 | 8 |
| **Estimated duration** | **~8 min** | **~8 min** |

`TEST_DURATION=10s` is chosen to ensure TCP operates in steady state, past the slow start phase — especially important for small MTU values and the WiFi scenario where the congestion window grows more slowly.

### UDP (`script_udp.sh`)

The script sweeps the UDP payload length using the `-l` option of `iperf3`. No MTU change is needed on the interface. The maximum payload is capped at 1472 bytes (= 1500 − 20 IP − 8 UDP) to avoid IP fragmentation.

| Parameter | eth-eth | wifi-eth |
|---|---|---|
| `CLIENT_IFACE` | `en5` | `en0` |
| `MIN_LEN` | 100 | 100 |
| `MAX_LEN` | 1472 | 1472 |
| `STEP_LEN` | 200 | 200 |
| `ITERATIONS` | 5 | 5 |
| `TEST_DURATION` | 5s | 5s |
| `SLEEP_TIME` | 1s | 1s |
| `TARGET_BITRATE` | `0` (unlimited) | `95M` |
| Length points | 8 | 8 |
| **Estimated duration** | **~4 min** | **~4 min** |

`TEST_DURATION=5s` is sufficient for UDP as there is no slow start. For the WiFi scenario, `TARGET_BITRATE` is capped at `95M` to avoid saturating the WiFi transmit buffer with unlimited UDP bursts, which would cause artificial packet loss and underestimate the true goodput.

---

## Output Files

Each script run produces two files in the `../Results/` directory:

- `tcp_gput_<TIMESTAMP>.dat` / `udp_gput_<TIMESTAMP>.dat` — measurement data with columns:
  ```
  # Size(Bytes)  Avg(Mbps)  Min(Mbps)  Max(Mbps)  StdDev
  ```
- `tcp_gput_<TIMESTAMP>_info.txt` / `udp_gput_<TIMESTAMP>_info.txt` — full metadata of the test run (scenario, interfaces, OS, iperf version, parameters).

---

## Plotting

Results can be visualised as candlestick plots using gnuplot:

```bash
gnuplot -p -e 'plot "results.dat" using 1:($2-$5):3:4:($2+$5) with candlesticks'
```

The candlestick bars show min/max as whiskers and mean ± stddev as the box body.

---

## Theoretical Reference

Expected maximum goodput values (bottleneck at 100 Mbps, full duplex Ethernet):

| Protocol | Max payload | Efficiency | Max goodput |
|---|---|---|---|
| UDP | 1472 B | 95.7% | ~95.7 Mbps |
| TCP | 1460 B | ~91.8% | ~91.8 Mbps |

For TCP, efficiency accounts for both data frames and returning ACK frames. For UDP, no ACKs are generated at the transport layer.

---

## References

Jun, J., Peddabachagari, P., & Sichitiu, M. (2003). *Theoretical maximum throughput of IEEE 802.11 and its applications*. In Second IEEE International Symposium on Network Computing and Applications (NCA 2003), pp. 249–256. IEEE.