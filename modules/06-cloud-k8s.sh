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
    curl -fsSL "https://s3.amazonaws.com/session-manager-downloads/plugin/latest/ubuntu_64bit/session-manager-plugin.deb" \
        -o "${local_tmp}/sm.deb" >> "$LOG_FILE" 2>&1
    dpkg -i "${local_tmp}/sm.deb" >> "$LOG_FILE" 2>&1 && ok "Session Manager plugin" || warn "SM plugin failed"
    rm -rf "$local_tmp"
fi

# AWS bash completion
COMP_FILE="/etc/bash_completion.d/aws"
if [[ ! -f "$COMP_FILE" ]] && command -v aws_completer &>/dev/null; then
    echo "complete -C '$(command -v aws_completer)' aws" > "$COMP_FILE"
fi
tick "AWS extras (eksctl, session-manager, completion)"

# ── Google Cloud SDK ──────────────────────────────────────────────────────────
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
tick "Google Cloud SDK + GKE auth"

# ── Azure CLI ─────────────────────────────────────────────────────────────────
if command -v az &>/dev/null \
        || { [[ -f /etc/apt/sources.list.d/azure-cli.list ]] \
             && [[ -s /usr/share/keyrings/microsoft-azure.gpg ]]; }; then
    tick "Azure CLI repo — already present"
else
    info "Adding Azure CLI repo..."
    curl -fsSL "https://packages.microsoft.com/keys/microsoft.asc" \
        | gpg --batch --yes --dearmor -o /usr/share/keyrings/microsoft-azure.gpg >> "$LOG_FILE" 2>&1 || warn "Azure key failed"
    # Fall back to noble if Azure CLI has no repo for the current codename
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
tick "Azure CLI"

# ── Kubernetes tools ──────────────────────────────────────────────────────────
info "Installing Kubernetes tools..."

# kubectl
if command -v kubectl &>/dev/null; then
    skip "kubectl"
else
    info "Installing kubectl..."
    KUBECTL_VER=$(curl -fsSL https://dl.k8s.io/release/stable.txt 2>/dev/null)
    if [[ -n "$KUBECTL_VER" ]]; then
        curl -fsSL "https://dl.k8s.io/release/${KUBECTL_VER}/bin/linux/$(dpkg --print-architecture)/kubectl" \
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
    curl -fsSL "https://github.com/ahmetb/kubectx/releases/latest/download/kubectx_${_kubectx_ver}_linux_${_kubectx_arch}.tar.gz" \
        -o "$local_tmp/kubectx.tar.gz" >> "$LOG_FILE" 2>&1
    tar xzf "$local_tmp/kubectx.tar.gz" -C "$local_tmp" >> "$LOG_FILE" 2>&1
    if [[ -f "$local_tmp/kubectx" ]]; then
        install "$local_tmp/kubectx" /usr/local/bin/kubectx
    else
        warn "kubectx — binary not found in archive"
    fi
    curl -fsSL "https://github.com/ahmetb/kubectx/releases/latest/download/kubens_${_kubectx_ver}_linux_${_kubectx_arch}.tar.gz" \
        -o "$local_tmp/kubens.tar.gz" >> "$LOG_FILE" 2>&1
    tar xzf "$local_tmp/kubens.tar.gz" -C "$local_tmp" >> "$LOG_FILE" 2>&1
    if [[ -f "$local_tmp/kubens" ]]; then
        install "$local_tmp/kubens" /usr/local/bin/kubens
    else
        warn "kubens — binary not found in archive"
    fi
    rm -rf "$local_tmp"
    ok "kubectx + kubens"
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
