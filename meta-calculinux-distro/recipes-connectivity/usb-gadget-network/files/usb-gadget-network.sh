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

# USB network protocol selection: "ecm" (Linux/macOS) or "rndis" (Windows)
# ECM is preferred for Linux/macOS, RNDIS for Windows
USB_PROTOCOL=${USB_PROTOCOL:-ecm}

# Optional USB serial console on ttyGS0 (ACM function)
ENABLE_SERIAL_CONSOLE=${ENABLE_SERIAL_CONSOLE:-0}

# Optional ADB FunctionFS support (drives custom adbd outside Android)
ENABLE_ADB=${ENABLE_ADB:-0}
ADB_FUNCTION_NAME=${ADB_FUNCTION_NAME:-ffs.adb}
ADB_MOUNTPOINT=${ADB_MOUNTPOINT:-/dev/ffs/adb}

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
        
        # Step 1: Unbind from UDC first (disable gadget)
        if [ -f "${GADGET_PATH}/UDC" ]; then
            UDC_VAL=$(cat "${GADGET_PATH}/UDC" 2>/dev/null || true)
            if [ -n "$UDC_VAL" ]; then
                echo "" > "${GADGET_PATH}/UDC" 2>/dev/null || true
            fi
        fi
        
        # Step 2: Remove function symlinks from configurations
        find "${GADGET_PATH}/configs" -type l -exec rm {} \; 2>/dev/null || true
        
        # Step 3: Remove strings in configurations
        find "${GADGET_PATH}/configs" -mindepth 3 -maxdepth 3 -type d -exec rmdir {} \; 2>/dev/null || true
        find "${GADGET_PATH}/configs" -mindepth 2 -maxdepth 2 -name "strings" -type d -exec rmdir {} \; 2>/dev/null || true
        
        # Step 4: Remove os_desc symlinks
        find "${GADGET_PATH}/os_desc" -type l -exec rm {} \; 2>/dev/null || true
        
        # Step 5: Remove configurations
        find "${GADGET_PATH}/configs" -mindepth 1 -maxdepth 1 -type d -exec rmdir {} \; 2>/dev/null || true
        
        # Step 6: Unmount FunctionFS if mounted
        if mountpoint -q "${ADB_MOUNTPOINT}" 2>/dev/null; then
            umount "${ADB_MOUNTPOINT}" || true
        fi
        
        # Step 7: Remove functions
        find "${GADGET_PATH}/functions" -mindepth 1 -maxdepth 1 -type d -exec rmdir {} \; 2>/dev/null || true
        
        # Step 8: Remove strings
        find "${GADGET_PATH}/strings" -mindepth 1 -maxdepth 1 -type d -exec rmdir {} \; 2>/dev/null || true
        
        # Step 9: Remove gadget directory
        rmdir "${GADGET_PATH}" 2>/dev/null || {
            echo "Warning: Could not remove gadget directory, listing contents:"
            find "${GADGET_PATH}" -type d -o -type l 2>/dev/null
            return 1
        }
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
    
    # Create ACM serial function (for console access) if enabled
    if [ "${ENABLE_SERIAL_CONSOLE}" = "1" ]; then
        mkdir -p functions/acm.usb0
    fi
    
    # Create network function based on protocol selection
    if [ "${USB_PROTOCOL}" = "rndis" ]; then
        # RNDIS function for Windows
        mkdir -p functions/rndis.usb0
        echo ${HOST_MAC} > functions/rndis.usb0/host_addr
        echo ${DEVICE_MAC} > functions/rndis.usb0/dev_addr
        
        # RNDIS needs OS descriptors for Windows compatibility
        echo 1 > os_desc/use
        echo 0xcd > os_desc/b_vendor_code
        echo MSFT100 > os_desc/qw_sign
        
        NETWORK_FUNCTION="rndis.usb0"
        CONFIG_LABEL="RNDIS"
    else
        # ECM/CDC-Ether function for Linux/macOS (default)
        mkdir -p functions/ecm.usb0
        echo ${HOST_MAC} > functions/ecm.usb0/host_addr
        echo ${DEVICE_MAC} > functions/ecm.usb0/dev_addr
        
        NETWORK_FUNCTION="ecm.usb0"
        CONFIG_LABEL="CDC-Ether/ECM"
    fi
    
    # Create single configuration
    mkdir -p configs/c.1
    echo 250 > configs/c.1/MaxPower
    mkdir -p configs/c.1/strings/0x409
    echo "${CONFIG_LABEL}" > configs/c.1/strings/0x409/configuration
    
    # Optional: Create ADB FunctionFS function
    if [ "${ENABLE_ADB}" = "1" ]; then
        mkdir -p "functions/${ADB_FUNCTION_NAME}"
        mkdir -p "${ADB_MOUNTPOINT}"
        if ! mountpoint -q "${ADB_MOUNTPOINT}"; then
            mount -t functionfs adb "${ADB_MOUNTPOINT}"
        fi
        ln -sf "../../functions/${ADB_FUNCTION_NAME}" "configs/c.1/${ADB_FUNCTION_NAME}"
    fi

    # Link functions to configuration
    ln -s functions/${NETWORK_FUNCTION} configs/c.1/
    if [ "${ENABLE_SERIAL_CONSOLE}" = "1" ]; then
        ln -s functions/acm.usb0 configs/c.1/
    fi
    
    # Link OS descriptors (only needed for RNDIS)
    if [ "${USB_PROTOCOL}" = "rndis" ]; then
        ln -s configs/c.1 os_desc/
    fi
    
    # Find and enable UDC (with retry logic)
    # The UDC device can take time to initialize during boot
    MAX_ATTEMPTS=30
    ATTEMPT=0
    RETRY_DELAY=1
    
    while [ $ATTEMPT -lt $MAX_ATTEMPTS ]; do
        UDC_DEVICE=$(ls /sys/class/udc 2>/dev/null | head -n1)
        if [ -n "${UDC_DEVICE}" ]; then
            break
        fi
        ATTEMPT=$((ATTEMPT + 1))
        if [ $ATTEMPT -lt $MAX_ATTEMPTS ]; then
            echo "Waiting for UDC device... (attempt $ATTEMPT/$MAX_ATTEMPTS)"
            sleep $RETRY_DELAY
        fi
    done
    
    if [ -z "${UDC_DEVICE}" ]; then
        echo "Error: No UDC device found after $MAX_ATTEMPTS attempts"
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
        modprobe usb_f_acm || true
        modprobe dwc2 || true
        
        # Wait for configfs to be mounted
        if [ ! -d "${GADGET_DIR}" ]; then
            echo "ConfigFS not mounted at ${GADGET_DIR}"
            exit 1
        fi
        
        cleanup_gadget
        setup_gadget
        
        # Wait for interface to appear and let systemd-networkd configure it
        # The usb0.network file handles both DHCP (for network sharing) and static IP (for manual connection)
        sleep 2
        
        echo "USB gadget configured - network interface usb0 will be managed by systemd-networkd"
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
