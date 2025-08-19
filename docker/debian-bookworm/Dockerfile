# HARDN-XDR Docker Image for Debian Bookworm
# This Dockerfile creates a containerized version of HARDN-XDR
FROM debian:bookworm-slim

LABEL maintainer="HARDN-XDR Project"
LABEL description="HARDN-XDR security hardening tool on Debian Bookworm"
LABEL version="1.0"

ENV DEBIAN_FRONTEND=noninteractive
ENV LANG=C.UTF-8
ENV HARDN_XDR_HOME=/opt/hardn-xdr


RUN apt-get update && apt-get install -y \
    bash \
    curl \
    wget \
    ca-certificates \
    gnupg \
    lsb-release \
    sudo \
    procps \
    net-tools \
    && rm -rf /var/lib/apt/lists/* \
    && apt-get clean


RUN groupadd -r hardn && \
    useradd -r -g hardn -m -s /bin/bash hardn && \
    echo 'hardn ALL=(ALL) NOPASSWD:ALL' >> /etc/sudoers


WORKDIR ${HARDN_XDR_HOME}

COPY hardn-xdr ${HARDN_XDR_HOME}/hardn-xdr
COPY hardn_audit.sh ${HARDN_XDR_HOME}/hardn_audit.sh
COPY smoke_test.sh ${HARDN_XDR_HOME}/smoke_test.sh
COPY src/ ${HARDN_XDR_HOME}/src/
COPY man/ ${HARDN_XDR_HOME}/man/
COPY docs/ ${HARDN_XDR_HOME}/docs/

COPY docker/debian-bookworm/entrypoint.sh /usr/local/bin/entrypoint.sh

RUN chmod +x ${HARDN_XDR_HOME}/hardn-xdr && \
    chmod +x ${HARDN_XDR_HOME}/hardn_audit.sh && \
    chmod +x ${HARDN_XDR_HOME}/smoke_test.sh && \
    chmod +x /usr/local/bin/entrypoint.sh

# Create symbolic link to make hardn-xdr available system-wide
RUN ln -s ${HARDN_XDR_HOME}/hardn-xdr /usr/local/bin/hardn-xdr

RUN chown -R hardn:hardn ${HARDN_XDR_HOME}

USER hardn

WORKDIR /home/hardn

HEALTHCHECK --interval=30s --timeout=10s --start-period=5s --retries=3 \
    CMD ${HARDN_XDR_HOME}/smoke_test.sh || exit 1

ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]

CMD ["/bin/bash"]
