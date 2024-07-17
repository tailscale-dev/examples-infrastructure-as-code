terraform {
    required_providers {
        proxmox = {
            source = "telmate/proxmox"
            version = "3.0.1-rc3"
        }
    }
}

provider "proxmox" {
    pm_api_url = var.proxmox_api_url
    pm_api_token_id = var.proxmox_api_token_id
    pm_api_token_secret = var.proxmox_api_token_secret

    pm_tls_insecure = true
    pm_parallel = 10
}

# locals {
#     vm_name = "cloudinit-test-vm"
#     pve_node = "deepthought"
#     pve_storage = "local"
# }

# resource "proxmox_cloud_init_disk" "ci" {
#     name = local.vm_name
#     pve_node = local.pve_node
#     storage = local.pve_storage

#     user_data = <<EOT
#     users:
#         - zaphod
#     ssh_authorized_keys:
#         - ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIPA5Cpi+h5gyLs8JmKwTmSIytcyhRf/eusiabgj3tsH2
#     EOT
# }



# resource "proxmox_vm_qemu" "vm" {
#     name = local.vm_name
#     target_node = local.pve_node
#     clone = "ubuntu-cloud2404"
#     storage = local.pve_storage

#     agent    = 1
#     cores    = 4
#     sockets  = 1
#     cpu      = "host"
#     memory   = 2048
#     scsihw   = "virtio-scsi-pci"
#     bootdisk = "scsi0"

#     #os_type  = "cloud-init"

#     #ciuser = "root"

#     disks {
#         scsi {
#             scsi0 {
#                 cdrom {
#                 iso = "${proxmox_cloud_init_disk.ci.id}"
#                 }
#             }
#         }
#         virtio {
#             virtio0 {
#                 disk {
#                 size            = 20
#                 cache           = "writeback"
#                 storage         = "local"
#                 }
#             }
#         }
#     }
#   network {
#     model  = "virtio"
#     bridge = "vmbr0"
#   }

#   lifecycle {
#     ignore_changes = [
#       network,
#     ]
#   }

resource "proxmox_vm_qemu" "cloudinit-test" {
    name = "terraform-test-vm"
    desc = "A test for using terraform and cloudinit"

    # Node name has to be the same name as within the cluster
    # this might not include the FQDN
    target_node = "deepthought"

    # The destination resource pool for the new VM
    #pool = "pool0"

    # The template name to clone this vm from
    clone = "ubuntu-cloud2404"

    # Activate QEMU agent for this VM
    agent = 1

    os_type = "cloud-init"
    cores = 2
    sockets = 1
    vcpus = 0
    cpu = "host"
    memory = 2048
    #scsihw = "lsi"

    # Setup the disk
    disks {
        ide {
            ide3 {
                cloudinit {
                    storage = "local"
                }
            }
        }
        virtio {
            virtio0 {
                disk {
                    size            = 32
                    cache           = "writeback"
                    storage         = "local"
                    iothread        = true
                    discard         = true
                }
            }
        }
    }

    # Setup the network interface and assign a vlan tag: 256
    network {
        model = "virtio"
        bridge = "vmbr0"
        #tag = 256
    }

    # Setup the ip address using cloud-init.
    boot = "order=virtio0"
    # Keep in mind to use the CIDR notation for the ip.
    #ipconfig0 = "ip=192.168.10.20/24,gw=192.168.10.1"

    sshkeys = <<EOF
    ssh-rsa 9182739187293817293817293871== user@pc
    EOF
}