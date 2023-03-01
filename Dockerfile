# An incomplete base Docker image for running JupyterHub
#
# Add your configuration to create a complete derivative Docker image.
#
# Include your configuration settings by starting with one of two options:
#
# Option 1:
#
# FROM jupyterhub/jupyterhub:latest
#
# And put your configuration file jupyterhub_config.py in /srv/jupyterhub/jupyterhub_config.py.
#
# Option 2:
#
# Or you can create your jupyterhub config and database on the host machine, and mount it with:
#
# docker run -v $PWD:/srv/jupyterhub -t jupyterhub/jupyterhub
#
# NOTE
# If you base on jupyterhub/jupyterhub-onbuild
# your jupyterhub_config.py will be added automatically
# from your docker directory.

ARG BASE_IMAGE=tensorflow/tensorflow:2.11.0-gpu
FROM $BASE_IMAGE AS builder

USER root

ENV DEBIAN_FRONTEND noninteractive
RUN apt-get update \
    && apt-get install -yq --no-install-recommends \
        build-essential \
        ca-certificates \
        locales \
        python3-dev \
        python3-pip \
        python3-pycurl \
        wget \
    && curl -sL https://deb.nodesource.com/setup_16.x | bash - \
    && apt-get install -yq nodejs \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

# copy everything except whats in .dockerignore, its a
# compromise between needing to rebuild and maintaining
# what needs to be part of the build
COPY . /src/jupyterhub/

WORKDIR /src/jupyterhub

RUN python3 -m pip install --upgrade setuptools pip wheel

# Build client component packages (they will be copied into ./share and
# packaged with the built wheel.)
RUN npm install
RUN python3 -m pip wheel --wheel-dir wheelhouse .


FROM $BASE_IMAGE

USER root

ENV DEBIAN_FRONTEND=noninteractive

RUN apt-get update \
    && apt-get install -yq --no-install-recommends \
        build-essential \
        ca-certificates \
        locales \
        python3-dev \
        python3-pip \
        python3-pycurl \
        wget \
    && curl -sL https://deb.nodesource.com/setup_16.x | bash - \
    && apt-get install -yq nodejs \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

ENV SHELL=/bin/bash \
    LC_ALL=en_US.UTF-8 \
    LANG=en_US.UTF-8 \
    LANGUAGE=en_US.UTF-8

RUN locale-gen $LC_ALL

RUN apt-get update \
    && apt install -yq --no-install-recommends software-properties-common dirmngr \
    &&  apt-key adv --keyserver keyserver.ubuntu.com --recv-keys E298A3A825C0D65DFD57CBB651716619E084DAB9 \
    && add-apt-repository "deb https://cloud.r-project.org/bin/linux/ubuntu $(lsb_release -cs)-cran40/" \
    && apt install -yq --no-install-recommends r-base

RUN pip install notebook matplotlib scipy sklearn pandas mongoengine https://github.com/andreas-h/sshauthenticator/archive/v0.1.zip

RUN apt-get update \
    && apt-get install -yq --no-install-recommends \
        libcairo2-dev \
        libxt-dev \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

RUN R -e "install.packages('IRkernel', repos='http://cran.us.r-project.org'); IRkernel::installspec(user=FALSE)"

# always make sure pip is up to date!
RUN python3 -m pip install --no-cache --upgrade setuptools pip

RUN npm install -g configurable-http-proxy@^4.2.0 \
    && rm -rf ~/.npm

# install the wheels we built in the first stage
COPY --from=builder /src/jupyterhub/wheelhouse /tmp/wheelhouse
RUN python3 -m pip install --no-cache --ignore-installed /tmp/wheelhouse/*

RUN mkdir -p /srv/jupyterhub/
WORKDIR /srv/jupyterhub/

EXPOSE 8000

LABEL maintainer="Jupyter Project <jupyter@googlegroups.com>"
LABEL org.jupyter.service="jupyterhub"

CMD ["jupyterhub"]
