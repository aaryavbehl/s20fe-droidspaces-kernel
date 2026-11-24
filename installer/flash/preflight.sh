#!/system/bin/sh
set -eu

ZIP="$1"
BOOT=/dev/block/by-name/boot
MB=/data/adb/magisk/magiskboot
ORIGINAL=85d2f10b3eb07e46a6e144fbb0a713270856b797f56c16b029432cfbb28d5c1e
KERNEL=9f33ed8de629160ae531c73996c439101a38dfae9d488129e899003cccde5080

hash() {
    sha256sum "$1" | awk '{print $1}'
}

echo "=== DEVICE VALIDATION ==="

[ "$(/system/bin/getprop ro.product.device)" = r8q ]
[ "$(/system/bin/getprop ro.product.model)" = SM-G781B ]
[ "$(/system/bin/getprop ro.build.id)" = CP2A.260605.016 ]
[ -x "$MB" ]
[ -b "$BOOT" ]
[ "$(blockdev --getsize64 "$BOOT")" = 67108864 ]
[ "$(hash "$BOOT")" = "$ORIGINAL" ]

echo "Device and original boot verified"

WORK=$(mktemp -d /data/local/tmp/r8q-preflight.XXXXXX)
trap 'rm -rf "$WORK"' EXIT

mkdir "$WORK/old" "$WORK/new" "$WORK/verify"

dd if="$BOOT" of="$WORK/original.img" bs=4194304
[ "$(hash "$WORK/original.img")" = "$ORIGINAL" ]

unzip -p "$ZIP" Image > "$WORK/Image"
[ "$(hash "$WORK/Image")" = "$KERNEL" ]

echo "=== UNPACK ORIGINAL BOOT ==="

cd "$WORK/old"
"$MB" unpack -n "$WORK/original.img"

[ -s kernel ]
[ -s ramdisk.cpio ]
[ -s dtb ]

cp -a "$WORK/old/." "$WORK/new/"
cp "$WORK/Image" "$WORK/new/kernel"

echo "=== REPACK TEST IMAGE ==="

cd "$WORK/new"
unset PATCHVBMETAFLAG
"$MB" repack -n "$WORK/original.img" "$WORK/candidate.img"

[ -s "$WORK/candidate.img" ]
[ "$(stat -c %s "$WORK/candidate.img")" -le 67108864 ]

echo "=== VERIFY REPACKED IMAGE ==="

cd "$WORK/verify"
"$MB" unpack -n "$WORK/candidate.img"

cmp kernel "$WORK/Image"
echo "PASS: replacement kernel"

for part in ramdisk.cpio dtb kernel_dtb second extra recovery_dtbo
do
    if [ -f "$WORK/old/$part" ]; then
        cmp "$part" "$WORK/old/$part"
        echo "PASS: preserved $part"
    else
        [ ! -e "$part" ]
    fi
done

echo "Candidate image size:"
stat -c %s "$WORK/candidate.img"

echo "Candidate SHA256:"
sha256sum "$WORK/candidate.img"

[ "$(hash "$BOOT")" = "$ORIGINAL" ]

echo "PASS: original boot partition unchanged"

echo "=== FINAL FLASH VALIDATION ==="

[ "$(hash "$BOOT")" = "$ORIGINAL" ]
[ "$(hash "$WORK/original.img")" = "$ORIGINAL" ]
[ "$(stat -c %s "$WORK/candidate.img")" = 67108864 ]

EXPECTED=$(hash "$WORK/candidate.img")

echo "=== FLASHING CUSTOM KERNEL ==="

if ! dd if="$WORK/candidate.img" of="$BOOT" bs=4194304 ||
   ! sync ||
   [ "$(hash "$BOOT")" != "$EXPECTED" ]; then

    echo "FLASH FAILED - ATTEMPTING ROLLBACK"

    if dd if="$WORK/original.img" of="$BOOT" bs=4194304 &&
       sync &&
       [ "$(hash "$BOOT")" = "$ORIGINAL" ]; then
        echo "ORIGINAL BOOT RESTORED"
    else
        echo "CRITICAL: USE EXTERNAL RECOVERY"
        echo "DO NOT REBOOT NORMALLY"
    fi

    exit 1
fi

echo "PASS: flashed boot checksum verified"
echo "=== KERNEL INSTALLATION SUCCESSFUL ==="
echo "Reboot required to activate custom kernel"

