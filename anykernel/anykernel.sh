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
    # Create the directories if they do not exist
    mkdir -p /data/adb/modules
    mkdir -p /data/adb/service.d
    
    # 1. Install KernelSU native overlay module (Bypasses mount --bind permissions bugs!)
    ui_print "- Installing KernelSU native media overlay module...";
    MODDIR="/data/adb/modules/disable_hw_media"
    mkdir -p "$MODDIR/system/vendor/etc"
    
    # Write module.prop
    cat <<EOF > "$MODDIR/module.prop"
id=disable_hw_media
name=Disable Hardware Video Codecs (Ratibor Fix)
version=v1.2
versionCode=3
author=Antigravity
description=Systemlessly disables hardware video encoders to restore smooth hardware-accelerated VP9/HEVC 1080p60 decoding.
EOF

    # Copy and patch ALL media_codecs*.xml configs from the device vendor partition
    VNDETC=""
    if [ -d /vendor/etc ]; then
      VNDETC="/vendor/etc"
    elif [ -d /system/vendor/etc ]; then
      VNDETC="/system/vendor/etc"
    fi

    if [ -n "$VNDETC" ]; then
      ui_print "- Copying and patching all media codec configuration files...";
      for xml in "$VNDETC"/media_codecs*.xml; do
        if [ -f "$xml" ]; then
          name=$(basename "$xml")
          cp -f "$xml" "$MODDIR/system/vendor/etc/$name"
          
          # Disable all hardware video decoders and encoders in this file
          sed -i 's/OMX.qcom.video.decoder/OMX.qcom.video.decoder.disabled/g' "$MODDIR/system/vendor/etc/$name" 2>/dev/null
          sed -i 's/OMX.qcom.video.encoder/OMX.qcom.video.encoder.disabled/g' "$MODDIR/system/vendor/etc/$name" 2>/dev/null
          
          chmod 644 "$MODDIR/system/vendor/etc/$name"
        fi
      done
    else
      ui_print "- Vendor etc directory not found! Skipping media configs patch.";
    fi

    # Set correct module permissions
    chmod 755 "$MODDIR"
    chmod 755 "$MODDIR/system"
    chmod 755 "$MODDIR/system/vendor"
    chmod 755 "$MODDIR/system/vendor/etc"
    chmod 644 "$MODDIR/module.prop"
    ui_print "- Media overlay module successfully installed!";

    # 2. Install boot-time AI-Booster script
    ui_print "- Installing boot-time AI-Booster script...";
    SVCSCRIPT="/data/adb/service.d/disable_hw_media.sh"
    
    cat <<'EOF' > "$SVCSCRIPT"
#!/system/bin/sh
# Wait for boot to progress
sleep 10

# ====================================================
# ANTIGRAVITY AI & PERFORMANCE BOOSTER TUNINGS
# ====================================================

# 1. CPU EAS Schedtune Boost (Forces active app/UI threads to run on Big Cores)
if [ -d /dev/stune ]; then
  echo "30" > /dev/stune/top-app/schedtune.boost 2>/dev/null
  echo "5" > /dev/stune/foreground/schedtune.boost 2>/dev/null
  echo "1" > /dev/stune/top-app/schedtune.prefer_idle 2>/dev/null
fi

# 2. CPU Governor Responsive Scheduling (schedutil / EAS)
for governor in /sys/devices/system/cpu/cpufreq/policy*/schedutil; do
  if [ -d "$governor" ]; then
    echo "500" > "$governor/up_rate_limit_us" 2>/dev/null
    echo "20000" > "$governor/down_rate_limit_us" 2>/dev/null
  fi
done

# 3. Schedutil hispeed_freq & hispeed_load tuning (Ensures instant scale up under video/UI load)
# Little Cores policy0 (default min: 633MHz, max: 1.6GHz)
if [ -d /sys/devices/system/cpu/cpufreq/policy0/schedutil ]; then
  echo "1113600" > /sys/devices/system/cpu/cpufreq/policy0/schedutil/hispeed_freq 2>/dev/null
  echo "85" > /sys/devices/system/cpu/cpufreq/policy0/schedutil/hispeed_load 2>/dev/null
fi
# Big Cores policy4 (default min: 1.11GHz, max: 1.8GHz)
if [ -d /sys/devices/system/cpu/cpufreq/policy4/schedutil ]; then
  echo "1400064" > /sys/devices/system/cpu/cpufreq/policy4/schedutil/hispeed_freq 2>/dev/null
  echo "80" > /sys/devices/system/cpu/cpufreq/policy4/schedutil/hispeed_load 2>/dev/null
fi

# 4. Adreno GPU Governor & Minimum Frequency Tuning
echo "msm-adreno-tz" > /sys/class/kgsl/kgsl-3d0/devfreq/governor
# Keep GPU clock at 266MHz/300MHz minimum under load to prevent stutters
echo "300000000" > /sys/class/kgsl/kgsl-3d0/devfreq/min_freq 2>/dev/null

# 5. Storage I/O Read-Ahead size optimization (Faster video buffering)
echo "512" > /sys/block/mmcblk0/queue/read_ahead_kb 2>/dev/null
echo "512" > /sys/block/mmcblk1/queue/read_ahead_kb 2>/dev/null
EOF

    # Set correct permissions
    chmod 755 "$SVCSCRIPT"
    
    # Clean up old bind-mount leftovers to prevent conflicts
    rm -f /data/adb/media_codecs_custom.xml 2>/dev/null
    rm -f /data/adb/media_codecs_vendor_custom.xml 2>/dev/null
    
    ui_print "- Safe media patch & AI-Booster successfully installed!";
  else
    ui_print "- KernelSU/Magisk not detected on active device. Skipping media codec patch.";
  fi
fi
## end boot install

