FROM ubuntu:22.04

LABEL org.opencontainers.image.authors="kubernetes-update-container"

ENV DEBIAN_FRONTEND=noninteractive
ENV TZ=UTC

SHELL ["/bin/bash", "-o", "pipefail", "-c"]

RUN ln -fs /usr/share/zoneinfo/$TZ /etc/localtime \
 && echo "tzdata tzdata/Areas select Etc" | debconf-set-selections \
 && echo "tzdata tzdata/Zones/Etc select UTC" | debconf-set-selections \
 && apt-get update \
 && apt-get install -y --no-install-recommends \
      curl \
      ca-certificates \
      tzdata \
      unzip \
      lsb-release \
      jq \
      etcd-client \
 && dpkg-reconfigure -f noninteractive tzdata \
 && rm -rf /var/lib/apt/lists/*

RUN useradd -m -s /bin/bash appuser
USER appuser

# Default command
CMD ["/bin/bash"]
