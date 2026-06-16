FROM ubuntu:24.04

ARG TARGETARCH

ENV DEBIAN_FRONTEND=noninteractive

RUN apt-get update \
    && apt-get install -y --no-install-recommends \
      apparmor \
      apparmor-utils \
      bash \
      bash-completion \
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
      sudo \
      tar \
      tcpdump \
      tree \
      vim \
      wget \
    && rm -rf /var/lib/apt/lists/*

RUN useradd -m -s /bin/bash student \
    && mkdir -p /run/sshd /home/student/.ssh /home/student/.kube \
    && touch /home/student/.hushlogin \
    && chown -R student:student /home/student \
    && chmod 700 /home/student/.ssh \
    && install -d -m 0750 /etc/sudoers.d \
    && printf '%s\n' \
      'student ALL=(root) NOPASSWD: /usr/sbin/apparmor_parser, /usr/sbin/aa-status, /usr/sbin/aa-enabled' \
      > /etc/sudoers.d/cks-apparmor \
    && chmod 0440 /etc/sudoers.d/cks-apparmor

RUN curl -fsSL "https://dl.k8s.io/release/v1.36.1/bin/linux/${TARGETARCH}/kubectl" -o /usr/local/bin/kubectl \
    && chmod +x /usr/local/bin/kubectl \
    && kubectl completion bash > /etc/bash_completion.d/kubectl \
    && printf '%s\n' \
      'alias k=kubectl' \
      'complete -o default -F __start_kubectl k' \
      > /etc/bash_completion.d/cks-kubectl

RUN install -d /etc/cks-shell \
    && printf '%s\n' \
      'export KUBECONFIG=${KUBECONFIG:-/home/student/.kube/config}' \
      'if [[ $- == *i* ]] && [ -z "${CKS_TASK_SHOWN:-}" ] && [ -f /home/student/task.txt ]; then' \
      '  export CKS_TASK_SHOWN=1' \
      '  cat /home/student/task.txt' \
      '  echo' \
      'fi' \
      'if ! type _get_comp_words_by_ref >/dev/null 2>&1 && [ -f /usr/share/bash-completion/bash_completion ]; then' \
      '  . /usr/share/bash-completion/bash_completion' \
      'fi' \
      "alias k=kubectl" \
      "alias kgp='kubectl get pods'" \
      "alias kga='kubectl get all'" \
      "alias val='sh val.sh'" \
      "alias apparmor_parser='sudo apparmor_parser'" \
      "alias aa-status='sudo aa-status'" \
      "alias aa-enabled='sudo aa-enabled'" \
      "PS1='\[\033[31m\]student@\${CKS_LAB_NAME:-cks-lab}:\\w$ \[\033[0m\]'" \
      > /etc/cks-shell/bashrc \
    && printf '%s\n' \
      'if [ -f /etc/cks-shell/bashrc ]; then' \
      '  . /etc/cks-shell/bashrc' \
      'fi' \
      >> /etc/bash.bashrc

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
    install_binary_asset() { \
      repo="$1"; pattern="$2"; binary="$3"; \
      url="$(curl -fsSL "https://api.github.com/repos/${repo}/releases/latest" \
        | jq -r --arg pattern "$pattern" '.assets[] | select(.name | test($pattern)) | .browser_download_url' \
        | head -n 1)"; \
      test -n "$url" || { echo "no release asset matched ${repo}: ${pattern}" >&2; exit 1; }; \
      curl -fsSL "$url" -o "/usr/local/bin/${binary}"; \
      chmod +x "/usr/local/bin/${binary}"; \
    }; \
    install_istioctl() { \
      tmp="$(mktemp -d)"; \
      url="$(curl -fsSL https://api.github.com/repos/istio/istio/releases/latest \
        | jq -r --arg arch "$ARCH" '.assets[] | select(.name | test("istio-.*-linux-" + $arch + "\\.tar\\.gz$")) | .browser_download_url' \
        | head -n 1)"; \
      test -n "$url" || { echo "no release asset matched istio/istio for ${ARCH}" >&2; exit 1; }; \
      curl -fsSL "$url" | tar -xz -C "$tmp"; \
      install -m 0755 "$tmp"/istio-*/bin/istioctl /usr/local/bin/istioctl; \
      rm -rf "$tmp"; \
    }; \
    install_binary_asset argoproj/argo-cd "argocd-linux-${ARCH}$" argocd; \
    install_tar_asset cilium/cilium-cli "cilium-linux-${ARCH}\\.tar\\.gz$" cilium; \
    install_tar_asset cilium/hubble "hubble-linux-${ARCH}\\.tar\\.gz$" hubble; \
    install_istioctl; \
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

RUN set -eux; \
    case "${TARGETARCH}" in \
      amd64) ARCH="amd64" ;; \
      arm64) ARCH="arm64" ;; \
      *) echo "unsupported arch ${TARGETARCH}" >&2; exit 1 ;; \
    esac; \
    url="$(curl -fsSL https://api.github.com/repos/kubernetes-sigs/bom/releases/latest \
      | jq -r --arg arch "$ARCH" '.assets[] | select(.name == ("bom-" + $arch + "-linux")) | .browser_download_url' \
      | head -n 1)"; \
    test -n "$url"; \
    curl -fsSL "$url" -o /usr/local/bin/bom; \
    chmod 0755 /usr/local/bin/bom; \
    test -x /usr/local/bin/bom; \
    bom version

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


RUN sed -i -E \
      -e 's/^([[:space:]]*session[[:space:]]+optional[[:space:]]+pam_motd.so)/#\1/' \
      -e 's/^([[:space:]]*session[[:space:]]+optional[[:space:]]+pam_lastlog.so)/#\1/' \
      /etc/pam.d/sshd \
    && install -d /etc/ssh/sshd_config.d \
    && printf '%s\n' 'PrintMotd no' 'PrintLastLog no' > /etc/ssh/sshd_config.d/99-cks-quiet-login.conf
RUN sed -i 's/#PasswordAuthentication yes/PasswordAuthentication no/' /etc/ssh/sshd_config \
    && sed -i 's/#PubkeyAuthentication yes/PubkeyAuthentication yes/' /etc/ssh/sshd_config \
    && sed -i 's/#PermitRootLogin prohibit-password/PermitRootLogin no/' /etc/ssh/sshd_config

EXPOSE 22

CMD ["/usr/sbin/sshd", "-D", "-e"]
