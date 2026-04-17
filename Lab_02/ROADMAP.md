# 🛜 Wireless Security Lab — Roadmap

**Course:** Wireless and Device-to-Device Communication Security Laboratory  
**Institution:** Politecnico di Torino — Dipartimento di Automatica ed Informatica  
**Instructor:** Marco Mellia  

---

## Overview

The goal of this lab is to understand Wireshark as a network analyser/sniffer, measure the performance of a WLAN across different physical setups using **iperf3**, and analyse 802.11 frames in monitor mode. All three testbed configurations are performed on the **same network and same Access Point**.

### Team

| Member | Testbed responsibility |
|--------|----------------------|
| **Marco** | Ethernet client → Ethernet server (baseline) |
| **Federico** | WiFi client → Ethernet server |
| **Fabio** | WiFi client → WiFi client | 

> **Important note:** All three configurations must share the same network and AP. The WiFi–WiFi scenario is **not** done over a phone hotspot — both machines connect to the same AP used in the other tests.

---

## Tools Required

| Tool | Purpose | Link |
|------|---------|------|
| **iperf3** | Goodput measurement | https://iperf.fr |
| **Wireshark** | Packet capture & analysis | https://www.wireshark.org |
| **aircrack-ng** | 802.11 monitor mode & packet injection | https://aircrack-ng.org |
| **hashcat** | WPA password cracking | https://hashcat.net/hashcat |
| **tcpdump** | Force WiFi into monitor mode if Wireshark is picky | https://www.tcpdump.org |

### Installation

**Ubuntu:**
```bash
sudo apt update
sudo apt install iperf3 wireshark aircrack-ng hashcat tcpdump
# Add your user to the wireshark group to capture without root
sudo usermod -aG wireshark $USER
newgrp wireshark
```

**macOS (Homebrew):**
```bash
brew install iperf3 wireshark aircrack-ng hashcat
```

---

## Phase 1 — Setup & Verification (Everyone)

Before any test, all team members must complete these steps on their machines.

- [ ] Install and verify iperf3: `iperf3 --version`
- [ ] Install and launch Wireshark at least once to verify interface permissions
- [ ] Open the firewall for iperf3 (default port TCP/UDP **5201**):
  ```bash
  # Ubuntu
  sudo ufw allow 5201
  ```
- [ ] Note down the IP address of every device:
  ```bash
  # Ubuntu
  ip a
  # macOS
  ifconfig
  ```
- [ ] Verify basic connectivity before any test:
  ```bash
  ping <destination_IP>
  ```

---

## Phase 2 — Testbed Configuration

All machines connect to **the same AP and the same subnet**.

### Marco — Ethernet client ↔ Ethernet server (Ubuntu)

- [ ] Connect both PCs to the same network via Ethernet cable (direct or through the AP/switch)
- [ ] Check Ethernet link speed:
  ```bash
  ethtool eth0
  # or, if using predictable interface names:
  ethtool enp3s0
  ```
- [ ] Note the negotiated speed (e.g. 100 Mbit/s or 1 Gbit/s)
- [ ] Confirm both PCs are on the same subnet and can ping each other

### Federico — WiFi client ↔ Ethernet server (Ubuntu)

- [ ] Connect one PC to the AP via Ethernet cable, the other via WiFi — **same AP, same subnet**
- [ ] Check WiFi link speed:
  ```bash
  iw dev wlan0 link
  # or
  iwconfig wlan0
  ```
- [ ] Note the WiFi channel, band (2.4 GHz / 5 GHz), and negotiated MCS rate
- [ ] Confirm both PCs can ping each other across the mixed link

### Fabio — WiFi client ↔ WiFi client (macOS)

- [ ] Connect **both** machines to the same AP via WiFi (the same AP used in the other tests)
- [ ] Check WiFi link speed:
  ```bash
  sudo wdutil info
  # or: hold Option (⌥) and click the WiFi icon in the menu bar
  ```
- [ ] Note RSSI, MCS rate, and channel width on both clients — these help explain throughput results
- [ ] Confirm both machines can ping each other

---

## Phase 3 — Performance Testing with iperf3

All three configurations follow the same procedure. **Always read the result on the receiver** — this is the goodput figure.

### Common procedure (all configurations)

1. **Start the server** on the receiving machine:
   ```bash
   iperf3 -s
   ```

2. **Start Wireshark** on the receiver on the correct interface **before** launching the client. This ensures the TCP handshake is captured.

3. **TCP baseline test** (10 seconds):
   ```bash
   iperf3 -c <server_IP> -t 10
   ```

4. **Save the .pcap** immediately after each test with a descriptive name:
   ```
   marco_eth_eth_TCP.pcap
   federico_wifi_eth_TCP.pcap
   fabio_wifi_wifi_TCP.pcap
   ```

5. **UDP test** (set a target bitrate close to the expected link capacity):
   ```bash
   iperf3 -c <server_IP> -u -b 100M -t 10
   ```
   Save the corresponding .pcap.

6. Record the throughput (bit/s) reported by iperf3 on the **receiver** side.

### Additional test — Marco (wired baseline)

```bash
# 4 parallel streams — check if throughput scales vs single stream
iperf3 -c <server_IP> -P 4 -t 10
```

---

## Phase 4 — Wireshark Analysis

### 4a — TCP/UDP analysis (all configurations)

For each saved .pcap:

| Analysis | How to access | What to look for |
|----------|--------------|-----------------|
| **I/O Graph** | Statistics → I/O Graph | Add TCP Received and TCP Transmitted curves; set Interval to 100 ms; check for throughput stability |
| **Stevens TCP Graph** | Select a packet → Statistics → TCP Stream Graphs → Time-Sequence (Stevens) | Slope = throughput; flat segments or drops = retransmissions / congestion |
| **Throughput Plot** | Statistics → TCP Stream Graphs → Throughput | Average throughput and variance across the transfer |
| **Round-Trip Time** | Statistics → TCP Stream Graphs → Round-Trip Time | Compare RTT between wired and WiFi testbeds |
| **Conversations** | Statistics → Conversations → TCP tab | Bytes transferred, duration, per-stream throughput |

**Useful display filters:**
```
tcp.stream eq 0           # isolate the first TCP stream
udp                       # show only UDP traffic
ip.addr == <server_IP>    # filter by host
```

### 4b — 802.11 frame monitoring (Federico + Fabio)

**Ubuntu** — enable monitor mode on the wireless interface before starting Wireshark:

```bash
sudo ip link set wlan0 down
sudo iw wlan0 set monitor control
sudo ip link set wlan0 up
```

Restore managed mode after the lab:
```bash
sudo ip link set wlan0 down
sudo iw wlan0 set type managed
sudo ip link set wlan0 up
```

**macOS** — Wireshark can capture 802.11 frames directly using the standard Airport interface. Select the `en0` interface in Wireshark — no manual monitor mode setup is needed.  
Alternatively, use the built-in Wireless Diagnostics sniffer:
```
Wireless Diagnostics → Window menu → Sniffer
# Captures saved to /var/tmp/
```

**Key 802.11 display filters (from the reference sheet):**

| Goal | Filter |
|------|--------|
| All management frames | `wlan.fc.type == 0` |
| Beacon frames | `wlan.fc.type_subtype == 8` |
| Authentication frames | `wlan.fc.type_subtype == 11` |
| Association requests | `wlan.fc.type_subtype == 0` |
| All data frames | `wlan.fc.type == 2` |
| QoS Data (used by iperf3) | `wlan.fc.type_subtype == 40` |
| ACK frames | `wlan.fc.type_subtype == 29` |
| RTS frames | `wlan.fc.type_subtype == 27` |
| CTS frames | `wlan.fc.type_subtype == 28` |
| Filter by AP (BSSID) | `wlan.bssid == <AP_MAC>` |
| Filter by client (MAC) | `wlan.addr == <client_MAC>` |
| Filter by SSID | `wlan_mgt.ssid == "your_SSID"` |

**RadioTap header filters (signal & rate):**

```
radiotap.dbm_antsignal >= -70      # filter by minimum signal strength (RSSI)
radiotap.datarate == 54            # filter by data rate in Mbit/s
radiotap.channel.freq == 5240      # filter by channel frequency in MHz
```

**What to observe:**
- During association: Probe Request → Probe Response → Authentication → Association Request → Association Response
- During the iperf3 transfer: large proportion of QoS Data frames and ACKs
- Presence or absence of RTS/CTS (depends on frame size threshold)
- RSSI and MCS rate in RadioTap headers — correlate these with iperf3 throughput results

---

## Phase 5 — Results Comparison & Report

### Summary table to fill in

| Setup | TCP goodput | UDP goodput | Avg RTT | Notes |
|-------|-------------|-------------|---------|-------|
| ETH–ETH (Marco) | | | | |
| WiFi–ETH (Federico) | | | | |
| WiFi–WiFi (Fabio) | | | | |

### Report checklist

- [ ] Description of each physical testbed: link standard (e.g. 802.11ac 5 GHz), distance to AP, any notable interference
- [ ] Screenshot: I/O Graph for each configuration
- [ ] Screenshot: Stevens TCP graph for each configuration
- [ ] Screenshot: Throughput plot for each configuration
- [ ] Screenshot: RTT plot — compare wired vs WiFi
- [ ] Screenshot: Wireshark 802.11 Management frames (beacon, auth, association)
- [ ] Screenshot: Data frames during iperf3 transfer (with QoS Data filter applied)
- [ ] Comment on throughput differences and link them to the physical characteristics of each medium
- [ ] Summary table (above) with all measured values

---

## Quick Reference — iperf3 Commands

```bash
# Server (receiver)
iperf3 -s

# TCP test, 10 seconds
iperf3 -c <IP> -t 10

# UDP test, 100 Mbit/s target, 10 seconds
iperf3 -c <IP> -u -b 100M -t 10

# 4 parallel TCP streams
iperf3 -c <IP> -P 4 -t 10

# Reverse mode (server sends, client receives)
iperf3 -c <IP> -R -t 10
```

---

## References

- Wireshark Display Filters: https://wiki.wireshark.org/DisplayFilters
- Wireshark Wi-Fi filters: https://wiki.wireshark.org/Wi-Fi
- iperf3 documentation: https://iperf.fr/iperf-doc.php
- aircrack-ng: https://aircrack-ng.org/doku.php?id=aireplay-ng
- 802.11 Wireshark filter reference sheet: see `wireshark_802_11_filters_reference_sheet` in this repo