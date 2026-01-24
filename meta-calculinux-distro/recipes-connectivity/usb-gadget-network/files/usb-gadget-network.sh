#!/bin/bash
# USB Gadget Network Configuration Script
# Configures USB gadget using ConfigFS for RNDIS and CDC-Ether networking

set -e

# Optional runtime configuration
if [ -f /etc/default/usb-gadget-network ]; then
    . /etc/default/usb-gadget-network
fi

GADGET_DIR="/sys/kernel/config/usb_gadget"
GADGET_NAME="g1"
GADGET_PATH="${GADGET_DIR}/${GADGET_NAME}"

# Optional ADB FunctionFS support (drives custom adbd outside Android)
ENABLE_ADB=${ENABLE_ADB:-1}
ADB_FUNCTION_NAME=${ADB_FUNCTION_NAME:-ffs.adb}
ADB_MOUNTPOINT=${ADB_MOUNTPOINT:-/dev/ffs/adb}
ADB_CONFIGS=${ADB_CONFIGS:-"c.1 c.2"}

# USB IDs
ID_VENDOR="0x1d6b"  # Linux Foundation
ID_PRODUCT="0x0104" # Multifunction Composite Gadget
SERIAL_NUMBER="calculinux001"

# Device description
MANUFACTURER="Calculinux"
PRODUCT="PicoCalc USB Network"

# Network configuration
HOST_MAC="48:6f:73:74:50:43"  # HostPC
DEVICE_MAC="44:65:76:69:63:65"  # Device

# Function to clean up existing gadget
cleanup_gadget() {
    if [ -d "${GADGET_PATH}" ]; then
        echo "Cleaning up existing gadget configuration..."
        
        # Remove symbolic links to configurations
        for conf in ${GADGET_PATH}/configs/*/; do
            if [ -d "$conf" ]; then
                for func in ${conf}*.*; do
                    if [ -L "$func" ]; then
                        rm "$func"
                    fi
                done
            fi
        done
        
        # Remove configurations
        for conf in ${GADGET_PATH}/configs/*/; do
            if [ -d "$conf" ]; then
                rmdir "$conf"
            fi
        done

        # Unmount FunctionFS if mounted
        if mountpoint -q "${ADB_MOUNTPOINT}"; then
            umount "${ADB_MOUNTPOINT}" || true
        fi

        # Remove functions
        for func in ${GADGET_PATH}/functions/*/; do
            if [ -d "$func" ]; then
                rmdir "$func"
            fi
        done
        
        # Remove strings
        for strings in ${GADGET_PATH}/strings/*/; do
            if [ -d "$strings" ]; then
                rmdir "$strings"
            fi
        done
        
        # Remove configs strings
        for strings in ${GADGET_PATH}/configs/*/strings/*/; do
            if [ -d "$strings" ]; then
                rmdir "$strings"
            fi
        done
        
        # Disable gadget
        echo "" > ${GADGET_PATH}/UDC || true
        
        # Remove gadget
        rmdir ${GADGET_PATH}
    fi
}

# Function to setup gadget
setup_gadget() {
    echo "Setting up USB gadget network..."
    
    # Create gadget
    mkdir -p ${GADGET_PATH}
    cd ${GADGET_PATH}
    
    # Set USB IDs
    echo ${ID_VENDOR} > idVendor
    echo ${ID_PRODUCT} > idProduct
    echo 0x0200 > bcdUSB  # USB 2.0
    echo 0x0100 > bcdDevice  # Device version
    
    # Set device class
    echo 0xEF > bDeviceClass
    echo 0x02 > bDeviceSubClass
    echo 0x01 > bDeviceProtocol
    
    # Create English strings
    mkdir -p strings/0x409
    echo ${SERIAL_NUMBER} > strings/0x409/serialnumber
    echo ${MANUFACTURER} > strings/0x409/manufacturer
    echo ${PRODUCT} > strings/0x409/product
    
    # Create RNDIS function
    mkdir -p functions/rndis.usb0
    echo ${HOST_MAC} > functions/rndis.usb0/host_addr
    echo ${DEVICE_MAC} > functions/rndis.usb0/dev_addr
    
    # RNDIS needs OS descriptors for Windows compatibility
    echo 1 > os_desc/use
    echo 0xcd > os_desc/b_vendor_code
    echo MSFT100 > os_desc/qw_sign
    
    # Create ECM/CDC-Ether function (for Linux/macOS)
    mkdir -p functions/ecm.usb0
    echo ${HOST_MAC} > functions/ecm.usb0/host_addr
    echo ${DEVICE_MAC} > functions/ecm.usb0/dev_addr
    
    # Create configuration for RNDIS (Windows)
    mkdir -p configs/c.1
    echo 250 > configs/c.1/MaxPower
    mkdir -p configs/c.1/strings/0x409
    echo "RNDIS" > configs/c.1/strings/0x409/configuration
    
    # Create configuration for ECM (Linux/macOS)
    mkdir -p configs/c.2
    echo 250 > configs/c.2/MaxPower
    mkdir -p configs/c.2/strings/0x409
    echo "CDC-Ether/ECM" > configs/c.2/strings/0x409/configuration
    
    # Optional: Create ADB FunctionFS function (added to all configs)
    if [ "${ENABLE_ADB}" = "1" ]; then
        mkdir -p "functions/${ADB_FUNCTION_NAME}"
        mkdir -p "${ADB_MOUNTPOINT}"
        if ! mountpoint -q "${ADB_MOUNTPOINT}"; then
            mount -t functionfs adb "${ADB_MOUNTPOINT}"
        fi
        for cfg in ${ADB_CONFIGS}; do
            mkdir -p "configs/${cfg}"
            ln -sf "../../functions/${ADB_FUNCTION_NAME}" "configs/${cfg}/${ADB_FUNCTION_NAME}"
        done
    fi

    # Link functions to configurations
    ln -s functions/rndis.usb0 configs/c.1/
    ln -s functions/ecm.usb0 configs/c.2/
    
    # Link OS descriptors
    ln -s configs/c.1 os_desc/
    
    # Find and enable UDC
    UDC_DEVICE=$(ls /sys/class/udc | head -n1)
    if [ -z "${UDC_DEVICE}" ]; then
        echo "Error: No UDC device found"
        exit 1
    fi
    
    echo "Enabling UDC: ${UDC_DEVICE}"
    echo ${UDC_DEVICE} > UDC
    
    echo "USB gadget network configured successfully"
}

# Main execution
case "$1" in
    start)
        # Load required kernel modules
        modprobe libcomposite || true
        modprobe usb_f_rndis || true
        modprobe usb_f_ecm || true
        modprobe usb_f_fs || true
        modprobe dwc2 || true
        
        # Wait for configfs to be mounted
        if [ ! -d "${GADGET_DIR}" ]; then
            echo "ConfigFS not mounted at ${GADGET_DIR}"
            exit 1
        fi
        
        cleanup_gadget
        setup_gadget
        
        # Wait for interface to appear
        sleep 2
        
        # Configure network interface
        if ip link show usb0 > /dev/null 2>&1; then
            ip addr add 192.168.7.2/24 dev usb0
            ip link set usb0 up
            echo "USB network interface usb0 configured with IP 192.168.7.2"
        else
            echo "Warning: usb0 interface not found"
        fi
        ;;
    stop)
        # Bring down interface
        if ip link show usb0 > /dev/null 2>&1; then
            ip link set usb0 down
        fi
        
        cleanup_gadget
        
        # Unload modules
        rmmod usb_f_ecm || true
        rmmod usb_f_rndis || true
        rmmod libcomposite || true
        ;;
    restart)
        $0 stop
        sleep 1
        $0 start
        ;;
    *)
        echo "Usage: $0 {start|stop|restart}"
        exit 1
        ;;
esac

exit 0
