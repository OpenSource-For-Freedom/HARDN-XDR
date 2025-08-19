# Docker 

## Quick Start

- Download HARDN-XDR by source. 
```
cd hardn-xdr
```

#### Build
```
docker build -f docker/debian-bookworm/Dockerfile -t hardn-xdr:debian-bookworm .
```
### Run 
```
docker run -it --rm --user root hardn-xdr:debian-bookworm bash
```
### Start

- To test the short version for compatability
```
cd /opt/hardn-xdr
./smoke_test.sh

```

### Menu
```
bash /opt/hardn-xdr/src/setup/hardn-main.sh --help
```
- to deploy the recommended modules

### Full Version
```
/opt/hardn-xdr/src/setup/hardn-main.sh
```

# 1. Start with critical network and SSH hardening
```
sudo hardn-xdr --docker --module sshd
sudo hardn-xdr --docker --module network_protocols
```
# 2. Apply kernel-level security
```
sudo hardn-xdr --docker --module kernel_sec
sudo hardn-xdr --docker --module coredumps
```
# 3. Enable automatic updates for CVE patches
```
sudo hardn-xdr --docker --module auto_updates
```
# 4. Clean up vulnerable packages
```
sudo hardn-xdr --docker --module purge_old_pkgs
```
# 5. Validate system integrity
```
sudo hardn-xdr --docker --module debsums
```
# Run the most important CVE mitigation modules
```
sudo hardn-xdr --docker \
--module sshd \
--module network_protocols \
--module kernel_sec \
--module auto_updates \
--module purge_old_pkgs \
--module debsums \
--module file_perms \
--module credential_protection
```
