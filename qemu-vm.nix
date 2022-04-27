{ config, pkgs, lib, modulesPath, ... }:

with lib;

let
  diskImage = import "${modulesPath}/../lib/make-disk-image.nix" {
    name = "image.qcow2";
    format = "qcow2";
    diskSize = "auto";
    partitionTableType = "efi";
    inherit config lib pkgs;
  };
  runVM = ''
    #! ${pkgs.runtimeShell}
    set -e
    SYSTEM=${config.system.build.toplevel}
    IMAGE=${diskImage}/nixos.qcow2

    ${pkgs.qemu}/bin/qemu-img create -f qcow2 -F qcow2 -b $IMAGE work.qcow2 10G
    ${pkgs.qemu}/bin/qemu-system-x86_64 \
      -smp 4 \
      -m 2048M \
      -kernel $SYSTEM/kernel \
      -enable-kvm \
      -append "$(cat $SYSTEM/kernel-params) init=$SYSTEM/init $KERNEL_CMDLINE" \
      -initrd $SYSTEM/initrd \
      -serial stdio \
      -monitor none \
      -drive file=work.qcow2,if=virtio
  '';

  importVM = ''
    #! ${pkgs.runtimeShell}
    if [ "$#" -ne 1 ]; then
        echo "Usage: ./$0 [vm-id]"
        exit 1
    fi

    set -e
    SYSTEM=${config.system.build.toplevel}
    IMAGE=${diskImage}/nixos.qcow2
    WORK_DISK=work-$1.qcow2
    VM_NAME=k8s-node-$1

    virsh --connect qemu:///system destroy $VM_NAME || true
    virsh --connect qemu:///system undefine $VM_NAME || true
    ${pkgs.qemu}/bin/qemu-img create -f qcow2 -F qcow2 -b $IMAGE $WORK_DISK 10G
    virt-install  \
      --name $VM_NAME \
      --vcpus 2 \
      --connect qemu:///system \
      --os-variant nixos-unstable \
      --network network=default \
      --network network=k8s-intracluster \
      --memory 2048 \
      --boot kernel=$SYSTEM/kernel,initrd=$SYSTEM/initrd,kernel_args="hostname=$VM_NAME init=$SYSTEM/init $(cat $SYSTEM/kernel-params)" \
      --disk $WORK_DISK \
      --import \
      --noautoconsole
  '';

  sshVM = ''
  #! ${pkgs.runtimeShell}
  IP=$(virsh --connect qemu:///system qemu-agent-command k8s-node-$1 '{"execute":"guest-network-get-interfaces"}' | jq -r ".return | .[] | select(.name == \"enp1s0\") | .\"ip-addresses\" | .[] | select(.\"ip-address-type\" == \"ipv4\") | .\"ip-address\"")
  exec ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null root@$IP
  '';

in
{
  imports = [
    "${modulesPath}/profiles/qemu-guest.nix"
  ];
  config = {
    system.build.vm = pkgs.runCommand "kube-vm" { }
      ''
        mkdir -p $out/bin
        ln -s ${config.system.build.toplevel} $out/system
        ln -s ${pkgs.writeScript "run-vm" runVM} $out/bin/run-vm

        ln -s ${pkgs.writeScript "import-vm" importVM} $out/bin/import-vm
        ln -s ${pkgs.writeScript "ssh-vm" sshVM} $out/bin/ssh-vm
      '';

    fileSystems."/" = {
      device = "/dev/disk/by-label/nixos";
      autoResize = true;
      fsType = "ext4";
    };
    services.qemuGuest.enable = true;
    networking.hostName = "";

    systemd.services.hostname-init = {
      script = ''
      HOSTNAME=$(cat /proc/cmdline | tr " " "\\n" | grep hostname | cut -d= -f 2)
      ${pkgs.systemd}/bin/hostnamectl --transient hostname $HOSTNAME
      '';

      wantedBy = [ "basic.target" ];
      after = [ "basic.target" ];

      serviceConfig = {
        Type = "oneshot";
        RemainAfterExit = true;
      };
    };

    boot.loader.grub.enable = false;
    boot.growPartition = true;
  };
}
