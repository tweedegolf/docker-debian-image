ARG DEBIAN_VERSION
FROM debian:${DEBIAN_VERSION}

RUN apt-get update \
    && DEBIAN_FRONTEND=noninteractive apt-get upgrade -y \
    && DEBIAN_FRONTEND=noninteractive apt-get install --no-install-recommends -y \
    wget \
    curl \
    ca-certificates \
    apt-transport-https \
    gnupg \
    dirmngr \
    gosu \
    git \
    dnsutils \
    tmux \
    nano \
    vim \
    lsof \
    unzip \
    libnss-wrapper \
    procps \
    strace \
    zutils \
    openssh-client \
    openssl \
    && rm -rf /var/lib/apt/lists/*

# Set default timezone
ENV TZ Europe/Amsterdam
RUN ln -snf /usr/share/zoneinfo/$TZ /etc/localtime && echo $TZ > /etc/timezone
ENV DOCKER 1

ENV DYNAMIC_USER_NAME app
ENV DYNAMIC_GROUP_NAME app
ENV DYNAMIC_USER_HOME /home/public
ENV DYNAMIC_USER_SHELL /bin/bash
ENV ROOT_SWITCH_USER ""

# Create a world writable public home folder
RUN mkdir /home/public && chmod 0777 /home/public

# Create a known hosts file with github / gitlab keys
COPY ssh_known_hosts /etc/ssh/ssh_known_hosts

# Setup docker secrets to env script
COPY docker-secrets-to-env.sh /usr/local/bin/docker-secrets-to-env

# Setup docker-entrypoint
RUN mkdir /usr/local/bin/docker-entrypoint.d
RUN mkdir /usr/local/bin/docker-entrypoint-scripts.d
COPY docker-entrypoint.sh /usr/local/bin/docker-entrypoint
RUN ln -s /usr/local/bin/docker-entrypoint /usr/local/bin/doen
ENTRYPOINT ["docker-entrypoint"]
