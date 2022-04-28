{
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable-small";
  };

  outputs = {self, nixpkgs}: {
    nixosConfigurations = {

      kubeServer = nixpkgs.lib.nixosSystem {
        system = "x86_64-linux";
        modules = [
          (import ./qemu-vm.nix)
          ({ pkgs, modulesPath, ... }: {
            imports = [ ];
            boot.kernelPackages = pkgs.linuxPackages_latest;
            services.k3s.enable = true;
            documentation.man.enable = false;
            documentation.doc.enable = false;
            documentation.enable = false;
            services.openssh.enable = true;
            users.users.root.password = "root";
            users.users.root.openssh.authorizedKeys.keys = [ "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIGLJN8Kz3Cn4mMQCPar9j99s5rD7JAP2kUWVleiv2LF8" ];
          })
        ];
      };

      kubeAgent = nixpkgs.lib.nixosSystem {
        system = "x86_64-linux";
        modules = [
          (import ./qemu-vm.nix)
          ({ pkgs, modulesPath, ... }: {
            imports = [ ];
            boot.kernelPackages = pkgs.linuxPackages_latest;
            services.k3s.enable = true;
            documentation.man.enable = false;
            documentation.doc.enable = false;
            documentation.enable = false;
            services.openssh.enable = true;
            users.users.root.password = "root";
            users.users.root.openssh.authorizedKeys.keys = [ "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIGLJN8Kz3Cn4mMQCPar9j99s5rD7JAP2kUWVleiv2LF8" ];
          })
        ];
      };
    };
  };
}
