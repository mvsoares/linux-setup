# =============================================================================
# Module 06 — Cloud CLIs, Kubernetes & DevOps Tools
# =============================================================================
init_sub 9

ARCH_GO=$(get_arch)              # amd64 | arm64
ARCH_RUST=$(get_arch_rust)       # x86_64 | aarch64
ARCH_ALT=$(get_arch_x86_arm64)   # x86_64 | arm64

# ── AWS CLI v2 ────────────────────────────────────────────────────────────────
if command -v aws &>/dev/null; then
    skip "AWS CLI ($(aws --version 2>&1 | head -1))"
    tick "AWS CLI"
else
    info "Installing AWS CLI v2 (${ARCH_RUST})..."
    local_tmp=$(mktemp -d)
    if curl -fsSL "${CURL_TIMEOUT_OPTS[@]}" "https://awscli.amazonaws.com/awscli-exe-linux-${ARCH_RUST}.zip" \
            -o "${local_tmp}/awscliv2.zip" >> "$LOG_FILE" 2>&1; then
        unzip -q "${local_tmp}/awscliv2.zip" -d "${local_tmp}" >> "$LOG_FILE" 2>&1
        "${local_tmp}/aws/install" --update >> "$LOG_FILE" 2>&1 && ok "AWS CLI v2 installed" || warn "AWS CLI install failed"
    else
        warn "AWS CLI v2 download failed"
    fi
    rm -rf "${local_tmp}"
    tick "AWS CLI v2"
fi

# eksctl
if command -v eksctl &>/dev/null; then
    skip "eksctl"
else
    info "Installing eksctl..."
    local_tmp=$(mktemp -d)
    curl -fsSL "${CURL_TIMEOUT_OPTS[@]}" "https://github.com/eksctl-io/eksctl/releases/latest/download/eksctl_Linux_${ARCH_GO}.tar.gz" \
        -o "${local_tmp}/eksctl.tar.gz" >> "$LOG_FILE" 2>&1 \
        && tar xzf "${local_tmp}/eksctl.tar.gz" -C /usr/local/bin eksctl >> "$LOG_FILE" 2>&1 \
        && ok "eksctl installed" || warn "eksctl install failed"
    rm -rf "$local_tmp"
fi

# AWS Session Manager plugin
if command -v session-manager-plugin &>/dev/null; then
    skip "AWS Session Manager plugin"
else
    info "Installing AWS Session Manager plugin..."
    local_tmp=$(mktemp -d)
    SM_ARCH_RPM="linux_64bit"; SM_ARCH_DEB="ubuntu_64bit"
    if [[ "$ARCH_GO" == "arm64" ]]; then
        SM_ARCH_RPM="linux_arm64"; SM_ARCH_DEB="ubuntu_arm64"
    fi
    if is_fedora; then
        if curl -fsSL "${CURL_TIMEOUT_OPTS[@]}" "https://s3.amazonaws.com/session-manager-downloads/plugin/latest/${SM_ARCH_RPM}/session-manager-plugin.rpm" \
                -o "${local_tmp}/sm.rpm" >> "$LOG_FILE" 2>&1; then
            dnf install -y "${local_tmp}/sm.rpm" >> "$LOG_FILE" 2>&1 && ok "Session Manager plugin" || warn "SM plugin failed"
        else
            warn "Session Manager plugin download failed"
        fi
    else
        if curl -fsSL "${CURL_TIMEOUT_OPTS[@]}" "https://s3.amazonaws.com/session-manager-downloads/plugin/latest/${SM_ARCH_DEB}/session-manager-plugin.deb" \
                -o "${local_tmp}/sm.deb" >> "$LOG_FILE" 2>&1; then
            dpkg -i "${local_tmp}/sm.deb" >> "$LOG_FILE" 2>&1 && ok "Session Manager plugin" || warn "SM plugin failed"
        else
            warn "Session Manager plugin download failed"
        fi
    fi
    rm -rf "$local_tmp"
fi

# AWS bash completion
COMP_FILE="/etc/bash_completion.d/aws"
if [[ ! -f "$COMP_FILE" ]] && command -v aws_completer &>/dev/null; then
    mkdir -p /etc/bash_completion.d
    echo "complete -C '$(command -v aws_completer)' aws" > "$COMP_FILE"
fi
tick "AWS extras (eksctl, session-manager, completion)"

# ── Google Cloud SDK ──────────────────────────────────────────────────────────
if is_fedora; then
    if command -v gcloud &>/dev/null || [[ -f /etc/yum.repos.d/google-cloud-sdk.repo ]]; then
        tick "Google Cloud repo — already present"
    else
        info "Adding Google Cloud SDK repo..."
        cat > /etc/yum.repos.d/google-cloud-sdk.repo << GCPREPO
[google-cloud-cli]
name=Google Cloud CLI
baseurl=https://packages.cloud.google.com/yum/repos/cloud-sdk-el9-${ARCH_RUST}
enabled=1
gpgcheck=1
repo_gpgcheck=0
gpgkey=https://packages.cloud.google.com/yum/doc/rpm-package-key.gpg
GCPREPO
        tick "Google Cloud repo added"
    fi
    if command -v gcloud &>/dev/null; then
        skip "gcloud SDK"
    else
        wait_for_rpm_lock
        for _try in 1 2 3; do
            if curl -fsSL "${CURL_TIMEOUT_OPTS[@]}" "https://packages.cloud.google.com/yum/doc/rpm-package-key.gpg" \
                    -o /tmp/google-cloud-rpm-package-key.gpg >> "$LOG_FILE" 2>&1 \
                    && rpm --import /tmp/google-cloud-rpm-package-key.gpg >> "$LOG_FILE" 2>&1; then
                rm -f /tmp/google-cloud-rpm-package-key.gpg
                break
            fi
            sleep 3
        done
        dnf_each google-cloud-cli
    fi
    dnf_each google-cloud-cli-gke-gcloud-auth-plugin 2>/dev/null || true
else
    if command -v gcloud &>/dev/null \
            || { [[ -f /etc/apt/sources.list.d/google-cloud-sdk.list ]] \
                 && [[ -s /usr/share/keyrings/cloud.google.gpg ]]; }; then
        tick "Google Cloud repo — already present"
    else
        info "Adding Google Cloud SDK repo..."
        add_apt_repo "Google Cloud" "https://packages.cloud.google.com/apt/doc/apt-key.gpg" \
            "/usr/share/keyrings/cloud.google.gpg" \
            "/etc/apt/sources.list.d/google-cloud-sdk.list" \
            "deb [signed-by=/usr/share/keyrings/cloud.google.gpg] https://packages.cloud.google.com/apt cloud-sdk main" || true
        apt_quiet update
    fi
    if command -v gcloud &>/dev/null; then
        skip "gcloud SDK"
    else
        apt_each google-cloud-cli
    fi
    apt_each google-cloud-cli-gke-gcloud-auth-plugin 2>/dev/null || true
fi
tick "Google Cloud SDK + GKE auth"

# ── Azure CLI ─────────────────────────────────────────────────────────────────
if is_fedora; then
    if command -v az &>/dev/null || [[ -f /etc/yum.repos.d/azure-cli.repo ]]; then
        tick "Azure CLI repo — already present"
    else
        info "Adding Azure CLI repo..."
        rpm --import https://packages.microsoft.com/keys/microsoft.asc >> "$LOG_FILE" 2>&1 || true
        # Modern Microsoft prod repo (replaces deprecated /yumrepos/azure-cli)
        cat > /etc/yum.repos.d/azure-cli.repo << 'AZREPO'
[azure-cli]
name=Azure CLI
baseurl=https://packages.microsoft.com/rhel/9.0/prod/
enabled=1
gpgcheck=1
gpgkey=https://packages.microsoft.com/keys/microsoft.asc
AZREPO
        tick "Azure CLI repo added"
    fi
    if command -v az &>/dev/null; then
        skip "Azure CLI"
    else
        if ! dnf -y -q install azure-cli >> "$LOG_FILE" 2>&1; then
            info "dnf azure-cli unavailable on Fedora $(rpm -E %fedora) — falling back to pipx..."
            command -v pipx &>/dev/null && as_user "pipx install azure-cli" >> "$LOG_FILE" 2>&1 \
                && ok "Azure CLI (via pipx)" || warn "Azure CLI install failed"
        else
            ok "azure-cli"
        fi
    fi
else
    if command -v az &>/dev/null \
            || { [[ -f /etc/apt/sources.list.d/azure-cli.list ]] \
                 && [[ -s /usr/share/keyrings/microsoft-azure.gpg ]]; }; then
        tick "Azure CLI repo — already present"
    else
        info "Adding Azure CLI repo..."
        AZ_DISTRO=$(lsb_release -cs 2>/dev/null || echo "noble")
        if ! curl -fsSL "${CURL_TIMEOUT_OPTS[@]}" "https://packages.microsoft.com/repos/azure-cli/dists/${AZ_DISTRO}/Release" \
                &>/dev/null; then
            AZ_DISTRO="noble"
            info "Azure CLI has no repo for $(lsb_release -cs 2>/dev/null), falling back to ${AZ_DISTRO}"
        fi
        add_apt_repo "Azure CLI" "https://packages.microsoft.com/keys/microsoft.asc" \
            "/usr/share/keyrings/microsoft-azure.gpg" \
            "/etc/apt/sources.list.d/azure-cli.list" \
            "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/microsoft-azure.gpg] https://packages.microsoft.com/repos/azure-cli/ ${AZ_DISTRO} main" || true
        apt_quiet update
    fi
    if command -v az &>/dev/null; then
        skip "Azure CLI"
    else
        apt_each azure-cli
    fi
fi
tick "Azure CLI"

# ── Kubernetes tools ──────────────────────────────────────────────────────────
info "Installing Kubernetes tools..."

# kubectl
if command -v kubectl &>/dev/null; then
    skip "kubectl"
else
    info "Installing kubectl..."
    KUBECTL_VER=$(curl -fsSL "${CURL_TIMEOUT_OPTS[@]}" https://dl.k8s.io/release/stable.txt 2>/dev/null || echo "")
    if [[ -n "$KUBECTL_VER" ]]; then
        curl -fsSL "${CURL_TIMEOUT_OPTS[@]}" "https://dl.k8s.io/release/${KUBECTL_VER}/bin/linux/${ARCH_GO}/kubectl" \
            -o /usr/local/bin/kubectl >> "$LOG_FILE" 2>&1 \
            && chmod +x /usr/local/bin/kubectl && ok "kubectl ${KUBECTL_VER}" || warn "kubectl failed"
    else
        warn "kubectl — could not determine latest version"
    fi
fi

# helm
if command -v helm &>/dev/null; then
    skip "helm"
else
    info "Installing helm..."
    curl -fsSL "${CURL_TIMEOUT_OPTS[@]}" https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 -o /tmp/get-helm-3.sh \
        && bash /tmp/get-helm-3.sh >> "$LOG_FILE" 2>&1 \
        && rm -f /tmp/get-helm-3.sh \
        && ok "helm installed" || warn "helm install failed"
fi

# k9s
if command -v k9s &>/dev/null; then
    skip "k9s"
else
    install_github_tar "derailed/k9s" "Linux_${ARCH_GO}.tar.gz" "k9s" "k9s"
fi

# stern (multi-pod log tailing)
if command -v stern &>/dev/null; then
    skip "stern"
else
    install_github_tar "stern/stern" "linux_${ARCH_GO}.tar.gz" "stern" "stern"
fi

# kubectx / kubens
if command -v kubectx &>/dev/null && command -v kubens &>/dev/null; then
    skip "kubectx + kubens"
else
    info "Installing kubectx + kubens..."
    _kubectx_ver=$(_github_latest_tag "ahmetb/kubectx")
    if [[ -n "$_kubectx_ver" ]]; then
        local_tmp=$(mktemp -d)
        _kctx_ok=0
        if curl -fsSL "${CURL_TIMEOUT_OPTS[@]}" "https://github.com/ahmetb/kubectx/releases/download/${_kubectx_ver}/kubectx_${_kubectx_ver}_linux_${ARCH_RUST}.tar.gz" \
                -o "$local_tmp/kubectx.tar.gz" >> "$LOG_FILE" 2>&1 \
                && tar xzf "$local_tmp/kubectx.tar.gz" -C "$local_tmp" >> "$LOG_FILE" 2>&1 \
                && [[ -f "$local_tmp/kubectx" ]]; then
            install -m 755 "$local_tmp/kubectx" /usr/local/bin/kubectx
            _kctx_ok=$((_kctx_ok + 1))
        else
            warn "kubectx — download/extract failed"
        fi
        if curl -fsSL "${CURL_TIMEOUT_OPTS[@]}" "https://github.com/ahmetb/kubectx/releases/download/${_kubectx_ver}/kubens_${_kubectx_ver}_linux_${ARCH_RUST}.tar.gz" \
                -o "$local_tmp/kubens.tar.gz" >> "$LOG_FILE" 2>&1 \
                && tar xzf "$local_tmp/kubens.tar.gz" -C "$local_tmp" >> "$LOG_FILE" 2>&1 \
                && [[ -f "$local_tmp/kubens" ]]; then
            install -m 755 "$local_tmp/kubens" /usr/local/bin/kubens
            _kctx_ok=$((_kctx_ok + 1))
        else
            warn "kubens — download/extract failed"
        fi
        rm -rf "$local_tmp"
        [[ $_kctx_ok -eq 2 ]] && ok "kubectx + kubens (${_kubectx_ver})"
    else
        warn "kubectx/kubens — could not determine latest version"
    fi
fi

# kustomize
if command -v kustomize &>/dev/null; then
    skip "kustomize"
else
    info "Installing kustomize..."
    curl -fsSL "${CURL_TIMEOUT_OPTS[@]}" "https://raw.githubusercontent.com/kubernetes-sigs/kustomize/master/hack/install_kustomize.sh" \
        | bash -s -- /usr/local/bin >> "$LOG_FILE" 2>&1 \
        && ok "kustomize installed" || warn "kustomize failed"
fi

# kubecolor (colorized kubectl drop-in)
if command -v kubecolor &>/dev/null; then
    skip "kubecolor"
else
    install_github_tar "kubecolor/kubecolor" "linux_${ARCH_GO}.tar.gz" "kubecolor" "kubecolor"
fi

# kind (local Kubernetes clusters using Podman/Docker)
if command -v kind &>/dev/null; then
    skip "kind"
else
    install_github_bin "kubernetes-sigs/kind" "kind-linux-${ARCH_GO}" "kind" "kind"
fi
tick "Kubernetes tools (kubectl · helm · k9s · stern · kubectx · kustomize · kubecolor · kind)"

# ── DevOps, IaC & Container Security CLIs ────────────────────────────────────
info "Installing DevOps, IaC & security tools..."

# OpenTofu (open-source Terraform drop-in)
if command -v tofu &>/dev/null; then
    skip "OpenTofu ($(tofu version 2>/dev/null | head -1))"
else
    install_github_zip "opentofu/opentofu" "linux_${ARCH_GO}.zip" "tofu" "OpenTofu (tofu)"
fi

# Trivy (vulnerability scanner for containers, filesystems & IaC)
if command -v trivy &>/dev/null; then
    skip "trivy"
else
    TRIVY_ARCH="64bit"
    [[ "$ARCH_GO" == "arm64" ]] && TRIVY_ARCH="ARM64"
    install_github_tar "aquasecurity/trivy" "Linux-${TRIVY_ARCH}.tar.gz" "trivy" "trivy"
fi

# dive (inspect Docker/Podman OCI image layers)
if command -v dive &>/dev/null; then
    skip "dive"
else
    install_github_tar "wagoodman/dive" "linux_${ARCH_GO}.tar.gz" "dive" "dive"
fi

# sops + age (encrypted secrets in Git)
if command -v sops &>/dev/null; then
    skip "sops"
else
    install_github_bin "getsops/sops" "linux.${ARCH_GO}" "sops" "sops"
fi

if command -v age &>/dev/null; then
    skip "age"
else
    install_github_tar "FiloSottile/age" "linux-${ARCH_GO}.tar.gz" "age" "age"
    # Also install age-keygen if present in release
    if ! command -v age-keygen &>/dev/null; then
        install_github_tar "FiloSottile/age" "linux-${ARCH_GO}.tar.gz" "age-keygen" "age-keygen"
    fi
fi

# act (run GitHub Actions locally)
if command -v act &>/dev/null; then
    skip "act"
else
    install_github_tar "nektos/act" "Linux_${ARCH_ALT}.tar.gz" "act" "act"
fi
tick "DevOps & security CLIs (opentofu · trivy · dive · sops · age · act)"

# ── Bash completions for K8s & DevOps CLIs ───────────────────────────────────
mkdir -p /etc/bash_completion.d
command -v kubectl &>/dev/null && kubectl completion bash > /etc/bash_completion.d/kubectl 2>/dev/null || true
command -v helm    &>/dev/null && helm completion bash    > /etc/bash_completion.d/helm    2>/dev/null || true
command -v eksctl  &>/dev/null && eksctl completion bash  > /etc/bash_completion.d/eksctl  2>/dev/null || true
command -v k9s     &>/dev/null && k9s completion bash     > /etc/bash_completion.d/k9s     2>/dev/null || true

# ── Cloud & K8s aliases (/etc/profile.d + ~/.bashrc.d) ───────────────────────
read -r -d '' CLOUD_ALIASES << 'ALIASES' || true
#!/usr/bin/env bash
[[ $- != *i* ]] && return
[[ -n "${__LINUX_SETUP_CLOUD_LOADED:-}" ]] && return
__LINUX_SETUP_CLOUD_LOADED=1

# AWS
alias awswho='aws sts get-caller-identity'
alias awsregion='aws configure get region'
alias awsprofiles='aws configure list-profiles'
awsp() {
    local p; if command -v fzf &>/dev/null; then
        p=$(aws configure list-profiles 2>/dev/null | fzf --prompt="AWS profile: ")
    else aws configure list-profiles; read -rp "Profile: " p; fi
    [[ -n "$p" ]] && export AWS_PROFILE="$p" && echo "AWS_PROFILE=$p"
}
# GCP
alias gcpwho='gcloud auth list'
alias gcpproject='gcloud config get-value project'
gcpp() {
    local p; if command -v fzf &>/dev/null; then
        p=$(gcloud projects list --format="value(projectId)" 2>/dev/null | fzf --prompt="GCP project: ")
    else gcloud projects list; read -rp "Project ID: " p; fi
    [[ -n "$p" ]] && gcloud config set project "$p"
}
# Azure
alias azwho='az account show'
alias azaccounts='az account list --output table'
azp() {
    local s; if command -v fzf &>/dev/null; then
        s=$(az account list --query "[].name" -o tsv 2>/dev/null | fzf --prompt="Azure sub: ")
    else az account list --output table; read -rp "Subscription: " s; fi
    [[ -n "$s" ]] && az account set --subscription "$s" && az account show --output table
}
# K8s (use kubecolor automatically when installed)
if command -v kubecolor &>/dev/null; then
    alias k='kubecolor'
    complete -o default -F __start_kubectl k 2>/dev/null || true
else
    alias k='kubectl'
    complete -o default -F __start_kubectl k 2>/dev/null || true
fi
alias kx='kubectx'; alias kn='kubens'
alias kgp='k get pods'; alias kgs='k get svc'
alias kga='k get all'; alias kdp='k describe pod'
alias klo='kubectl logs -f'; alias kex='kubectl exec -it'
command -v tofu &>/dev/null && alias tf='tofu'
export USE_GKE_GCLOUD_AUTH_PLUGIN=True
ALIASES

install_shell_snippet "97-cloud-aliases.sh" "$CLOUD_ALIASES"
tick "Cloud & K8s shell aliases + bash completions"

ok "Cloud CLIs & Kubernetes tools complete"
