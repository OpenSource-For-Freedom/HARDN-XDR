# HARDN-XDR (STIG + FIPS) on Red Hat UBI 9 minimal

# FROM registry.access.redhat.com/ubi9/ubi-minimal@sha256:<digest>
FROM registry.access.redhat.com/ubi9/ubi-minimal:9.5

LABEL org.opencontainers.image.title="HARDN-XDR (UBI9, FIPS/STIG)"
LABEL org.opencontainers.image.description="HARDN-XDR with FIPS crypto policy and OpenSCAP STIG content"
LABEL org.opencontainers.image.vendor="HARDN-XDR Project"
LABEL org.opencontainers.image.licenses="Apache-2.0"
LABEL org.opencontainers.image.version="1.0"

SHELL ["/bin/bash","-Eeuo","pipefail","-c"]

ENV LANG=C.UTF-8 \
    HARDN_XDR_HOME=/opt/hardn-xdr \
    PATH="/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin"

ARG HARDN_UID=10001
ARG HARDN_GID=10001

# Install runtime deps + FIPS/crypto policy tools + OpenSCAP + STIG content
### minimal 
RUN microdnf -y update && \
    microdnf -y install \
      bash coreutils findutils grep shadow-utils \
      ca-certificates curl wget \
      openssl crypto-policies \
      openscap-scanner scap-security-guide \
    && microdnf -y clean all

# Enforce FIPS crypto policy inside the container user space.

RUN update-crypto-policies --set FIPS || { echo "WARN: Could not set FIPS policy"; exit 1; }


RUN groupadd -g "${HARDN_GID}" -r hardn && \
    useradd  -u "${HARDN_UID}" -r -g hardn -d /home/hardn -m -s /usr/sbin/nologin hardn


WORKDIR ${HARDN_XDR_HOME}



COPY --chown=hardn:hardn --chmod=0755 hardn-xdr ${HARDN_XDR_HOME}/hardn-xdr
COPY --chown=hardn:hardn --chmod=0755 hardn_audit.sh ${HARDN_XDR_HOME}/hardn_audit.sh
COPY --chown=hardn:hardn --chmod=0755 smoke_test.sh ${HARDN_XDR_HOME}/smoke_test.sh
COPY --chown=hardn:hardn --chmod=0755 src/ ${HARDN_XDR_HOME}/src/
COPY --chown=hardn:hardn --chmod=0755 man/ ${HARDN_XDR_HOME}/man/
COPY --chown=hardn:hardn --chmod=0755 docs/ ${HARDN_XDR_HOME}/docs/
COPY --chown=root:root  --chmod=0755 docker/debian-bookworm/entrypoint.sh /usr/local/bin/entrypoint.sh

# fallback 
# RUN chown -R hardn:hardn ${HARDN_XDR_HOME} && \
#     chmod 0755 ${HARDN_XDR_HOME}/hardn-xdr ${HARDN_XDR_HOME}/hardn_audit.sh ${HARDN_XDR_HOME}/smoke_test.sh && \
#     chmod -R a+rx ${HARDN_XDR_HOME}/src ${HARDN_XDR_HOME}/man ${HARDN_XDR_HOME}/docs && \
#     chmod 0755 /usr/local/bin/entrypoint.sh

# Symlink to make hardn-xdr available but all --r, only root --w-x
RUN ln -s ${HARDN_XDR_HOME}/hardn-xdr /usr/local/bin/hardn-xdr && \
    chmod 0755 /usr/local/bin /usr/local/bin/hardn-xdr

# helper to run a RHEL9 STIG scan to OpenSCAP.
# Run it as root (start container with --user 0) for best coverage.
RUN cat > /usr/local/bin/stig-scan.sh <<'EOF'
#!/bin/bash
set -Eeuo pipefail
DS="/usr/share/xml/scap/ssg/content/ssg-rhel9-ds.xml"
PROFILE="xccdf_org.ssgproject.content_profile_stig"
OUT_DIR="/tmp/openscap"
mkdir -p "$OUT_DIR"
echo "[+] Running OpenSCAP STIG profile for RHEL 9..."
oscap xccdf eval \
  --profile "$PROFILE" \
  --report "$OUT_DIR/$(date +%Y%m%dT%H%M%S)_stig_report.html" \
  --results "$OUT_DIR/$(date +%Y%m%dT%H%M%S)_stig_results.xml" \
  "$DS"
RC=$?
echo "[*] Results in: $OUT_DIR"
exit $RC
EOF
RUN chmod 0755 /usr/local/bin/stig-scan.sh

USER hardn
WORKDIR /home/hardn

# Healthcheck (smoke_test.sh)
HEALTHCHECK --interval=30s --timeout=10s --start-period=5s --retries=3 \
  CMD "${HARDN_XDR_HOME}/smoke_test.sh" || exit 1

ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]
CMD ["/bin/bash","-lc","exec bash"]