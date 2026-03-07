# Use the official Ubuntu base image
FROM hub.rat.dev/ubuntu:24.04

# Avoid prompts during installation
ARG DEBIAN_FRONTEND=noninteractive



# 1. Copy BOTH 'uv' and 'bun' binaries from their official images
COPY --from=ghcr.io/astral-sh/uv:latest /uv /uvx /bin/
COPY --from=hub.rat.dev/oven/bun:latest /usr/local/bin/bun /usr/local/bin/bun

# 2. Install only minimal system dependencies
ARG DEBIAN_FRONTEND=noninteractive
RUN apt-get update && apt-get install -y \
    bash-completion \
    # 1. Core Build Tools
    build-essential \
    pkg-config \
    # 2. Networking & Debugging
    curl net-tools wget \
    iputils-ping dnsutils \
    # 3. CLI Utilities & Performance
    tmux ncdu nano \
    htop tree jq \
    # 4. Version Control & Storage
    git unzip \
    # 5. Language Support
    python3 python3-pip \
    ca-certificates \
    && rm -rf /var/lib/apt/lists/*

# 3. Environment & Workspace Setup
ENV UV_LINK_MODE=copy \
    PYTHONUNBUFFERED=1 \
    VIRTUAL_ENV=/opt/.venv \
    PATH="/opt/.venv/bin:/usr/local/bin:$PATH"

WORKDIR /app

# 4. Venv & Completions
RUN uv venv $VIRTUAL_ENV -p 3.12 && \
    mkdir -p /etc/bash_completion.d && \
    uv generate-shell-completion bash > /etc/bash_completion.d/uv && \
    ln -s /usr/local/bin/bun /usr/local/bin/npm

# 5. Global Shell Configuration (Ensures non-interactive shell support)
RUN echo 'source /etc/profile.d/bash_completion.sh' >> /etc/bash.bashrc && \
    echo 'source /opt/.venv/bin/activate' >> /etc/bash.bashrc && \
    echo 'alias pip="uv pip"' >> /etc/bash.bashrc

# 6. Improved Entrypoint Script
# Uses "exec" to replace the shell with tmux and handles non-interactive commands
RUN printf '#!/bin/bash\n\
if [ "$#" -gt 0 ]; then\n\
    exec "$@"\n\
fi\n\
\n\
# Create the session if it doesn't exist\n\
tmux has-session -t docker 2>/dev/null || tmux new-session -d -s docker\n\
\n\
# If there is no TTY (non-interactive), stay alive with tail\n\
if [ ! -t 0 ]; then\n\
    tail -f /dev/null\n\
else\n\
    exec tmux attach-session -t docker\n\
fi' > /entrypoint.sh && \
chmod +x /entrypoint.sh


ENTRYPOINT ["/entrypoint.sh"]