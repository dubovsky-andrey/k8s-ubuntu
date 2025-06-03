FROM ubuntu:25.04

LABEL org.opencontainers.image.authors="k8s-ubuntu"

ENV DEBIAN_FRONTEND=noninteractive \
    TZ=UTC \
    PATH="/opt/venv/bin:$PATH"

SHELL ["/bin/bash", "-o", "pipefail", "-c"]

RUN ln -fs /usr/share/zoneinfo/$TZ /etc/localtime \
 && echo "tzdata tzdata/Areas select Etc" | debconf-set-selections \
 && echo "tzdata tzdata/Zones/Etc select UTC" | debconf-set-selections \
 && apt-get update \
 && apt-get install -y --no-install-recommends tzdata \
 && dpkg-reconfigure -f noninteractive tzdata \
 && rm -rf /var/lib/apt/lists/*

RUN apt-get update \
 && apt-get install -y --no-install-recommends \
      python3 python3-pip python3-venv python3-full \
 && python3 -m venv /opt/venv \
 && /opt/venv/bin/pip install --no-cache-dir regex emoji \
 && rm -rf /var/lib/apt/lists/*

RUN pip install --no-cache-dir regex emoji

RUN apt-get update \
 && apt-get install -y --no-install-recommends \
      curl \
      ca-certificates \
      unzip \
      lsb-release \
      jq \
      etcd-client \
      iputils-ping \
      ansible \
 && rm -rf /var/lib/apt/lists/*


# RUN useradd -m -s /bin/bash appuser
# USER appuser

CMD ["/bin/bash"]
