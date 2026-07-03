# -*- mode: ruby -*-
# vi: set ft=ruby :

# Vagrantfile for AD-HomeLab
# Provides an alternative to the raw Hyper-V provisioning scripts.
# Requires Vagrant with the Hyper-V provider installed.
#
# Usage:
#   vagrant up dc01
#   vagrant up win11-client01
#   vagrant up win11-client02
#
# Note: Vagrant boxes for Windows Server 2022 and Windows 11 are available
# on Vagrant Cloud. You may need to build your own box from the eval ISO
# using Packer if a suitable box is not available.

Vagrant.configure("2") do |config|
  admin_password = ENV["AD_HOMELAB_ADMIN_PASSWORD"]
  if admin_password.nil? || admin_password.empty?
    raise "Set AD_HOMELAB_ADMIN_PASSWORD before running vagrant up. Example: $env:AD_HOMELAB_ADMIN_PASSWORD = 'Use-A-Unique-Lab-Password!'"
  end

  config.vm.communicator = "winrm"
  config.winrm.username = "Administrator"
  config.winrm.password = admin_password

  # ── DC01: Windows Server 2022 Domain Controller ──
  config.vm.define "dc01" do |dc01|
    dc01.vm.box = "gusztavvargadr/windows-server-2022-standard"
    dc01.vm.hostname = "DC01"

    dc01.vm.provider "hyperv" do |h|
      h.memory = 4096
      h.cpus = 2
      h.virtualization_extensions = true
      h.enable_virtualization_extensions = true
      h.differencing_disk = true
      h.vmname = "AD-Lab-DC01"
    end

    dc01.vm.network "private_network",
      type: "static_ip",
      ip: "10.0.0.10",
      netmask: "255.255.255.0",
      gateway: "10.0.0.1"

    dc01.vm.provision "shell", path: "vagrant/bootstrap-dc.ps1",
      args: [admin_password]
  end

  # ── WIN11-CLIENT01 ──
  config.vm.define "win11-client01" do |client01|
    client01.vm.box = "gusztavvargadr/windows-11"
    client01.vm.hostname = "WIN11-CLIENT01"

    client01.vm.provider "hyperv" do |h|
      h.memory = 4096
      h.cpus = 2
      h.virtualization_extensions = true
      h.enable_virtualization_extensions = true
      h.differencing_disk = true
      h.vmname = "AD-Lab-WIN11-CLIENT01"
    end

    client01.vm.network "private_network",
      type: "dhcp"

    client01.vm.provision "shell", path: "vagrant/bootstrap-client.ps1",
      args: ["WIN11-CLIENT01", "10.0.0.10", "homelab.local", admin_password]
  end

  # ── WIN11-CLIENT02 ──
  config.vm.define "win11-client02" do |client02|
    client02.vm.box = "gusztavvargadr/windows-11"
    client02.vm.hostname = "WIN11-CLIENT02"

    client02.vm.provider "hyperv" do |h|
      h.memory = 4096
      h.cpus = 2
      h.virtualization_extensions = true
      h.enable_virtualization_extensions = true
      h.differencing_disk = true
      h.vmname = "AD-Lab-WIN11-CLIENT02"
    end

    client02.vm.network "private_network",
      type: "dhcp"

    client02.vm.provision "shell", path: "vagrant/bootstrap-client.ps1",
      args: ["WIN11-CLIENT02", "10.0.0.10", "homelab.local", admin_password]
  end
end
