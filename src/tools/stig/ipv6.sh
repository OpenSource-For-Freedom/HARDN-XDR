#!/bin/bash



stig_disable_ipv6() {
    echo "net.ipv6.conf.all.disable_ipv6 = 1" >> /etc/sysctl.d/99-sysctl.conf
    echo "net.ipv6.conf.default.disable_ipv6 = 1" >> /etc/sysctl.d/99-sysctl.conf
    sysctl -p
}


main(){

stig_disable_ipv6

}