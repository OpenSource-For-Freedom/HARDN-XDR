#!/bin/bash



stig_disable_ctrl_alt_del() {
    systemctl mask ctrl-alt-del.target
    systemctl daemon-reexec
}

main(){

stig_disable_ctrl_alt_del

}