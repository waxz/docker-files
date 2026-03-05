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

# 2. Generate and enable completions
# RUN echo "source /etc/profile.d/bash_completion.sh" >> /etc/bash.bashrc && \
#     mkdir -p /etc/bash_completion.d && \
#     # Generate uv completions (explicitly for bash)
#     uv generate-shell-completion bash > /etc/bash_completion.d/uv && \
#     # Use getcompletes for bun to avoid shell detection errors
#     bun getcompletes > /etc/bash_completion.d/bun



# 3. Fix: Ensure aliases also attempt completion
# This tells bash to use the same completion logic for 'npm' as it does for 'bun'
#RUN echo 'complete -F _$BASH_COMPLETION_COMMAND npm 2>/dev/null || complete -F _bun npm' >> /etc/bash.bashrc

# 4. Setup aliases and workspace
RUN echo 'alias pip="uv pip"' >> /etc/bash.bashrc && \
    echo 'alias npm="bun"' >> /etc/bash.bashrc

# 5. Replace the alias line in your Dockerfile with this:
RUN ln -s /usr/local/bin/bun /usr/local/bin/npm

# 6. Persistent Tmux Entrypoint
# This script checks if a tmux session exists; if not, it creates one.
RUN echo '#!/bin/bash\n\
 tmux has-session -t docker 2>/dev/null\n\
 if [ $? != 0 ]; then\n\
   tmux new-session -d -s docker\n\
 fi\n\
 tmux attach-session -t docker' > /usr/local/bin/entrypoint.sh && \
 chmod +x /usr/local/bin/entrypoint.sh



WORKDIR /app
RUN uv venv /app/.venv
ENV PATH="/app/.venv/bin:$PATH"

# Verify everything is working
# RUN uv --version && bun --version && npm --version && python3 --version


# Set the entrypoint to launch tmux automatically
ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]