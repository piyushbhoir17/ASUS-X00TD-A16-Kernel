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

    # Copy and patch the XML configs directly in the recovery environment
    # (Tries both possible mount paths)
    if [ -f /vendor/etc/media_codecs.xml ]; then
      cp -f /vendor/etc/media_codecs.xml "$MODDIR/system/vendor/etc/media_codecs.xml"
      cp -f /vendor/etc/media_codecs_vendor.xml "$MODDIR/system/vendor/etc/media_codecs_vendor.xml"
    elif [ -f /system/vendor/etc/media_codecs.xml ]; then
      cp -f /system/vendor/etc/media_codecs.xml "$MODDIR/system/vendor/etc/media_codecs.xml"
      cp -f /system/vendor/etc/media_codecs_vendor.xml "$MODDIR/system/vendor/etc/media_codecs_vendor.xml"
    fi

    # Disable hardware encoders and hardware H.264/legacy decoders to restore smooth software fallback
    # (While keeping hardware VP9 and HEVC decoders active for 1080p60 YouTube!)
    sed -i 's/OMX.qcom.video.encoder/OMX.qcom.video.encoder.disabled/g' "$MODDIR/system/vendor/etc/media_codecs.xml" 2>/dev/null
    sed -i 's/OMX.qcom.video.encoder/OMX.qcom.video.encoder.disabled/g' "$MODDIR/system/vendor/etc/media_codecs_vendor.xml" 2>/dev/null
    
    sed -i 's/OMX.qcom.video.decoder.avc/OMX.qcom.video.decoder.avc.disabled/g' "$MODDIR/system/vendor/etc/media_codecs.xml" 2>/dev/null
    sed -i 's/OMX.qcom.video.decoder.avc/OMX.qcom.video.decoder.avc.disabled/g' "$MODDIR/system/vendor/etc/media_codecs_vendor.xml" 2>/dev/null
    
    sed -i 's/OMX.qcom.video.decoder.mpeg4/OMX.qcom.video.decoder.mpeg4.disabled/g' "$MODDIR/system/vendor/etc/media_codecs.xml" 2>/dev/null
    sed -i 's/OMX.qcom.video.decoder.mpeg4/OMX.qcom.video.decoder.mpeg4.disabled/g' "$MODDIR/system/vendor/etc/media_codecs_vendor.xml" 2>/dev/null
    
    sed -i 's/OMX.qcom.video.decoder.h263/OMX.qcom.video.decoder.h263.disabled/g' "$MODDIR/system/vendor/etc/media_codecs.xml" 2>/dev/null
    sed -i 's/OMX.qcom.video.decoder.h263/OMX.qcom.video.decoder.h263.disabled/g' "$MODDIR/system/vendor/etc/media_codecs_vendor.xml" 2>/dev/null

    # Set correct module permissions
    chmod 755 "$MODDIR"
    chmod 755 "$MODDIR/system"
    chmod 755 "$MODDIR/system/vendor"
    chmod 755 "$MODDIR/system/vendor/etc"
    chmod 644 "$MODDIR/module.prop"
    chmod 644 "$MODDIR/system/vendor/etc/media_codecs.xml" 2>/dev/null
    chmod 644 "$MODDIR/system/vendor/etc/media_codecs_vendor.xml" 2>/dev/null
    ui_print "- Media overlay module successfully installed!";

    # 2. Install boot-time AI-Booster script
    ui_print "- Installing boot-time AI-Booster script...";
    SVCSCRIPT="/data/adb/service.d/disable_hw_media.sh"
    
    cat <<'EOF' > "$SVCSCRIPT"
#!/system/bin/sh
# Wait for boot to progress
sleep 5

# ====================================================
# ANTIGRAVITY AI & PERFORMANCE BOOSTER TUNINGS
# ====================================================

# 1. CPU Governor Responsive Scheduling (schedutil / EAS)
for governor in /sys/devices/system/cpu/cpufreq/policy*/schedutil; do
  if [ -d "$governor" ]; then
    echo "500" > "$governor/up_rate_limit_us" 2>/dev/null
    echo "20000" > "$governor/down_rate_limit_us" 2>/dev/null
  fi
done

# 2. Adreno GPU Governor Tuning
echo "msm-adreno-tz" > /sys/class/kgsl/kgsl-3d0/devfreq/governor

# 3. Storage I/O Read-Ahead size optimization
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

