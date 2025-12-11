# Custom EFI disk image builder that doesn't require a VM
# Uses LKL tools and direct file operations instead of running QEMU
#
# This is necessary because the standard nixpkgs make-disk-image requires
# KVM, which may not work properly on all aarch64 systems due to CPU
# feature incompatibilities (SVE, etc.)

{ pkgs
, lib
, config
, diskSize ? "8G"
, espSize ? "512M"
, rootLabel ? "nixos"
, espLabel ? "ESP"
, imageName ? "orangepi6plus-nixos"
}:

let
  # The NixOS system toplevel
  toplevel = config.system.build.toplevel;

  # Kernel and initrd
  kernel = "${toplevel}/kernel";
  initrd = "${toplevel}/initrd";

  # Kernel command line
  kernelParams = toString config.boot.kernelParams;

  # GRUB package with EFI support
  grubEfi = pkgs.grub2.override { efiSupport = true; };

  # Build standalone GRUB EFI binary with embedded modules
  grubEfiBinary = pkgs.runCommand "grubaa64.efi" {
    nativeBuildInputs = [ grubEfi ];
  } ''
    grub-mkimage \
      -O arm64-efi \
      -o $out \
      -p /grub \
      part_gpt part_msdos fat ext2 normal boot linux \
      configfile loopback chain efifwsetup efi_gop \
      ls search search_label search_fs_uuid search_fs_file \
      gfxterm gfxterm_background gfxterm_menu test all_video loadenv \
      exfat btrfs iso9660 echo
  '';

  # Create GRUB configuration
  grubCfg = pkgs.writeText "grub.cfg" ''
    set timeout=${toString config.boot.loader.timeout}
    set default=0

    menuentry "NixOS" {
      linux /kernel init=${toplevel}/init ${kernelParams}
      initrd /initrd
    }
  '';

in pkgs.runCommand "${imageName}.img.zst" {
  nativeBuildInputs = with pkgs; [
    util-linux       # sfdisk, mkfs.vfat
    dosfstools       # mkfs.vfat
    e2fsprogs        # mkfs.ext4, mke2fs
    lkl              # cptofs for copying to filesystem images
    gptfdisk         # sgdisk
    coreutils
    gnutar
    zstd
    jq               # for parsing sfdisk JSON output
    mtools           # mcopy for FAT filesystem
  ];

  # Don't require KVM
  requiredSystemFeatures = [];
} ''
  # Calculate sizes
  espSizeBytes=$(numfmt --from=auto ${espSize})
  diskSizeBytes=$(numfmt --from=auto ${diskSize})

  # ESP size in sectors (512 bytes per sector)
  espSizeSectors=$((espSizeBytes / 512))

  # Create sparse disk image (temporary)
  truncate -s ${diskSize} image.img

  # Create GPT partition table with ESP and root partitions
  # Partition 1: ESP (EFI System Partition)
  # Partition 2: Root filesystem
  sfdisk image.img <<EOF
label: gpt
unit: sectors

1 : size=$espSizeSectors, type=C12A7328-F81F-11D2-BA4B-00A0C93EC93B, name="ESP"
2 : type=0FC63DAF-8483-4772-8E79-3D69D8477DE4, name="root"
EOF

  # Get partition offsets
  espStart=$(sfdisk -J image.img | ${pkgs.jq}/bin/jq '.partitiontable.partitions[0].start')
  espSectors=$(sfdisk -J image.img | ${pkgs.jq}/bin/jq '.partitiontable.partitions[0].size')
  rootStart=$(sfdisk -J image.img | ${pkgs.jq}/bin/jq '.partitiontable.partitions[1].start')
  rootSectors=$(sfdisk -J image.img | ${pkgs.jq}/bin/jq '.partitiontable.partitions[1].size')

  espOffset=$((espStart * 512))
  rootOffset=$((rootStart * 512))
  espBytes=$((espSectors * 512))
  rootBytes=$((rootSectors * 512))

  echo "ESP: start=$espStart sectors=$espSectors offset=$espOffset size=$espBytes"
  echo "Root: start=$rootStart sectors=$rootSectors offset=$rootOffset size=$rootBytes"

  # Create ESP filesystem image
  truncate -s $espBytes esp.img
  mkfs.vfat -F 32 -n ${espLabel} esp.img

  # Create directory structure for ESP (GRUB layout)
  mkdir -p esp-contents/EFI/BOOT
  mkdir -p esp-contents/grub

  # Copy GRUB EFI binary to fallback location
  cp ${grubEfiBinary} esp-contents/EFI/BOOT/BOOTAA64.EFI

  # Copy kernel and initrd to ESP root
  cp ${kernel} esp-contents/kernel
  cp ${initrd} esp-contents/initrd

  # Copy GRUB configuration
  cp ${grubCfg} esp-contents/grub/grub.cfg

  # Copy ESP contents to FAT image using mcopy (from mtools)
  ${pkgs.mtools}/bin/mcopy -i esp.img -s esp-contents/* ::

  # Write ESP to disk image
  dd if=esp.img of=image.img bs=512 seek=$espStart conv=notrunc

  # Create root filesystem image
  truncate -s $rootBytes root.img
  mkfs.ext4 -F -L ${rootLabel} root.img

  # Prepare root filesystem contents
  mkdir -p root-contents/nix/store
  mkdir -p root-contents/etc

  # Copy the Nix store closure
  echo "Copying Nix store closure..."
  storePaths=$(cat ${pkgs.closureInfo { rootPaths = [ toplevel ]; }}/store-paths)
  for path in $storePaths; do
    echo "  $path"
    cp -a $path root-contents/nix/store/
  done

  # Create nix-path-registration for the store
  cp ${pkgs.closureInfo { rootPaths = [ toplevel ]; }}/registration root-contents/nix-path-registration

  # Create essential symlinks
  mkdir -p root-contents/etc
  mkdir -p root-contents/bin
  mkdir -p root-contents/sbin

  # Create the /etc/NIXOS marker file
  touch root-contents/etc/NIXOS

  # Create symlink to current system
  mkdir -p root-contents/run
  ln -s ${toplevel} root-contents/run/current-system

  # Copy root filesystem contents using debugfs/e2tools or cptofs
  echo "Copying root filesystem contents..."
  cptofs -t ext4 -i root.img root-contents/* /

  # Write root filesystem to disk image
  dd if=root.img of=image.img bs=512 seek=$rootStart conv=notrunc

  echo "Image created successfully: image.img"

  # Compress the image with zstd
  echo "Compressing image with zstd..."
  zstd -T0 -19 --rm image.img -o $out

  echo "Compressed image created: $out"
  echo ""
  echo "To decompress: zstd -d <file>"
  echo "To write to SD card: zstdcat <file> | sudo dd of=/dev/sdX bs=4M status=progress"
''
