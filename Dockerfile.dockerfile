# ========== Dockerfile ==========
FROM ubuntu:24.10

LABEL maintainer="kubernetes-update-container"

# 1. Non-interactive APT и часовой пояс
ENV DEBIAN_FRONTEND=noninteractive
ENV TZ=UTC

# 2. Preseed tzdata, обновление и установка утилит
RUN echo "tzdata tzdata/Areas select Etc" | debconf-set-selections \
 && echo "tzdata tzdata/Zones/Etc select UTC" | debconf-set-selections \
 \
 && apt-get update \
 #&& apt-get upgrade -y \
 \
 && apt-get install -y --no-install-recommends \
      curl \
      ca-certificates \
      tzdata \
      unzip \
      lsb-release \
      jq \
      etcd-client \
 \
 && apt-get clean \
 && rm -rf /var/lib/apt/lists/*
