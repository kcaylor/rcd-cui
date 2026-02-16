# Cloud Demo Infrastructure Container
# Provides all tools needed to provision the Hetzner Cloud demo cluster
#
# Tools included:
#   - Terraform 1.7.x
#   - Ansible 2.16.x
#   - Python 3.12
#   - hcloud CLI
#   - ssh-keygen (for key generation)

FROM python:3.12-slim

# Versions
ARG TERRAFORM_VERSION=1.7.5
ARG HCLOUD_VERSION=1.42.0

# Install system dependencies
RUN apt-get update && apt-get install -y --no-install-recommends \
    curl \
    unzip \
    openssh-client \
    git \
    jq \
    && rm -rf /var/lib/apt/lists/*

# Install Terraform (auto-detect architecture)
RUN ARCH="$(dpkg --print-architecture)" \
    && case "${ARCH}" in \
         amd64) TF_ARCH="amd64" ;; \
         arm64) TF_ARCH="arm64" ;; \
         *) echo "Unsupported architecture: ${ARCH}" && exit 1 ;; \
       esac \
    && curl -fsSL "https://releases.hashicorp.com/terraform/${TERRAFORM_VERSION}/terraform_${TERRAFORM_VERSION}_linux_${TF_ARCH}.zip" -o /tmp/terraform.zip \
    && unzip /tmp/terraform.zip -d /usr/local/bin \
    && rm /tmp/terraform.zip \
    && terraform version

# Install hcloud CLI (auto-detect architecture)
RUN ARCH="$(dpkg --print-architecture)" \
    && case "${ARCH}" in \
         amd64) HC_ARCH="amd64" ;; \
         arm64) HC_ARCH="arm64" ;; \
         *) echo "Unsupported architecture: ${ARCH}" && exit 1 ;; \
       esac \
    && curl -fsSL "https://github.com/hetznercloud/cli/releases/download/v${HCLOUD_VERSION}/hcloud-linux-${HC_ARCH}.tar.gz" -o /tmp/hcloud.tar.gz \
    && tar -xzf /tmp/hcloud.tar.gz -C /usr/local/bin \
    && rm /tmp/hcloud.tar.gz \
    && hcloud version

# Install Ansible via pip (ansible 9.x = ansible-core 2.16.x)
RUN pip install --no-cache-dir \
    "ansible>=9.0,<10.0" \
    && ansible --version

# Set working directory
WORKDIR /workspace

# Default command shows available tools
CMD ["bash", "-c", "echo 'Cloud Demo Tools:' && terraform version && ansible --version | head -1 && hcloud version"]
