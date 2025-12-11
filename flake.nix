{
  description = "NixOS for Orange Pi 6 Plus (Cix P1 SoC)";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";

    nixos-generators = {
      url = "github:nix-community/nixos-generators";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = { self, nixpkgs, nixos-generators, ... }@inputs:
    let
      system = "aarch64-linux";

      # For cross-compilation from x86_64
      # buildSystem = "x86_64-linux";

      pkgs = import nixpkgs {
        inherit system;
        config.allowUnfree = true;
      };

      # Import our custom packages
      cixPackages = import ./pkgs { inherit pkgs; };

    in {
      # Custom packages
      packages.${system} = {
        inherit (cixPackages)
          linux-cix
          cix-gpu-driver
          cix-npu-driver
          cix-vpu-driver
          cix-isp-driver
          cix-gpu-umd
          cix-isp-umd
          cix-vpu-umd
          cix-audio-dsp
          cix-noe-umd
          cix-firmware
          # Realtek WiFi modules (out-of-tree)
          rtl8192eu
          rtl8812au
          rtl8723ds
          rtl8821cu
          rtl88x2bu;

        # Default package is the full system image
        default = self.images.${system}.raw-efi;
      };

      # Overlay for use in other flakes
      overlays.default = final: prev:
        import ./pkgs { pkgs = prev; };

      # ===================
      # NIXOS MODULES (for use in other flakes)
      # ===================
      # NOTE: These modules do NOT set nixpkgs.overlays. Consumers should apply
      # overlays.default at the flake level to make packages available via pkgs.
      nixosModules = {
        # Complete Orange Pi 6 Plus support (includes all modules)
        orangepi6plus = { config, lib, pkgs, ... }: {
          imports = [
            self.nixosModules.cix-hardware
            self.nixosModules.cix-drivers
          ];
        };

        # Hardware/board configuration (kernel, boot, platform settings)
        cix-hardware = { config, lib, pkgs, ... }: {
          imports = [ ./nixos/modules/orangepi6plus.nix ];
        };

        # Driver services and userspace components
        cix-drivers = { config, lib, pkgs, ... }: {
          imports = [ ./nixos/modules/cix-drivers.nix ];
        };

        # Base configuration (optional - users may want their own)
        cix-base = { config, lib, pkgs, ... }: {
          imports = [ ./nixos/configuration.nix ];
        };
      };

      # Default module export
      nixosModules.default = self.nixosModules.orangepi6plus;

      # ===================
      # NIXOS CONFIGURATIONS
      # ===================
      nixosConfigurations.orangepi6plus = nixpkgs.lib.nixosSystem {
        inherit system;
        specialArgs = { inherit inputs; };
        modules = [
          {
            nixpkgs.overlays = [ self.overlays.default ];
            nixpkgs.hostPlatform = system;
          }
          ./nixos/configuration.nix
          ./nixos/modules/orangepi6plus.nix
          ./nixos/modules/cix-drivers.nix
        ];
      };

      # Bootable images
      images.${system} = rec {
        # Default: VM-free EFI image (works everywhere, no KVM required)
        # Outputs: orangepi6plus-nixos.img.zst
        raw-efi = let
          nixosConfig = nixpkgs.lib.nixosSystem {
            inherit system;
            specialArgs = { inherit inputs; };
            modules = [
              {
                nixpkgs.overlays = [ self.overlays.default ];
                nixpkgs.hostPlatform = system;
              }
              ./nixos/configuration.nix
              ./nixos/modules/orangepi6plus.nix
              ./nixos/modules/cix-drivers.nix
            ];
          };
        in import ./nixos/lib/make-efi-image.nix {
          inherit pkgs;
          inherit (pkgs) lib;
          config = nixosConfig.config;
          diskSize = "5G";
          espSize = "512M";
        };

        # VM-based EFI image (requires working KVM)
        # Use this if you have a builder with functional KVM for potentially faster builds
        raw-efi-vm = nixos-generators.nixosGenerate {
          inherit system;
          format = "raw-efi";
          specialArgs = { inherit inputs; };
          modules = [
            {
              nixpkgs.overlays = [ self.overlays.default ];
              nixpkgs.hostPlatform = system;
            }
            ./nixos/configuration.nix
            ./nixos/modules/orangepi6plus.nix
            ./nixos/modules/cix-drivers.nix
            {
              # Image-specific settings
              virtualisation.diskSize = 8192; # 8GB
            }
          ];
        };
      };

      # Development shell for building
      devShells.${system}.default = pkgs.mkShell {
        buildInputs = with pkgs; [
          git
          gnumake
          gcc
          flex
          bison
          bc
          openssl
          elfutils
          ncurses
          scons
          python3
          nix-prefetch-git  # For updating source hashes
        ];

        shellHook = ''
          echo "Orange Pi 6 Plus NixOS Development Shell"
          echo "Build image: nix build .#images.aarch64-linux.raw-efi"
          echo "Build kernel: nix build .#packages.aarch64-linux.linux-cix"
          echo ""
          echo "To update source hashes: ./scripts/update-hashes.sh"
        '';
      };

      # For x86_64 hosts that want to cross-compile or use binfmt
      devShells.x86_64-linux.default =
        let
          pkgs-x86 = import nixpkgs { system = "x86_64-linux"; };
        in pkgs-x86.mkShell {
          buildInputs = with pkgs-x86; [
            git
            qemu
            nix-prefetch-git
          ];

          shellHook = ''
            echo "Orange Pi 6 Plus NixOS Cross-Build Shell"
            echo ""
            echo "To build aarch64 packages, ensure binfmt is enabled:"
            echo "  boot.binfmt.emulatedSystems = [ \"aarch64-linux\" ];"
            echo ""
            echo "Then: nix build .#images.aarch64-linux.raw-efi"
          '';
        };

      # For macOS hosts (aarch64-darwin and x86_64-darwin)
      devShells.aarch64-darwin.default =
        let
          pkgs-darwin = import nixpkgs { system = "aarch64-darwin"; };
        in pkgs-darwin.mkShell {
          buildInputs = with pkgs-darwin; [
            git
            nix-prefetch-git
            jq
            curl
          ];

          shellHook = ''
            echo "Orange Pi 6 Plus NixOS Development Shell (macOS)"
            echo ""
            echo "To build aarch64-linux packages, you need a Linux builder:"
            echo "  - Use a remote builder with: --builders 'ssh://user@linux-host aarch64-linux'"
            echo "  - Or use a Linux VM with nix-darwin's linux-builder"
            echo ""
            echo "To update source hashes: ./scripts/update-hashes.sh"
          '';
        };

      devShells.x86_64-darwin.default =
        let
          pkgs-darwin = import nixpkgs { system = "x86_64-darwin"; };
        in pkgs-darwin.mkShell {
          buildInputs = with pkgs-darwin; [
            git
            nix-prefetch-git
            jq
            curl
          ];

          shellHook = ''
            echo "Orange Pi 6 Plus NixOS Development Shell (macOS)"
            echo ""
            echo "To build aarch64-linux packages, you need a Linux builder:"
            echo "  - Use a remote builder with: --builders 'ssh://user@linux-host aarch64-linux'"
            echo "  - Or use a Linux VM"
            echo ""
            echo "To update source hashes: ./scripts/update-hashes.sh"
          '';
        };
    };
}
