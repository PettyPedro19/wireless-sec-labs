# Wireless Security Lab — GNSS Spoofing on Android

**Course:** Wireless Security — Politecnico di Torino  
**Instructors:** Prof. Marco Mellia, Dr. Andrea Nardin  
**Tool:** `ProcessGnssMeasScript.m` (Google GPS Measurement Tools, modified by NavSAS)

---

## Objective

The lab investigates how Android smartphones expose raw GNSS measurements through system APIs (available since Android 7 / API 24) and how these measurements can be manipulated to simulate a **cyberspoofing** attack — i.e., the injection of a fake position into the victim's GPS receiver.

---

## Key Concepts

### Android Raw Measurements

Starting from Android 7 (Nougat), any device with a GNSS chipset ≥ 2016 exposes raw data through `GnssMeasurement` and `GnssClock`, enabling independent position computation. The fundamental fields are:

- **TimeNanos / FullBiasNanos / BiasNanos** → derive the absolute reception time (GNSS time)
- **ReceivedSvTimeNanos** → satellite transmission time
- **Cn0DbHz** → carrier-to-noise ratio (C/N₀) in dB·Hz
- **AccumulatedDeltaRangeMeters** → carrier phase (ADR)

### Pseudorange

The pseudorange is the raw satellite–receiver distance, still affected by the local clock bias:

```
TxTime  = ReceivedSvTimeNanos
RxTime  = TimeNanos − (FullBiasNanos + BiasNanos) − weekNumberNanos

Pseudorange = (RxTime − TxTime) × c
```

### WLS PVT

The **Weighted Least Squares** solver estimates position, velocity, and time (PVT) by minimising pseudorange residuals weighted by the inverse variance of each measurement. It requires at least 4 satellites with good geometry (low HDOP).

### Simulated Spoofing

The script emulates an attacker that re-broadcasts GPS signals with pseudoranges consistent with a **fake position** (`spoof.position`). The `spoof.delay` parameter adds a delay equivalent to the physical distance between spoofer and victim. The attack is activated after `spoof.t_start` seconds from the start of the log.

---

## Script Pipeline

```
GNSSLogger (.txt)
        │
        ▼
ReadGnssLogger()          ← raw log parsing
        │
        ▼
GetNasaHourlyEphemeris()  ← ephemeris download from NASA CDDIS (internet required)
        │
        ▼
ProcessGnssMeas()         ← pseudorange computation (with or without spoofing)
        │
        ▼
GpsWlsPvt()               ← WLS solution → position, velocity, clock bias
        │
        ▼
Plots h1…h8               ← pseudoranges, C/N₀, PVT, geoplot
```

---

## Configuration Parameters

| Parameter | Description |
|---|---|
| `prFileName` | Name of the `.txt` file exported from GNSSLogger |
| `dirName` | Folder containing the log file |
| `param.llaTrueDegDegM` | True position [lat, lon, alt] — leave `[]` if unknown |
| `spoof.active` | `1` = spoofing enabled, `0` = disabled |
| `spoof.position` | Fake position to inject [lat, lon, alt] |
| `spoof.t_start` | Second from log start at which the attack begins |
| `spoof.delay` | Additional simulated delay [s] — order of milliseconds |

---

## Mandatory Tasks for the Report

| # | Task | Description |
|---|---|---|
| 4 | **Own data collection** | 5-min log with GNSSLogger, MATLAB analysis, comment on plots (open sky, battery mode, C/N₀, visible satellites) |
| 5 | **Spoof your own data** | Set `spoof.position` to nearby real coordinates, analyse effects on PVT, pseudoranges and clock bias |
| 6 | **Spoofing delay** | Add `spoof.delay` in the order of ms, observe effects on the estimated position and other observables |
| 7 *(opt.)* | **Peculiar conditions** | Data collection near interference sources (TV antennas, microwave ovens, etc.) |

---

## Collected Logs

| Log name | Phone | Time | Lat | Lon | Alt (m) | Low Battery Mode | Description |
|---|---|---|---|---|---|---|---|
| dataset_20260318_basket_1 | Marco | 18:42:09 | 45.064881 | 7.657425 | 250 | 0 | Log in openspace in front of I rooms |
| dataset_20260318_basket_2 | Marco | 19:11:24 | 45.064881 | 7.657425 | 250 | 0 | Log in openspace in front of I rooms, second try |
| dataset_20260318_R3 | Marco | 18:24:21| 45.066375 | 7.657918 | 255 | 0 | Log inside room R3 |
| dataset_20260319_outdoor_I | Marco | 13:27:58 | 45.065066 | 7.658469 | 253 | 0 | Log on table outside above rooms I|
| dataset_20260324_dumarey | Marco | 13:45:23 | 45.063878 | 7.658574 | 250 | 0 | Log outside Dumarey building, near high wall of the entrance (Sky plot was visible limited due to the building heigth)|
| dataset_20260324_microonde | Marco | 13:55:48 | 45.064378 | 7.659286 | 250 | 0 | Log measured inside Ex celid room, near window in the microwave room |
| dataset_20260321_Fabio_old | Fabio's old phone | 09:29:53 | 45.031278| 7.721366 | 940 | ? | Maddalena's Antenna |
| dataset_20260321_Fabio_new | Fabio's new phone | 09:29:53 | 45.031278| 7.721366 | 940 | ? | Maddalena's Antenna |
| dataset_20260324_treno | Marco | 17:11:12 | 45.026320 | 7.657475 | 243 | 0 | Coordinates of Lingotto station, log take on train |
| dataset_20260325_basket_old_marco | Marco's old phone | 11:12:58 | 45.064998 | 7.657404 | 250 | 0 | Log computed in front of "black box" |
| dataset_20260325_trainstation_savi | Marco's old phone | 09:41:18 | 44.652009 | 7.663959 | 320 | 0 | Log computed in Savigliano train station |
| datase_20260325_basket_2 | Marco's old phone | 13:53:52 | 45.064595 | 7.657548 | 250 | 0 | Logging using latest version of GNSSLogger |
computed in Savigliano train station |
| datase_20260325_tables_roomrR | Fabio's old phone | 16:18:19 | 45.066525 | 7.657821 | 245 | 1 | Logging using ultra power battery saver |

---

## Notes & Troubleshooting

- Use GNSSLogger **v2.0.0.1** — v3.0.0.1 may break parsing due to the `CodeType` field
- If `GetNasaHourlyEphemeris` fails → manually download the ephemeris from NASA CDDIS for your log's date/time and extract it into `demoFiles/`
- `geoplot` requires MATLAB's **Mapping Toolbox**
- If the ephemeris `.gz` file does not decompress automatically → extract it manually into the `demoFiles/` folder
- The phone's Low Battery mode can cause **HW clock discontinuities** → jumps in pseudoranges unrelated to spoofing
