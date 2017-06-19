# CNTK Dockerfile
#   CPU only
#   No 1-bit SGD

FROM ubuntu:14.04

RUN apt-get update && apt-get install -y --no-install-recommends \
        autotools-dev \
        build-essential \
        cmake \
        git \
        g++-multilib \
        gcc-multilib \
        gfortran-multilib \
        libavcodec-dev \
        libavformat-dev \
        libjasper-dev \
        libjpeg-dev \
        libpng-dev \
        liblapacke-dev \
        libswscale-dev \
        libtiff-dev \
        pkg-config \
        wget \
        zlib1g-dev \
        # Protobuf
        ca-certificates \
        curl \
        unzip \
        # For Kaldi
        python-dev \
        automake \
        libtool \
        autoconf \
        subversion \
        # For Kaldi's dependencies
        libapr1 libaprutil1 libltdl-dev libltdl7 libserf-1-1 libsigsegv2 libsvn1 m4 \
        # For Java Bindings
        openjdk-7-jdk \
        # For SWIG
        libpcre++-dev && \
    rm -rf /var/lib/apt/lists/*

# Upgrade cmake
RUN sudo apt-get update \
    && sudo apt-get install -y software-properties-common \
    && sudo add-apt-repository ppa:george-edison55/cmake-3.x \
    && sudo apt-get update \
    && sudo apt-get install -y cmake

## PYTHON

# Swig
RUN cd /root && \
    wget -q http://prdownloads.sourceforge.net/swig/swig-3.0.10.tar.gz -O - | tar xvfz - && \
    cd swig-3.0.10 && \
    ./configure --without-perl5 && \
    make -j $(nproc) && \
    make install

# Anaconda
RUN wget -q https://repo.continuum.io/archive/Anaconda2-4.4.0-Linux-x86_64.sh && \
    bash Anaconda2-4.4.0-Linux-x86_64.sh -b && \
    rm Anaconda2-4.4.0-Linux-x86_64.sh

# Build cntk conda env
RUN wget -q https://raw.githubusercontent.com/Microsoft/CNTK/master/Scripts/install/linux/conda-linux-cntk-py27-environment.yml -O /tmp/conda-linux-cntk-py27-environment.yml && \
    /root/anaconda2/bin/conda env create -p /root/anaconda2/envs/cntk-py27/ --file /tmp/conda-linux-cntk-py27-environment.yml

# Activate the Anaconda environemnt
ENV PATH /root/anaconda2/envs/cntk-py27/bin:$PATH

RUN OPENMPI_VERSION=1.10.3 && \
    wget -q -O - https://www.open-mpi.org/software/ompi/v1.10/downloads/openmpi-${OPENMPI_VERSION}.tar.gz | tar -xzf - && \
    cd openmpi-${OPENMPI_VERSION} && \
    ./configure --prefix=/usr/local/mpi && \
    make -j"$(nproc)" install && \
    rm -rf /openmpi-${OPENMPI_VERSION}

ENV PATH /usr/local/mpi/bin:$PATH
ENV LD_LIBRARY_PATH /usr/local/mpi/lib:$LD_LIBRARY_PATH

RUN LIBZIP_VERSION=1.1.2 && \
    wget -q -O - http://nih.at/libzip/libzip-${LIBZIP_VERSION}.tar.gz | tar -xzf - && \
    cd libzip-${LIBZIP_VERSION} && \
    ./configure && \
    make -j"$(nproc)" install && \
    rm -rf /libzip-${LIBZIP_VERSION}

ENV LD_LIBRARY_PATH /usr/local/lib:$LD_LIBRARY_PATH

RUN OPENCV_VERSION=3.1.0 && \
    wget -q -O - https://github.com/Itseez/opencv/archive/${OPENCV_VERSION}.tar.gz | tar -xzf - && \
    cd opencv-${OPENCV_VERSION} && \
    mkdir build && \
    cd build && \
    cmake -DCMAKE_BUILD_TYPE=RELEASE \
          -DPYTHON_EXECUTABLE="/root/anaconda2/envs/cntk-py27/bin/python2.7" \
          -DPYTHON_INCLUDE_DIR=$(python -c "from distutils.sysconfig import get_python_inc; print(get_python_inc())") \
          -DPYTHON_LIBRARY=$(python -c "import distutils.sysconfig as sysconfig; print(sysconfig.get_config_var('LIBDIR'))") \
          -DCMAKE_INSTALL_PREFIX=/usr/local/opencv-${OPENCV_VERSION} .. && \
    make -j"$(nproc)" && \
    make -j"$(nproc)" install && \
    cd ../.. && \
    rm -rf /opencv-${OPENCV_VERSION}

RUN OPENBLAS_VERSION=0.2.18 && \
    wget -q -O - https://github.com/xianyi/OpenBLAS/archive/v${OPENBLAS_VERSION}.tar.gz | tar -xzf - && \
    cd OpenBLAS-${OPENBLAS_VERSION} && \
    make -j"$(nproc)" USE_OPENMP=1 | tee make.log && \
    grep -qF 'OpenBLAS build complete. (BLAS CBLAS LAPACK LAPACKE)' make.log && \
    grep -qF 'Use OpenMP in the multithreading.' make.log && \
    make PREFIX=/usr/local/openblas install && \
    rm -rf /OpenBLAS-${OPENBLAS_VERSION}

ENV LD_LIBRARY_PATH /usr/local/openblas/lib:$LD_LIBRARY_PATH

# Install Boost 1.60.0
RUN BOOST_VERSION=1_60_0 && \
    BOOST_DOTTED_VERSION=$(echo $BOOST_VERSION | tr _ .) && \
    wget -q -O - https://sourceforge.net/projects/boost/files/boost/${BOOST_DOTTED_VERSION}/boost_${BOOST_VERSION}.tar.gz/download | tar -xzf - && \
    cd boost_${BOOST_VERSION} && \
    ./bootstrap.sh --prefix=/usr/local/boost-${BOOST_DOTTED_VERSION} --with-libraries=filesystem,system,test,python  && \
    ./b2 -d0 -j"$(nproc)" install  && \
    rm -rf /boost_${BOOST_VERSION}

# Install Protobuf
RUN PROTOBUF_VERSION=3.1.0 \
    PROTOBUF_STRING=protobuf-$PROTOBUF_VERSION && \
    wget -O - --no-verbose https://github.com/google/protobuf/archive/v${PROTOBUF_VERSION}.tar.gz | tar -xzf - && \
    cd $PROTOBUF_STRING && \
    ./autogen.sh && \
    ./configure CFLAGS=-fPIC CXXFLAGS=-fPIC --disable-shared --prefix=/usr/local/$PROTOBUF_STRING && \
    make -j $(nproc) install && \
    cd .. && \
    rm -rf $PROTOBUF_STRING

# Install CNTK custom MKL
RUN CNTK_CUSTOM_MKL_VERSION=3 && \
    mkdir /usr/local/CNTKCustomMKL && \
    wget --no-verbose -O - https://www.cntk.ai/mkl/CNTKCustomMKL-Linux-$CNTK_CUSTOM_MKL_VERSION.tgz | \
    tar -xzf - -C /usr/local/CNTKCustomMKL

# Install Kaldi
ENV KALDI_VERSION=c024e8aa
ENV KALDI_PATH /usr/local/kaldi-$KALDI_VERSION

RUN mv /bin/sh /bin/sh.orig && \
   ln -s -f /bin/bash /bin/sh && \
   mkdir $KALDI_PATH && \
   wget --no-verbose -O - https://github.com/kaldi-asr/kaldi/archive/$KALDI_VERSION.tar.gz | tar -xzf - --strip-components=1 -C $KALDI_PATH && \
   cd $KALDI_PATH && \
   cd tools && \
   perl -pi -e 's/^# (OPENFST_VERSION = 1.4.1)$/\1/' Makefile && \
   ./extras/check_dependencies.sh && \
   make -j $(nproc) all && \
   cd ../src && \
   ./configure --openblas-root=/usr/local/openblas --shared && \
   make -j $(nproc) depend && \
   make -j $(nproc) all && \
# Remove some unneeded stuff in $KALDI_PATH to reduce size
   find $KALDI_PATH -name '*.o' -print0 | xargs -0 rm && \
   for dir in $KALDI_PATH/src/*bin; do make -C $dir clean; done && \
   mv -f /bin/sh.orig /bin/sh

WORKDIR /cntk

# Build CNTK
RUN git clone --depth=1 -b master https://github.com/Microsoft/CNTK.git . && \
    CONFIGURE_OPTS="\
      --with-kaldi=${KALDI_PATH} \
      --with-py27-path=/root/anaconda2/envs/cntk-py27" && \
    git submodule update --init Source/Multiverso && \
    mkdir -p build/cpu/release && \
    cd build/cpu/release && \
    ../../../configure $CONFIGURE_OPTS --with-openblas=/usr/local/openblas && \
    make -j"$(nproc)" all && \
    cd ../../.. && \
    mkdir -p build-mkl/cpu/release && \
    cd build-mkl/cpu/release && \
    ../../../configure $CONFIGURE_OPTS --with-mkl=/usr/local/CNTKCustomMKL && \
    make -j"$(nproc)" all

#RUN cd Examples/Image/DataSets/CIFAR-10 && \
#    python install_cifar10.py && \
#    cd ../../../..
#
#RUN cd Examples/Image/DataSets/MNIST && \
#    python install_mnist.py && \
#    cd ../../../..

ENV PATH=/cntk/build/cpu/release/bin:$PATH PYTHONPATH=/cntk/bindings/python LD_LIBRARY_PATH=/cntk/bindings/python/cntk/libs:$LD_LIBRARY_PATH

# Install mysql
RUN apt-get update && apt-get install -y libmysqlclient-dev

RUN python -m cntk.sample_installer

# Install OpenCV3
RUN sudo apt-get install -y pkg-config
RUN sudo apt-get install -y libjpeg8-dev libtiff4-dev libjasper-dev libpng12-dev
RUN sudo apt-get install -y libavcodec-dev libavformat-dev libswscale-dev libv4l-dev
RUN sudo apt-get install -y libgtk2.0-dev
RUN sudo apt-get install -y libatlas-base-dev gfortran
RUN conda install --name cntk-py27 opencv

# Install MKL for python
RUN conda install --name cntk-py27 nomkl

# Add precompiled bbox and nms binaries

# Set env vars to find Boost during installs
ENV BOOST_ROOT=/usr/local/boost-1.60.0
ENV BOOST_LIBRARYDIR=/usr/local/boost-1.60.0/lib
ENV BOOST_INCLUDEDIR=/usr/local/boost-1.60.0/include
ENV PATH=$BOOST_INCLUDEDIR:$BOOST_ROOT:$BOOST_LIBRARYDIR:$PATH
ENV LD_LIBRARY_PATH=$BOOST_LIBRARYDIR:$LD_LIBRARY_PATH

# Install vision-service pip dependencies
ADD requirements.txt requirements.txt
RUN pip install -r requirements.txt

WORKDIR /var

# Add symbolic link to CNTK python bindings
RUN echo "/cntk/bindings/python/" > /root/anaconda2/envs/cntk-py27/lib/python2.7/site-packages/cntkBindings.pth

# Install python-core, IF it's changed on GitHub
ADD https://api.github.com/repos/torchbearerio/python-core/git/refs/heads/master version.json
RUN pip install git+https://github.com/torchbearerio/python-core.git --upgrade

ADD visionservice app

#ENTRYPOINT [ "/bin/bash" ]
CMD [ "python", "-m", "/var/app" ]
