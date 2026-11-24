SKIPUNZIP=1

[ "$BOOTMODE" = true ] || abort "! Use Magisk app"

unzip -p "$ZIPFILE" preflight.sh > "$TMPDIR/s20fe-install.sh" \
    || abort "! Extraction failed"

sh "$TMPDIR/s20fe-install.sh" "$ZIPFILE" \
    || abort "! Installation failed. Read recovery messages."

cp "$TMPDIR/module.prop" "$MODPATH/module.prop"
touch "$MODPATH/skip_mount"

ui_print "- CUSTOM KERNEL INSTALLED"
ui_print "- BOOT CHECKSUM VERIFIED"
ui_print "- REBOOT REQUIRED"
