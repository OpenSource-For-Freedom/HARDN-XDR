#!/bin/bash

detect_os() {
    if [ -f /etc/os-release ] && [ -r /etc/os-release ]; then
        . /etc/os-release
        export OS_NAME="$NAME"
        export OS_VERSION="$VERSION_ID"

        case "$OS_NAME" in
            "Debian GNU/Linux")
                if [[ "$OS_VERSION" == "11" || "$OS_VERSION" == "12" ]]; then
                    echo "Detected supported OS: $OS_NAME $OS_VERSION"
                else
                    echo "Unsupported Debian version: $OS_VERSION. Exiting."
                    exit 1
                fi
                ;;
            "Ubuntu")
                if [[ "$OS_VERSION" == "22.04" || "$OS_VERSION" == "24.04" ]]; then
                    echo "Detected supported OS: $OS_NAME $OS_VERSION"
                else
                    echo "Unsupported Ubuntu version: $OS_VERSION. Exiting."
                    exit 1
                fi
                ;;
            *)
                echo "Unsupported OS: $OS_NAME. Exiting."
                exit 1
                ;;
        esac
    else
        echo "Unable to read /etc/os-release. Exiting."
        exit 1
    fi
}

main() { 

    detect_os
}

main