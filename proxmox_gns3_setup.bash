#!/bin/bash
# CONFIGURATION
VMNAME="GNS3-V3-VM"
VMID=9000
MEMORY=4096
CORES=4
BRIDGE="vmbr0"
STORAGE="newdrive"
# URL zur ZIP-Datei der GNS3 VM:
ZIP_URL="https://github.com/GNS3/gns3-gui/releases/download/v3.0.4/GNS3.VM.KVM.3.0.4.zip"
# Lokaler Dateiname
ZIP_FILE="GNS3_VM.zip"

#
echo "GNS3 VM ZIP-Installation auf ProxmoxVE 8.x"

# damit download nach reboot gelöscht wird, in /tmp
cd /tmp

echo ">> Lade ZIP-Datei runter..."
wget -c "$ZIP_URL" -O "$ZIP_FILE"

echo ">> Entpacke ZIP..."
# evlt noch unzip installieren
unzip -o "$ZIP_FILE"

# Suche QCOW2-Dateien (egal wie sie exakt heißen)
DISK1_FILE=$(ls *.qcow2 | sed -n '1p')
DISK2_FILE=$(ls *.qcow2 | sed -n '2p')

if [[ -z "$DISK1_FILE" || -z "$DISK2_FILE" ]]; then
    echo "Fehler: Konnte nicht zwei QCOW2-Dateien im ZIP finden."
    exit 1
fi

echo ">> Gefundene QCOW2-Dateien:"
echo "   Disk1: $DISK1_FILE"
echo "   Disk2: $DISK2_FILE"

echo ">> Erstelle Proxmox VM $VMID ($VMNAME)..."
qm create $VMID \
    --name "$VMNAME" \
    --memory $MEMORY \
    --cores $CORES \
    --net0 virtio,bridge=$BRIDGE \
    --cpu host \
	--bios seabios \
	--kvm 1 \
	--ostype l26 \
	--machine q35 \
	--scsihw virtio-scsi-pci

echo ">> Importiere Disk 1..."
qm disk import $VMID "$DISK1_FILE" $STORAGE

echo ">> Importiere Disk 2..."
qm disk import $VMID "$DISK2_FILE" $STORAGE

# Disk IDs herausfinden (Reihenfolge egal)
DISKS=($(ls /dev/${STORAGE} | grep "vm-${VMID}-disk"))

DISK1_ID=${DISKS[0]}
DISK2_ID=${DISKS[1]}

echo ">> Binde Disks ein..."
qm set $VMID --scsi0 $STORAGE:${DISK1_ID}
qm set $VMID --scsi1 $STORAGE:${DISK2_ID}
# als boot drive festlegen
echo ">> Disk 0 als Bootdrive festlegen"
qm set $VMID --boot order=scsi0

echo ">> Starte VM..."
qm start $VMID

echo "GNS3 VM ist jetzt als VM $VMID aktiv"
