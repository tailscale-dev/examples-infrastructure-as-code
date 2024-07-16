resource "proxmox_vm_qemu" "pxe-minimal-example" {
    name                      = "pxe-minimal-example"
    agent                     = 0
    boot                      = "order=scsi0;net0"
    pxe                       = true
    target_node               = "gilfoyle"
    network {
        bridge    = "vmbr0"
        firewall  = false
        link_down = false
        model     = "e1000"
    }
}