#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <time.h>
#include <unistd.h>
#include <sys/types.h>
#include <sys/stat.h>
#include <sys/wait.h>

// Structure to represent kernel configuration
typedef struct {
    char parameter[256];
    char value[256];
} KernelConfig;

// Function to log actions to a file
void log_action(const char *action) {
    FILE *file = fopen("/var/log/hardn.log", "a");
    if (file == NULL) {
        perror("Failed to open log file");
        return;
    }

    time_t now = time(NULL);
    fprintf(file, "[%ld] %s\n", now, action);
    fclose(file);
}

// Function to apply a kernel configuration
int apply_kernel_config(const KernelConfig *config) {
    char command[512];
    snprintf(command, sizeof(command), "sysctl -w %s=%s", config->parameter, config->value);

    int ret = system(command);
    if (ret == 0) {
        char log_msg[512];
        snprintf(log_msg, sizeof(log_msg), "Applied: %s=%s", config->parameter, config->value);
        log_action(log_msg);
    } else {
        char log_msg[512];
        snprintf(log_msg, sizeof(log_msg), "Failed to apply: %s=%s", config->parameter, config->value);
        log_action(log_msg);
    }

    return ret;
}

// Function to persist kernel configurations to a file
void persist_sysctl_config(const KernelConfig *configs, size_t count) {
    FILE *file = fopen("/etc/sysctl.d/hardn.conf", "w");
    if (file == NULL) {
        perror("Failed to open sysctl config file");
        return;
    }

    for (size_t i = 0; i < count; i++) {
        fprintf(file, "%s = %s\n", configs[i].parameter, configs[i].value);
    }

    fclose(file);

    // Secure file permissions
    chmod("/etc/sysctl.d/hardn.conf", S_IRUSR | S_IWUSR);

    system("sysctl --system");
    log_action("Persisted kernel hardening to /etc/sysctl.d/hardn.conf");
}

// Function to blacklist kernel modules
void blacklist_kernel_modules() {
    const char *blacklist[] = {
        "cramfs", "freevxfs", "jffs2", "hfs", "hfsplus", "squashfs", "udf", "usb-storage",
        "dccp", "sctp", "rds", "tipc"
    };
    size_t count = sizeof(blacklist) / sizeof(blacklist[0]);

    FILE *file = fopen("/etc/modprobe.d/hardn-blacklist.conf", "w");
    if (file == NULL) {
        perror("Failed to open blacklist file");
        return;
    }

    for (size_t i = 0; i < count; i++) {
        fprintf(file, "install %s /bin/false\n", blacklist[i]);
    }

    fclose(file);

    // Secure file permissions
    chmod("/etc/modprobe.d/hardn-blacklist.conf", S_IRUSR | S_IWUSR);

    log_action("Blacklisted unnecessary and known bad kernel modules in hardn-blacklist.conf");
}

// Function to get the kernel version
void get_kernel_version() {
    FILE *fp = popen("uname -r", "r");
    if (fp == NULL) {
        perror("Failed to get kernel version");
        return;
    }

    char version[256];
    if (fgets(version, sizeof(version), fp) != NULL) {
        printf("Current kernel version: %s", version);
        char log_msg[512];
        snprintf(log_msg, sizeof(log_msg), "Kernel version: %s", version);
        log_action(log_msg);
    }

    pclose(fp);
}

// Function to update the system and kernel
void update_system() {
    log_action("Updating system and kernel...");
    int ret = system("apt update && apt upgrade -y && apt dist-upgrade -y && apt autoremove -y");
    if (ret == 0) {
        log_action("System and kernel updated successfully.");
    } else {
        log_action("Failed to update system and kernel.");
    }
}

// Function to backup existing configurations
void backup_existing_configs() {
    log_action("Backing up existing configurations...");
    system("cp /etc/sysctl.conf /etc/sysctl.conf.bak 2>/dev/null");
    system("cp /etc/modprobe.d/* /etc/modprobe.d/backup/ 2>/dev/null");
    log_action("Backup completed.");
}

void enforce_module_signatures() {
    FILE *file = fopen("/etc/sysctl.d/hardn.conf", "a");
    if (file == NULL) {
        perror("Failed to open sysctl config file");
        return;
    }

    fprintf(file, "kernel.modules_disabled = 1\n");
    fclose(file);

    system("sysctl --system");
    log_action("Enforced kernel module signature verification.");
}

void disable_legacy_kexec() {
    FILE *file = fopen("/etc/sysctl.d/hardn.conf", "a");
    if (file == NULL) {
        perror("Failed to open sysctl config file");
        return;
    }

    fprintf(file, "kernel.kexec_load_disabled = 1\n");
    fclose(file);

    system("sysctl --system");
    log_action("Disabled legacy kexec_load system call.");
}

void enable_kernel_lockdown() {
    FILE *file = fopen("/sys/kernel/security/lockdown", "w");
    if (file == NULL) {
        perror("Failed to enable kernel lockdown");
        return;
    }

    fprintf(file, "integrity");
    fclose(file);

    log_action("Enabled kernel lockdown in integrity mode.");
}

void restrict_kernel_pointers() {
    FILE *file = fopen("/etc/sysctl.d/hardn.conf", "a");
    if (file == NULL) {
        perror("Failed to open sysctl config file");
        return;
    }

    fprintf(file, "kernel.kptr_restrict = 1\n");
    fprintf(file, "kernel.dmesg_restrict = 1\n");
    fclose(file);

    system("sysctl --system");
    log_action("Restricted kernel pointer leaks and dmesg access.");
}

int main() {
    KernelConfig configs[] = {
        {"kernel.randomize_va_space", "2"},
        {"net.ipv4.ip_forward", "0"},
        {"net.ipv4.conf.all.rp_filter", "1"},
        {"net.ipv4.conf.default.rp_filter", "1"},
        {"net.ipv4.conf.all.accept_source_route", "0"},
        {"net.ipv4.conf.default.accept_source_route", "0"},
        {"net.ipv4.conf.all.accept_redirects", "0"},
        {"net.ipv4.conf.default.accept_redirects", "0"},
        {"net.ipv4.conf.all.send_redirects", "0"},
        {"net.ipv4.conf.default.send_redirects", "0"},
        {"net.ipv4.tcp_syncookies", "1"},
        {"kernel.sysrq", "0"},
        {"fs.suid_dumpable", "0"},
        {"net.ipv4.icmp_echo_ignore_broadcasts", "1"},
        {"net.ipv4.icmp_ignore_bogus_error_responses", "1"},
        {"net.ipv4.conf.all.log_martians", "1"},
        {"net.ipv4.conf.default.log_martians", "1"}
    };

    size_t config_count = sizeof(configs) / sizeof(configs[0]);

    printf("Applying STIG kernel parameters...\n");
    backup_existing_configs();
    for (size_t i = 0; i < config_count; i++) {
        apply_kernel_config(&configs[i]);
    }

    persist_sysctl_config(configs, config_count);
    blacklist_kernel_modules();
    enforce_module_signatures();
    disable_legacy_kexec();
    enable_kernel_lockdown();
    restrict_kernel_pointers();
    update_system();
    get_kernel_version();

    return 0;
}
