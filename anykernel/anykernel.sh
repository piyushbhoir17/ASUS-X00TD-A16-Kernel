### AnyKernel3 Ramdisk Mod Script
### Modified by @RissuDesu
## osm0sis @ xda-developers

### AnyKernel setup
# global properties
properties() { '
kernel.string=DerHimmel @ rsuntkOrgs
do.devicecheck=0
do.modules=0
do.systemless=0
do.cleanup=1
do.cleanuponabort=0
device.name1=X00TD
device.name2=X00TDA
device.name3=ASUS_X00TD
device.name4=ASUS_X00TDA
device.name5=
supported.versions=
supported.patchlevels=
supported.vendorpatchlevels=
'; } # end properties


### AnyKernel install
## boot files attributes
boot_attributes() {
set_perm_recursive 0 0 755 644 $RAMDISK/*;
set_perm_recursive 0 0 750 750 $RAMDISK/init* $RAMDISK/sbin;
} # end attributes

# boot shell variables
BLOCK=/dev/block/platform/soc/c0c4000.sdhci/by-name/boot;
IS_SLOT_DEVICE=0;
RAMDISK_COMPRESSION=auto;
PATCH_VBMETA_FLAG=auto;

# import functions/variables and setup patching - see for reference (DO NOT REMOVE)
. tools/ak3-core.sh;

# boot install
dump_boot; # use split_boot to skip ramdisk unpack, e.g. for devices with init_boot ramdisk

write_boot; # use flash_boot to skip ramdisk repack, e.g. for devices with init_boot ramdisk

# Disable hardware media codecs to force software C2 fallback systemlessly
if mount -o rw,remount /data 2>/dev/null || mount /data 2>/dev/null; then
  if [ -d /data/adb ]; then
    # Create the service.d directory if it does not exist
    mkdir -p /data/adb/service.d
    
    ui_print "- Installing boot-time bind-mount & AI-Booster script...";
    SVCSCRIPT="/data/adb/service.d/disable_hw_media.sh"
    
    # Write the boot-time bind-mount & performance optimization script
    cat <<'EOF' > "$SVCSCRIPT"
#!/system/bin/sh
# Wait for partitions to be fully mounted
sleep 5

# 1. Dynamically read ROM media configs and disable only hardware encoders
# (This keeps hardware decoders like VP9/HEVC active for smooth 1080p60 YouTube!)
cp /vendor/etc/media_codecs.xml /data/adb/media_codecs_custom.xml
cp /vendor/etc/media_codecs_vendor.xml /data/adb/media_codecs_vendor_custom.xml

sed -i 's/OMX.qcom.video.encoder/OMX.qcom.video.encoder.disabled/g' /data/adb/media_codecs_custom.xml
sed -i 's/OMX.qcom.video.encoder/OMX.qcom.video.encoder.disabled/g' /data/adb/media_codecs_vendor_custom.xml

# 2. Bind mount our custom XML configs on top of vendor files systemlessly
mount --bind /data/adb/media_codecs_custom.xml /vendor/etc/media_codecs.xml
mount --bind /data/adb/media_codecs_vendor_custom.xml /vendor/etc/media_codecs_vendor.xml

# 3. Restart mediacodec gracefully just once to reload the XMLs
killall -9 android.hardware.media.omx@1.0-service
pkill -f -9 mediacodec

# ====================================================
# ANTIGRAVITY AI & PERFORMANCE BOOSTER TUNINGS
# ====================================================

# 1. Virtual Memory (VM) Tuning for Fast AI Model Loading
# Reduce swap overhead and optimize memory allocation pages
echo "10" > /proc/sys/vm/swappiness
echo "100" > /proc/sys/vm/vfs_cache_pressure
echo "90" > /proc/sys/vm/dirty_ratio
echo "5" > /proc/sys/vm/dirty_background_ratio

# 2. CPU Governor Responsive Scheduling (schedutil / EAS)
# Make CPU scale up frequencies instantly under AI/system load
for governor in /sys/devices/system/cpu/cpufreq/policy*/schedutil; do
  if [ -d "$governor" ]; then
    echo "500" > "$governor/up_rate_limit_us" 2>/dev/null
    echo "20000" > "$governor/down_rate_limit_us" 2>/dev/null
  fi
done

# 3. Adreno GPU Governor Tuning for aggressive render scaling
echo "msm-adreno-tz" > /sys/class/kgsl/kgsl-3d0/devfreq/governor
echo "0" > /sys/class/kgsl/kgsl-3d0/bus_split 2>/dev/null
echo "1" > /sys/class/kgsl/kgsl-3d0/force_bus_on 2>/dev/null
echo "1" > /sys/class/kgsl/kgsl-3d0/force_clk_on 2>/dev/null
echo "0" > /sys/class/kgsl/kgsl-3d0/force_no_nap 2>/dev/null

# 4. Storage I/O Read-Ahead size optimization (Fast media reading)
echo "512" > /sys/block/mmcblk0/queue/read_ahead_kb 2>/dev/null
echo "512" > /sys/block/mmcblk1/queue/read_ahead_kb 2>/dev/null
EOF

    # Set correct permissions
    chmod 644 /data/adb/media_codecs_custom.xml
    chmod 644 /data/adb/media_codecs_vendor_custom.xml
    chmod 755 "$SVCSCRIPT"
    
    # Clean up any leftover old KernelSU modules to keep active modules clean
    if [ -d /data/adb/modules/disable_hw_media ]; then
      rm -rf /data/adb/modules/disable_hw_media
      ui_print "- Cleaned up legacy module folder successfully.";
    fi
    
    ui_print "- Safe media patch & AI-Booster successfully installed!";
  else
    ui_print "- KernelSU/Magisk not detected on active device. Skipping media codec patch.";
  fi
fi
## end boot install

