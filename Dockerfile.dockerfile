FROM ubuntu:24.04

ARG TARGETARCH

ENV DEBIAN_FRONTEND=noninteractive

RUN apt-get update \
    && apt-get install -y --no-install-recommends \
      bash \
      ca-certificates \
      curl \
      dnsutils \
      git \
      gzip \
      iproute2 \
      iptables \
      jq \
      libcap2-bin \
      less \
      man-db \
      nano \
      netcat-openbsd \
      openssh-server \
      openssl \
      python3 \
      python3-pip \
      tar \
      tcpdump \
      tree \
      vim \
      wget \
    && rm -rf /var/lib/apt/lists/*

RUN useradd -m -s /bin/bash student \
    && mkdir -p /run/sshd /home/student/.ssh /home/student/.kube \
    && chown -R student:student /home/student \
    && chmod 700 /home/student/.ssh

RUN curl -fsSL "https://dl.k8s.io/release/v1.34.0/bin/linux/${TARGETARCH}/kubectl" -o /usr/local/bin/kubectl \
    && chmod +x /usr/local/bin/kubectl

RUN set -eux; \
    case "${TARGETARCH}" in \
      amd64) ARCH="amd64"; KUBE_LINTER_ARCH="" ;; \
      arm64) ARCH="arm64"; KUBE_LINTER_ARCH="_arm64" ;; \
      *) echo "unsupported arch ${TARGETARCH}" >&2; exit 1 ;; \
    esac; \
    install_tar_asset() { \
      repo="$1"; pattern="$2"; binary="$3"; \
      url="$(curl -fsSL "https://api.github.com/repos/${repo}/releases/latest" \
        | jq -r --arg pattern "$pattern" '.assets[] | select(.name | test($pattern)) | .browser_download_url' \
        | head -n 1)"; \
      test -n "$url" || { echo "no release asset matched ${repo}: ${pattern}" >&2; exit 1; }; \
      curl -fsSL "$url" | tar -xz -C /usr/local/bin "$binary"; \
      chmod +x "/usr/local/bin/${binary}"; \
    }; \
    install_tar_asset cilium/cilium-cli "cilium-linux-${ARCH}\\.tar\\.gz$" cilium; \
    install_tar_asset cilium/hubble "hubble-linux-${ARCH}\\.tar\\.gz$" hubble; \
    install_tar_asset zegl/kube-score "kube-score_.*_linux_${ARCH}\\.tar\\.gz$" kube-score; \
    install_tar_asset stackrox/kube-linter "kube-linter-linux${KUBE_LINTER_ARCH}\\.tar\\.gz$" kube-linter; \
    install_tar_asset kubernetes-sigs/cri-tools "crictl-v.*-linux-${ARCH}\\.tar\\.gz$" crictl; \
    install_tar_asset itaysk/kubectl-neat "kubectl-neat_linux_${ARCH}\\.tar\\.gz$" kubectl-neat; \
    install_tar_asset stern/stern "stern_.*_linux_${ARCH}\\.tar\\.gz$" stern; \
    install_tar_asset controlplaneio/kubesec "kubesec_linux_${ARCH}\\.tar\\.gz$" kubesec; \
    install_tar_asset derailed/k9s "k9s_Linux_${ARCH}\\.tar\\.gz$" k9s

RUN curl -fsSL https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash

RUN curl -fsSL "https://github.com/mikefarah/yq/releases/latest/download/yq_linux_${TARGETARCH}" -o /usr/local/bin/yq \
    && chmod +x /usr/local/bin/yq

RUN curl -fsSL https://raw.githubusercontent.com/aquasecurity/trivy/main/contrib/install.sh \
    | sh -s -- -b /usr/local/bin

RUN pip3 install --break-system-packages checkov

RUN set -eux; \
    case "${TARGETARCH}" in \
      amd64) ARCH="amd64" ;; \
      arm64) ARCH="arm64" ;; \
      *) echo "unsupported arch ${TARGETARCH}" >&2; exit 1 ;; \
    esac; \
    tmp="$(mktemp -d)"; \
    kube_bench_url="$(curl -fsSL https://api.github.com/repos/aquasecurity/kube-bench/releases/latest \
      | jq -r --arg arch "$ARCH" '.assets[] | select(.name | test("linux_" + $arch + "\\.tar\\.gz$")) | .browser_download_url' \
      | head -n 1)"; \
    test -n "$kube_bench_url"; \
    curl -fsSL "$kube_bench_url" | tar -xz -C "$tmp"; \
    install -m 0755 "$tmp/kube-bench" /usr/local/bin/kube-bench; \
    rm -rf "$tmp"

RUN set -eux; \
    git clone --depth 1 https://github.com/ahmetb/kubectx /opt/kubectx; \
    ln -s /opt/kubectx/kubectx /usr/local/bin/kubectx; \
    ln -s /opt/kubectx/kubens /usr/local/bin/kubens

RUN sed -i 's/#PasswordAuthentication yes/PasswordAuthentication no/' /etc/ssh/sshd_config \
    && sed -i 's/#PubkeyAuthentication yes/PubkeyAuthentication yes/' /etc/ssh/sshd_config \
    && sed -i 's/#PermitRootLogin prohibit-password/PermitRootLogin no/' /etc/ssh/sshd_config

EXPOSE 22

CMD ["/usr/sbin/sshd", "-D", "-e"]
