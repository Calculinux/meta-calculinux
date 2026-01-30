#!/bin/bash
# USB Gadget Serial Console Manager
# Enables or disables serial-getty@ttyGS0 based on /etc/default/usb-gadget-network

set -e

# Load configuration
if [ -f /etc/default/usb-gadget-network ]; then
    . /etc/default/usb-gadget-network
fi

# Default to enabled if not set
ENABLE_SERIAL_CONSOLE=${ENABLE_SERIAL_CONSOLE:-0}

case "$1" in
    start)
        if [ "${ENABLE_SERIAL_CONSOLE}" = "1" ]; then
            echo "Enabling USB serial console on ttyGS0..."
            systemctl enable serial-getty@ttyGS0.service 2>/dev/null || true
            # Start it if the device exists
            if [ -e /dev/ttyGS0 ]; then
                systemctl start serial-getty@ttyGS0.service 2>/dev/null || true
            fi
        else
            echo "Disabling USB serial console on ttyGS0..."
            systemctl stop serial-getty@ttyGS0.service 2>/dev/null || true
            systemctl disable serial-getty@ttyGS0.service 2>/dev/null || true
        fi
        ;;
    stop)
        systemctl stop serial-getty@ttyGS0.service 2>/dev/null || true
        ;;
    *)
        echo "Usage: $0 {start|stop}"
        exit 1
        ;;
esac

exit 0
