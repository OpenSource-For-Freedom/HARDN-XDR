# Proposed CI/CD Enhancement for PakOS Support

## Current Test Matrix
```yaml
strategy:
  matrix:
    arch: [amd64, arm64]
    distro: [debian, ubuntu]
    deployment_type: [container, vm-simulation]
```

## Proposed Enhanced Test Matrix with PakOS
```yaml
strategy:
  matrix:
    arch: [amd64, arm64]
    distro: [debian, ubuntu, pakos]
    deployment_type: [container, vm-simulation]
    exclude:
      # Exclude PakOS testing until official container images are available
      - distro: pakos
        deployment_type: container
```

## Implementation Considerations

### PakOS Container Image Availability
- **Current Status**: PakOS official container images may not be publicly available
- **Workaround**: Test PakOS detection using custom /etc/os-release simulation
- **Future**: Add PakOS testing when official images become available

### Alternative Testing Strategy
1. **Simulate PakOS Environment**: Create test cases that mock PakOS /etc/os-release
2. **Debian Compatibility Testing**: Use Debian/Ubuntu as proxy for PakOS (if Debian-based)
3. **Community Engagement**: Work with PakOS community to obtain test images

### Docker Image Selection for PakOS
```yaml
# When PakOS images become available:
- name: Select base image for PakOS
  run: |
    if [ "${{ matrix.distro }}" = "pakos" ]; then
      BASE_IMAGE="pakos:latest"  # When available
    elif [ "${{ matrix.distro }}" = "ubuntu" ]; then
      BASE_IMAGE="ubuntu:24.04"
    else
      BASE_IMAGE="debian:stable-slim"
    fi
```

### Test Environment Variables for PakOS
```bash
# Additional environment variables for PakOS testing
-e PAKOS_DETECTED=1
-e IS_DEBIAN_DERIVATIVE=1
-e ID=pakos
-e VERSION_CODENAME=stable
-e PRETTY_NAME="PakOS (Pakistan Operating System)"
```

## Implementation Steps

1. **Phase 1: Detection Testing**
   - Test PakOS detection logic with mocked /etc/os-release
   - Validate Debian-derivative compatibility mode

2. **Phase 2: Compatibility Testing**  
   - Test all modules with PakOS environment variables
   - Verify package manager compatibility (apt assumed)

3. **Phase 3: Full Integration**
   - Add PakOS to CI matrix when container images available
   - Implement PakOS-specific test cases

## Mock PakOS Testing Implementation

```yaml
- name: Test PakOS detection with mock environment
  run: |
    # Create mock PakOS environment
    docker run --rm -i --platform linux/${{ matrix.arch }} \
      --privileged \
      -e SKIP_WHIPTAIL=1 \
      -e DEBIAN_FRONTEND=noninteractive \
      -e CI=true \
      -v "$(pwd)/hardn.deb:/tmp/hardn.deb" \
      debian:stable-slim bash -c '
        # Mock PakOS /etc/os-release
        cat > /etc/os-release << EOF
ID=pakos
NAME="PakOS"
VERSION="1.0"
VERSION_ID="1.0"
VERSION_CODENAME="stable"
PRETTY_NAME="PakOS (Pakistan Operating System)"
HOME_URL="https://pakos.pk/"
SUPPORT_URL="https://pakos.pk/support"
BUG_REPORT_URL="https://pakos.pk/bugs"
EOF
        
        # Install and test HARDN-XDR
        apt-get update
        dpkg -i /tmp/hardn.deb || true
        apt-get install -f -y
        
        # Test PakOS detection
        /usr/bin/hardn-xdr --version
        echo "Testing PakOS detection..."
        bash /usr/lib/hardn-xdr/src/setup/modules/pakos_config.sh
      '
```

This approach allows us to test PakOS compatibility even without official PakOS container images.