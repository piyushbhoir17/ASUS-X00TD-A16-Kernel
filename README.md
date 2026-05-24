# ASUS X00TD (SDM636) Android 16 Hybrid Kernel Build Tree

This repository contains the complete Device Tree (DTS) patches, AnyKernel3 custom configurations, and tools used to build **test6.zip** for the ASUS Zenfone Max Pro M1 (X00TD) running Android 16.

This unique hybrid setup resolves both the broken camera/flash drivers (present in other unified SDM660 kernels) and broken media playback/ccodec issues (present in standard SDM636 binaries).

---

## 📁 Repository Structure

*   **`anykernel/`**: The complete flashable AnyKernel3 template containing:
    *   `Image.gz-dtb`: The genuine Ratibor kernel binary with our patched DTB.
    *   `anykernel.sh`: The installer script containing systemless XML media codec masking and CPU/GPU AI-Booster tunings.
*   **`dts/`**: The decompiled, fully patched `ratibor.dts` source file.
*   **`tools/`**: Python helper scripts used to decompile, verify, and repack the kernel payload.

---

## 🛠️ The Patches & Fixes

### 1. Camera & Actuator Fix (Hardware Level)
*   **CMA Memory Buffer**: Increased the `secure_region` CMA memory allocation inside the Device Tree from **92MB** (`0x5C00000`) to **140MB** (`0x8C00000`) to satisfy Android 16's media framework requirements.
*   **Unified Binary Compatibility**: Preserves Ratibor's camera drivers intact to ensure the physical SDM636 board configurations (VFE, PMIC actuators, and proximity sensors) probe successfully.

### 2. Video Playback & Storage Fix (Systemless Level)
*   **Direct XML Bind-Mounting**: Bypasses KernelSU's `os error 38` modules mounting bug. During boot, a script in `/data/adb/service.d/` binds software-only `media_codecs.xml` files on top of the vendor partition.
*   **Software Fallback**: Disables the broken hardware Qualcomm media service (`vendor.media.omx`), forcing a clean, smooth fallback to Google's optimized software Codec2 decoders (`c2.android.avc.decoder`) for WhatsApp and Gallery playback.
*   **Complete Storage Safety**: Keeps system processes stable to ensure your internal storage and SD card remain fully readable.

### 3. AI & Performance Booster
*   **Virtual Memory (VM)**: Configured `swappiness = 10` for faster loading of heavy AI models and background processes.
*   **CPU EAS Scheduler**: Optimized the `schedutil` governor responsiveness to scale up frequencies instantly under workload.
*   **Adreno GPU**: Boosted devfreq rendering governors to eliminate graphical micro-stutters.
*   **I/O Storage**: Configured `read_ahead_kb = 512` for faster media indexing.

---

## 📦 How to Rebuild the Flashable ZIP

1. Make any adjustments to the device tree `dts/ratibor.dts`.
2. Compile the DTS back to DTB:
   ```bash
   dtc -I dts -O dtb -o ratibor_patched.dtb dts/ratibor.dts
   ```
3. Move `ratibor_patched.dtb` to the root folder.
4. Run the repack tool to merge it with the kernel binary:
   ```bash
   python3 tools/repack_clean.py
   ```
5. Navigate to the `anykernel/` directory and compress it:
   ```bash
   cd anykernel && zip -r9 ../test6.zip *
   ```
