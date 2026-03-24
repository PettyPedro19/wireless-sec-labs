# Android GNSS Spoofing Simulation Tool

This MATLAB-based tool simulates and analyzes GNSS spoofing attacks using raw measurement data from Android devices. It supports both **meaconing** and **signal-level spoofing** scenarios by modifying pseudoranges and reception timestamps based on a defined spoofing location.

## 📌 Overview

The tool modifications from the orginal Google's tool consists of two core functions:

1. **`compute_spoofSatRanges`**  
   Computes geometric satellite ranges from the spoofed location and spoofing-induced range differences wrt measured pseudoranged using a known spoofing position.

2. **`emulateSpoofing`**  
   Modifies GNSS reception times to reflect spoofing effects by injecting per-satellite pseudorange biases, a common spoofing delay, and realistic measurement noise.

These functions work together to emulate how a GNSS receiver would behave under spoofing conditions, enabling analysis, visualization, or testing of spoof detection algorithms.
The result is a cyberspoofing attack where reception time measurments are replaced by spoofed measurements.

---

## 🧭 Workflow

1. **Input Data**
   - GNSS raw measurements (`gnssRaw`) from Android devices.
   - Satellite positions and PVT solution (`gpsPvt`).
   - Spoofing parameters including spoofing location and attack start time (`spoof`).

2. **Compute Spoofed Ranges**
   - Use `compute_spoofSatRanges` to:
     - Convert spoofing location from LLA to ECEF.
     - Compute spoofed satellite-to-spoofer ranges.
     - Calculate differences from real pseudoranges and spoofed-position-derived pseudoranges.

3. **Simulate Spoofing Effect**
   - Use `emulateSpoofing` to:
     - Modify `tRxSeconds` (reception time) for each satellite.
     - Inject satellite-specific range offsets, spoof delay, and Gaussian noise.
     - Apply spoofing only after `spoof.t_start`.

4. **Output**
   - Modified `tRxSeconds` representing spoofed GNSS measurements.
   - Useful for spoofed PVT computation or spoof detection testing.

---

## 🧪 Use Cases

- Testing spoof detection algorithms in software.
- Educational demonstrations of spoofing impact on GNSS receivers.
- Security evaluation for GNSS-based mobile applications.
- Validation of receiver resilience against meaconing or signal simulation attacks.

---

## 🔧 Requirements

- MATLAB R2021a or later recommended.
- GNSS measurement data (e.g., from Android GNSS Logger).

---

## 📂 Functions

### `compute_spoofSatRanges(gnssMeas, gpsPvt, spoof)`
- Computes spoofed satellite ranges and range differences.

### `emulateSpoofing(gnssRaw, spoof, tRxSeconds)`
- Modifies reception times to simulate spoofing impact on measurements.

---

## 📄 License

This tool is intended for educational and research purposes. Please cite relevant work if used in academic publications and consider Google's original work license.

---

## 📫 Contact

For questions or collaboration inquiries, please contact Andrea Nardin at [andrea.nardin@polito.it].

