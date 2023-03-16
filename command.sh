#!/usr/bin/env bash


CURL_VERSION=${CURL_VERSION:="curl-7.88.1"}
PYCURL_VERSION=${PYCURL_VERSION:="pycurl-7.45.2"}
BORINGSSL_COMMIT=${BORINGSSL_COMMIT:="28f96c2686459add7acedcd97cb841030bdda019"}
#
#echo "CURL_VERSION    : ${CURL_VERSION}"
#echo "PYCURL_VERSION  : ${PYCURL_VERSION}"
#echo "BORINGSSL_COMMIT: ${BORINGSSL_COMMIT}"
#
help(){
  echo "Usage:"
  echo "      sh command.sh command [args]"
  echo "         command  --- command to execute"
  echo ""
  echo "Commands: "
  echo "      deps           ---  install dependencies"
  echo "      build          ---  build project"
  echo "      help           ---  print help"
  echo "      build_pycurl   ---  print help"
  echo ""
  echo "Detail: "
  echo "      sh command.sh deps simple                   ---   install simple dependencies"
  echo "      sh command.sh deps full                     ---   install full dependencies"
  echo "      sh command.sh boringssl                     ---   build boringssl"
  echo "      sh command.sh build simple prefix  ssl_path ---   build curl with simple features and"
  echo "                                                        install prefix and ssl_path"
  echo "      sh command.sh pycurl curlpath sslpath       ---   build pycurl"
  echo "                                                        curl path and ssl path"
}


install_ubuntu_full(){
  sudo apt-get install -y autoconf gcc g++ libtool cmake curl ninja-build libzip-dev \
  pkg-config libunistring-dev libidn2-dev libpsl-dev libc-ares-dev libbrotli-dev \
  libzstd-dev libgsasl7-dev librtmp-dev libssh2-1-dev libldap2-dev libnghttp2-dev \
  libbrotli-dev
  python3 -m pip install -U pip wheel gyp-next setuptools
}

install_ubuntu_simple(){
  sudo apt-get install -y autoconf gcc g++ libtool cmake curl ninja-build libzip-dev \
  pkg-config libunistring-dev libnghttp2-dev libbrotli-dev
  python3 -m pip install -U pip wheel gyp-next setuptools
}


install_macosx_full(){
  brew install autoconf automake libtool cmake curl ninja \
  pkg-config libunistring zlib brotli zstd libidn2 libpsl \
  c-ares rtmpdump libssh2 nghttp2
  python3 -m pip install -U pip wheel gyp-next setuptools
}

install_macosx_simple(){
  brew install autoconf automake libtool cmake curl ninja zlib \
  pkg-config libunistring brotli nghttp2
  python3 -m pip install -U pip wheel gyp-next setuptools
}


install_ubuntu(){
  echo "Install dependencies on Ubuntu"
  case $1 in
  "simple")
    install_ubuntu_simple
    ;;
  "full")
    install_ubuntu_full
    ;;
  esac
}

build_boringssl(){
    if [[ ! -f boringssl.tar.gz ]];then
      curl -L "https://boringssl.googlesource.com/boringssl/+archive/${BORINGSSL_COMMIT}.tar.gz" \
          	-o boringssl.tar.gz
    fi
    mkdir -p boringssl/build
    tar xf boringssl.tar.gz -C boringssl
    pushd boringssl/build
    pwd
    cmake -DCMAKE_BUILD_TYPE=Release \
          -DCMAKE_POSITION_INDEPENDENT_CODE=on \
          -DCMAKE_C_FLAGS="-Wno-unknown-warning-option -Wno-stringop-overflow -Wno-array-bounds" \
          -GNinja ..
    ninja -j"$(nproc)"
    mkdir -p lib
    ln -sf ../crypto/libcrypto.a lib/libcrypto.a
    ln -sf ../ssl/libssl.a lib/libssl.a
    cp -Rf ../include .
    popd
}


install_macosx(){
  echo "Install dependencies on MacOS"
  case "$1" in
    "simple")
      install_macosx_simple
      ;;
    "full")
      install_macosx_full
      ;;
    esac
}

install_depends(){
  case $(uname) in
  "Darwin")
    install_macosx "${@:1}"
    ;;
  "Linux")
    install_ubuntu "${@}"
    ;;
  esac
}

build_simple(){
  echo "build simple in $(pwd) to ${1}"
  autoreconf -if
  ./configure --prefix="$1" --with-openssl="$2" --with-brotli \
  --with-pic --with-zlib --with-nghttp2 && \
  make -j"$(nproc)" && make install
}

build_full(){
  echo "build full in $(pwd) to ${1}"
  autoreconf -if
  ./configure --prefix="$1" --with-openssl="$2" --with-brotli --with-nghttp2 \
   --enable-cookies --with-libpsl --enable-ares --with-libidn2 --with-zstd \
   --with-zlib --with-pic --enable-alt-svc --enable-dnsshuffle --enable-tls-srp \
   --with-nghttp2 --enable-ntlm --enable-websockets --with-libssh2 --enable-ldap \
   --enable-ldaps --enable-sspi --enable-doh && \
  make -j"$(nproc)" && make install
}

build_curl(){
  echo "Building ${CURL_VERSION} with $1 features"
  [[ -f "${CURL_VERSION}/.patched" ]] || tar xf "${CURL_VERSION}".tar.xz
  pushd "${CURL_VERSION}" || (echo "pushd failed" && return)
  PATCH_FILE=../curl/"${CURL_VERSION}".patch
  [[ ! -f "${PATCH_FILE}" ]] && echo "${PATCH_FILE} not found" && return
  [[ ! -f .patched ]] && patch -p1 < "$PATCH_FILE" && touch .patched && echo "files patched"
  case "$1" in
  "simple")
    build_simple "${@:2}"
    ;;
  "full")
    build_full "${@:2}"
    ;;
  esac
  popd || (echo "popd failed" && return)
}

build_pycurl(){
  echo "Building ${PYCURL_VERSION}"
  [[ ! -f "${PYCURL_VERSION}".tar.gz ]] && echo "${PYCURL_VERSION}.tar.gz not found" && return
  [[ -f "${PYCURL_VERSION}/.patched" ]] || tar xf "${PYCURL_VERSION}".tar.gz
  pushd "${PYCURL_VERSION}" || (echo "pushd failed" && return)
  PATCH_FILE=../pycurl/"${PYCURL_VERSION}".patch
  [[ ! -f "${PATCH_FILE}" ]] && echo "${PATCH_FILE} not found" && return
  [[ ! -f .patched ]] && patch -p1 < "$PATCH_FILE" && touch .patched && echo "files patched"
  CFLAGS="-s" python3 setup.py bdist_wheel --curl-config="${1}/bin/curl-config" --openssl-dir="$2"
  popd || echo "popd failed" && return
}

test(){
  echo "${2}" "${1}" "$0"
}

case "$1" in
"deps")
  install_depends "${@:2}"
  ;;
"build")
  build_curl "${@:2}"
  ;;
"pycurl")
  build_pycurl "${@:2}"
  ;;
"boringssl")
  build_boringssl "${@:2}"
  ;;
"test")
  test "${@:2}"
  ;;
 *)
   help
  ;;
esac
