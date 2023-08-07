FROM amazonlinux:2

# Set up working directories
RUN mkdir -p /opt/app/build && mkdir -p /opt/app/bin/

# Copy in the lambda source
WORKDIR /opt/app
COPY ./*.py /opt/app/
COPY requirements.txt /opt/app/requirements.txt

# Install packages
RUN yum update -y && \
    yum install -y \
        amazon-linux-extras \
        cpio yum-utils zip unzip less \
        https://dl.fedoraproject.org/pub/epel/epel-release-latest-7.noarch.rpm && \
    amazon-linux-extras enable python3.8 && \
    yum install -y python38-pip && \
    yum clean all

# This had --no-cache-dir, tracing through multiple tickets led to a problem in wheel
RUN python3.8 -m pip install -r requirements.txt && rm -rf /root/.cache/pip

# Download libraries we need to run in lambda
WORKDIR /tmp
RUN yumdownloader -x \*i686 --archlist=x86_64 \
    clamav clamav-lib clamav-update json-c pcre libxml2 xz-libs libcurl \
    libprelude gnutls libtasn1 lib64nettle nettle libtool-ltdl libnghttp2 \
    libidn2 libssh2 openldap libunistring cyrus-sasl-lib openssl-libs nss && \
    find . -name '*.rpm' -exec bash -c "rpm2cpio {} | cpio -idmv" \;

# Copy over the binaries and libraries
RUN cp -r /tmp/usr/bin/clamscan /tmp/usr/bin/freshclam /tmp/usr/lib64/* /opt/app/bin/

# Fix the freshclam.conf settings
RUN echo "DatabaseMirror database.clamav.net" > /opt/app/bin/freshclam.conf && \
    echo "CompressLocalDatabase yes" >> /opt/app/bin/freshclam.conf

# Create the zip file
WORKDIR /opt/app
RUN zip -r9 --exclude="*test*" /opt/app/build/lambda.zip ./*.py bin

WORKDIR /usr/local/lib/python3.8/site-packages
RUN zip -r9 /opt/app/build/lambda.zip ./*

WORKDIR /opt/app
