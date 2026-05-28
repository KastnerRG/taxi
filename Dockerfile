FROM ubuntu:22.04

ARG DEBIAN_FRONTEND=noninteractive
ARG USERNAME=usr
ARG CONT_WS=/repo
ARG UID=1000
ARG GID=1000

# Tool versions
ARG VERILATOR_VERSION=v5.048
ARG VERILATOR_PREFIX=/opt/verilator

# Python verification stack
ARG COCOTB_VERSION=2.0.1
ARG COCOTBEXT_AXI_VERSION=0.1.28

ENV VERILATOR_PREFIX=${VERILATOR_PREFIX}
ENV PATH=${VERILATOR_PREFIX}/bin:$PATH
ENV CONT_WS=${CONT_WS}
ENV PYTHONUNBUFFERED=1

RUN apt-get update && apt-get install -y --no-install-recommends \
    ca-certificates curl wget git \
    build-essential autoconf automake libtool pkg-config \
    bison flex gawk patchutils \
    bc m4 unzip rsync vim bash-completion \
    help2man perl time \
    python3 python3-pip python3-dev python3-setuptools python3-wheel python-is-python3 \
    libfl2 libfl-dev zlib1g-dev \
    libelf-dev liblzma-dev libunwind-dev \
    libgoogle-perftools-dev numactl ccache \
    gtkwave xauth \
 && rm -rf /var/lib/apt/lists/*

RUN ln -sf /bin/bash /bin/sh

RUN groupadd -g ${GID} ${USERNAME} \
 && useradd -m -u ${UID} -g ${GID} -s /bin/bash ${USERNAME}

# Python packages for cocotb verification
RUN python3 -m pip install --no-cache-dir --upgrade pip setuptools wheel \
 && python3 -m pip install --no-cache-dir \
      "cocotb==${COCOTB_VERSION}" \
      "cocotbext-axi==${COCOTBEXT_AXI_VERSION}" \
      pytest pytest-xdist

# Build and install Verilator from source
RUN rm -rf /tmp/verilator \
 && git clone --depth 1 --single-branch --branch "${VERILATOR_VERSION}" \
      https://github.com/verilator/verilator.git /tmp/verilator \
 && cd /tmp/verilator \
 && autoconf \
 && ./configure --prefix="${VERILATOR_PREFIX}" \
 && make -j"$(nproc)" \
 && make install \
 && rm -rf /tmp/verilator

RUN mkdir -p ${CONT_WS} \
 && chown -R ${UID}:${GID} /repo /home/${USERNAME}

USER ${USERNAME}
WORKDIR ${CONT_WS}

RUN cat >> /home/${USERNAME}/.bashrc <<'EOF'
export PATH="/opt/verilator/bin:$PATH"
export PS1="\[\e[0;36m\][\u@\h \W]\$ \[\e[m\] "
alias ll='ls -alF'
EOF

CMD ["/bin/bash"]