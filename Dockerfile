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
        cpio yum-utils zip unzip less \
        https://dl.fedoraproject.org/pub/epel/epel-release-latest-7.noarch.rpm && \
    yum install -y python3-pip && \
    yum clean all

# This had --no-cache-dir, tracing through multiple tickets led to a problem in wheel
RUN python3 -m pip install -r requirements.txt && rm -rf /root/.cache/pip

# Download libraries we need to run in lambda
WORKDIR /tmp
RUN set -o pipefail && \
    yumdownloader -x \*i686 --archlist=x86_64 \
        clamav clamav-lib clamav-update json-c pcre2 libtool-ltdl && \
    find . -name '*.rpm' -exec bash -c "rpm2cpio {} | cpio -idmv" \;

# Copy over the binaries and libraries
RUN cp /tmp/usr/bin/clamscan /tmp/usr/bin/freshclam /tmp/usr/lib64/*.so.? /opt/app/bin/
WORKDIR /opt/app/bin
RUN cp $(LD_LIBRARY_PATH=. ldd clamscan | cut -d' ' -f3 | grep lib64 | grep -v libc\.so) .
RUN cp $(LD_LIBRARY_PATH=. ldd freshclam | cut -d' ' -f3 | grep lib64 | grep -v libc\.so) .

WORKDIR /opt/app
# Fix the freshclam.conf settings
RUN echo "DatabaseMirror database.clamav.net" > /opt/app/bin/freshclam.conf && \
    echo "CompressLocalDatabase yes" >> /opt/app/bin/freshclam.conf

# Create the zip file
WORKDIR /opt/app
RUN zip -r9 --exclude="*test*" /opt/app/build/lambda.zip ./*.py bin

WORKDIR /usr/local/lib/python3.7/site-packages
RUN zip -r9 /opt/app/build/lambda.zip ./*

WORKDIR /opt/app
