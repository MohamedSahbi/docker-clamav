FROM debian:stretch-slim
LABEL author="http://m-ko.de Markus Kosmal <dude@m-ko.de>"

# Debian Base to use
ENV DEBIAN_VERSION stretch
#ENV $HTTPProxyServer HTTPProxyServer
#ENV $HTTPProxyPort Port

# initial install of av daemon
RUN echo "deb http://deb.debian.org/debian/ $DEBIAN_VERSION main contrib non-free" > /etc/apt/sources.list && \
    echo "deb http://security.debian.org/ $DEBIAN_VERSION/updates main contrib non-free" >> /etc/apt/sources.list && \
    apt-get update && \
    DEBIAN_FRONTEND=noninteractive apt-get install --no-install-recommends -y -qq \
        clamav-daemon \
        clamav-freshclam \
        libclamunrar9 \
        ca-certificates \
        wget && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/*

# initial update of av databases
RUN wget -v -O /var/lib/clamav/main.cvd http://database.clamav.net/main.cvd && \
    wget -v -O /var/lib/clamav/daily.cvd http://database.clamav.net/daily.cvd && \
    wget -v -O /var/lib/clamav/bytecode.cvd http://database.clamav.net/bytecode.cvd && \
    chown clamav:clamav /var/lib/clamav/*

# permission juggling
RUN mkdir /var/run/clamav && \
    chown clamav:clamav /var/run/clamav && \
    chmod 750 /var/run/clamav

# av configuration update
RUN sed -i 's/^Foreground .*$/Foreground true/g' /etc/clamav/clamd.conf && \
    sed -i '/LocalSocketGroup/d' /etc/clamav/clamd.conf && \
    echo "TCPSocket 3310" >> /etc/clamav/clamd.conf && \ 
    echo "DatabaseDirectory /var/lib/clamav" >> /etc/clamav/clamd.conf && \
# By passing the proxy as a parameter in the docker build command,
# envconfig.sh updates clamd.conf and freshclam.conf (worked for me)
# If it didn't work, uncomment these lines and set the values in lines 6 and 7
    # if [ -n "$HTTPProxyServer" ]; then echo "HTTPProxyServer $HTTPProxyServer" >> /etc/clamav/freshclam.conf; fi && \
    # if [ -n "$HTTPProxyPort"   ]; then echo "HTTPProxyPort $HTTPProxyPort" >> /etc/clamav/freshclam.conf; fi && \
    if [ -n "$DatabaseMirror"  ]; then echo "DatabaseMirror $DatabaseMirror" >> /etc/clamav/freshclam.conf; fi && \
    if [ -n "$DatabaseMirror"  ]; then echo "ScriptedUpdates off" >> /etc/clamav/freshclam.conf; fi && \
    sed -i 's/^Foreground .*$/Foreground true/g' /etc/clamav/freshclam.conf
    
RUN chgrp -R root /var/log/clamav
RUN chmod -R g+w /var/log/clamav
RUN chgrp -R root /var/lib/clamav
RUN chmod -R g+w /var/lib/clamav
RUN chgrp -R root /run/clamav
RUN chmod -R g+w /run/clamav
RUN chgrp -R root /var/run/clamav
RUN chmod -R g+w /var/run/clamav

# env based configs - will be called by bootstrap.sh
COPY envconfig.sh /
COPY check.sh /
COPY bootstrap.sh /

# port provision
EXPOSE 3310

RUN chown clamav:clamav bootstrap.sh check.sh envconfig.sh /etc/clamav/clamd.conf /etc/clamav/freshclam.conf && \
    chmod u+x bootstrap.sh check.sh envconfig.sh    

USER clamav

CMD ["/bootstrap.sh"]
