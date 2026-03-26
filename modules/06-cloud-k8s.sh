# =============================================================================
# Module 06 — Cloud CLIs & Kubernetes Tools
# =============================================================================
init_sub 8

# ── AWS CLI v2 ────────────────────────────────────────────────────────────────
if command -v aws &>/dev/null; then
    skip "AWS CLI ($(aws --version 2>&1 | head -1))"
    tick "AWS CLI"
else
    info "Installing AWS CLI v2..."
    local_tmp=$(mktemp -d)
    if curl -fsSL "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" \
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
    EKSCTL_ARCH=$(uname -m | sed 's/x86_64/amd64/;s/aarch64/arm64/')
    local_tmp=$(mktemp -d)
    curl -fsSL "https://github.com/eksctl-io/eksctl/releases/latest/download/eksctl_Linux_${EKSCTL_ARCH}.tar.gz" \
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
    if is_fedora; then
        curl -fsSL "https://s3.amazonaws.com/session-manager-downloads/plugin/latest/linux_64bit/session-manager-plugin.rpm" \
            -o "${local_tmp}/sm.rpm" >> "$LOG_FILE" 2>&1
        dnf install -y "${local_tmp}/sm.rpm" >> "$LOG_FILE" 2>&1 && ok "Session Manager plugin" || warn "SM plugin failed"
    else
        curl -fsSL "https://s3.amazonaws.com/session-manager-downloads/plugin/latest/ubuntu_64bit/session-manager-plugin.deb" \
            -o "${local_tmp}/sm.deb" >> "$LOG_FILE" 2>&1
        dpkg -i "${local_tmp}/sm.deb" >> "$LOG_FILE" 2>&1 && ok "Session Manager plugin" || warn "SM plugin failed"
    fi
    rm -rf "$local_tmp"
fi

# AWS bash completion
COMP_FILE="/etc/bash_completion.d/aws"
if [[ ! -f "$COMP_FILE" ]] && command -v aws_completer &>/dev/null; then
    echo "complete -C '$(command -v aws_completer)' aws" > "$COMP_FILE"
fi
tick "AWS extras (eksctl, session-manager, completion)"

# ── Google Cloud SDK ──────────────────────────────────────────────────────────
if is_fedora; then
    if command -v gcloud &>/dev/null || [[ -f /etc/yum.repos.d/google-cloud-sdk.repo ]]; then
        tick "Google Cloud repo — already present"
    else
        info "Adding Google Cloud SDK repo..."
        cat > /etc/yum.repos.d/google-cloud-sdk.repo << 'GCPREPO'
[google-cloud-cli]
name=Google Cloud CLI
baseurl=https://packages.cloud.google.com/yum/repos/cloud-sdk-el9-x86_64
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
            if curl -fsSL "https://packages.cloud.google.com/yum/doc/rpm-package-key.gpg" \
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
        curl -fsSL "https://packages.cloud.google.com/apt/doc/apt-key.gpg" \
            | gpg --batch --yes --dearmor -o /usr/share/keyrings/cloud.google.gpg >> "$LOG_FILE" 2>&1 || warn "GCP key fetch failed"
        echo "deb [signed-by=/usr/share/keyrings/cloud.google.gpg] \
https://packages.cloud.google.com/apt cloud-sdk main" \
            > /etc/apt/sources.list.d/google-cloud-sdk.list
        apt_quiet update
        tick "Google Cloud repo added"
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
        rpm --import https://packages.microsoft.com/keys/microsoft.asc >> "$LOG_FILE" 2>&1
        cat > /etc/yum.repos.d/azure-cli.repo << 'AZREPO'
[azure-cli]
name=Azure CLI
baseurl=https://packages.microsoft.com/yumrepos/azure-cli
enabled=1
gpgcheck=1
gpgkey=https://packages.microsoft.com/keys/microsoft.asc
AZREPO
        tick "Azure CLI repo added"
    fi
    if command -v az &>/dev/null; then
        skip "Azure CLI"
    else
        dnf_each azure-cli
    fi
else
    if command -v az &>/dev/null \
            || { [[ -f /etc/apt/sources.list.d/azure-cli.list ]] \
                 && [[ -s /usr/share/keyrings/microsoft-azure.gpg ]]; }; then
        tick "Azure CLI repo — already present"
    else
        info "Adding Azure CLI repo..."
        curl -fsSL "https://packages.microsoft.com/keys/microsoft.asc" \
            | gpg --batch --yes --dearmor -o /usr/share/keyrings/microsoft-azure.gpg >> "$LOG_FILE" 2>&1 || warn "Azure key failed"
        AZ_DISTRO=$(lsb_release -cs 2>/dev/null || echo "noble")
        if ! curl -fsSL "https://packages.microsoft.com/repos/azure-cli/dists/${AZ_DISTRO}/Release" \
                &>/dev/null; then
            AZ_DISTRO="noble"
            info "Azure CLI has no repo for $(lsb_release -cs 2>/dev/null), falling back to ${AZ_DISTRO}"
        fi
        echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/microsoft-azure.gpg] \
https://packages.microsoft.com/repos/azure-cli/ ${AZ_DISTRO} main" \
            > /etc/apt/sources.list.d/azure-cli.list
        apt_quiet update
        tick "Azure CLI repo added"
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
    if [[ "${USE_PINNED_VERSIONS:-}" == "true" ]]; then
        KUBECTL_VER="${KUBECTL_VER_PIN:-}"
    else
        KUBECTL_VER=$(safe_curl_text "https://dl.k8s.io/release/stable.txt")
        [[ -z "$KUBECTL_VER" ]] && KUBECTL_VER="${KUBECTL_VER_PIN:-}"
    fi
    if [[ -n "$KUBECTL_VER" ]]; then
        curl -fsSL "https://dl.k8s.io/release/${KUBECTL_VER}/bin/linux/$(get_arch)/kubectl" \
            -o /usr/local/bin/kubectl >> "$LOG_FILE" 2>&1
        chmod +x /usr/local/bin/kubectl && ok "kubectl ${KUBECTL_VER}" || warn "kubectl failed"
    else
        warn "kubectl — could not determine latest version"
    fi
fi

# helm
if command -v helm &>/dev/null; then
    skip "helm"
else
    info "Installing helm..."
    curl -fsSL https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash >> "$LOG_FILE" 2>&1 \
        && ok "helm installed" || warn "helm install failed"
fi

# k9s
if command -v k9s &>/dev/null; then
    skip "k9s"
else
    install_github_tar "derailed/k9s" "Linux_amd64.tar.gz" "k9s" "k9s"
fi

# stern (multi-pod log tailing)
if command -v stern &>/dev/null; then
    skip "stern"
else
    install_github_tar "stern/stern" "linux_amd64.tar.gz" "stern" "stern"
fi

# kubectx / kubens
if command -v kubectx &>/dev/null; then
    skip "kubectx"
else
    info "Installing kubectx + kubens..."
    local_tmp=$(mktemp -d)
    _kubectx_ver="v$(github_latest_version ahmetb/kubectx)"
    _kubectx_arch=$(uname -m)
    if [[ "$_kubectx_ver" == "v" ]]; then
        warn "kubectx — could not determine version"; rm -rf "$local_tmp"
    else
        if curl -fsSL "https://github.com/ahmetb/kubectx/releases/latest/download/kubectx_${_kubectx_ver}_linux_${_kubectx_arch}.tar.gz" \
            -o "$local_tmp/kubectx.tar.gz" >> "$LOG_FILE" 2>&1 && \
           tar xzf "$local_tmp/kubectx.tar.gz" -C "$local_tmp" >> "$LOG_FILE" 2>&1 && \
           [[ -f "$local_tmp/kubectx" ]]; then
            install "$local_tmp/kubectx" /usr/local/bin/kubectx
        else
            warn "kubectx — download/extract failed"
        fi
        if curl -fsSL "https://github.com/ahmetb/kubectx/releases/latest/download/kubens_${_kubectx_ver}_linux_${_kubectx_arch}.tar.gz" \
            -o "$local_tmp/kubens.tar.gz" >> "$LOG_FILE" 2>&1 && \
           tar xzf "$local_tmp/kubens.tar.gz" -C "$local_tmp" >> "$LOG_FILE" 2>&1 && \
           [[ -f "$local_tmp/kubens" ]]; then
            install "$local_tmp/kubens" /usr/local/bin/kubens
        else
            warn "kubens — download/extract failed"
        fi
        rm -rf "$local_tmp"
        ok "kubectx + kubens"
    fi
fi

# kustomize
if command -v kustomize &>/dev/null; then
    skip "kustomize"
else
    info "Installing kustomize..."
    curl -fsSL "https://raw.githubusercontent.com/kubernetes-sigs/kustomize/master/hack/install_kustomize.sh" \
        | bash -s -- /usr/local/bin >> "$LOG_FILE" 2>&1 \
        && ok "kustomize installed" || warn "kustomize failed"
fi
tick "Kubernetes tools (kubectl · helm · k9s · stern · kubectx · kustomize)"

# ── Cloud aliases ─────────────────────────────────────────────────────────────
cat > /etc/profile.d/97-cloud-aliases.sh << 'ALIASES'
#!/usr/bin/env bash
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
# K8s
alias k='kubectl'; alias kx='kubectx'; alias kn='kubens'
alias kgp='kubectl get pods'; alias kgs='kubectl get svc'
alias kga='kubectl get all'; alias kdp='kubectl describe pod'
alias klo='kubectl logs -f'; alias kex='kubectl exec -it'
export USE_GKE_GCLOUD_AUTH_PLUGIN=True
ALIASES
chmod 644 /etc/profile.d/97-cloud-aliases.sh
tick "Cloud & K8s shell aliases"

ok "Cloud CLIs & Kubernetes tools complete"
