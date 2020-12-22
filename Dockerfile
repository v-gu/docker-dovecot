## -*- docker-image-name: lisnaz/dovecot -*-
#
# Dockerfile for dovecot
#
# need init: false

FROM lisnaz/alpine:latest
MAINTAINER Vincent Gu <v@vgu.io>

# static since it has volume attached
ENV DOVECOT_DIR                         "${ROOT_DIR}/dovecot"

ENV DOVECOT_LMTP_LISTEN_ADDR            "0.0.0.0"
ENV DOVECOT_LMTP_LISTEN_PORT            24
ENV DOVECOT_IMAP_LISTEN_PORT            24
ENV DOVECOT_POP3_LISTEN_PORT            24
ENV DOVECOT_AUTH_LISTEN_PORT            11000

# static since it has volume attached
ENV DOVECOT_MAIL_STORAGE_LOCATION       "${ROOT_DIR}/vmail"

ENV DOVECOT_MAIL_STORAGE_FORMAT         sdbox
ENV DOVECOT_PASSWORD_FILE_CONTENTS      ""
ENV DOVECOT_USERDB_USE_PASSWORD_FILE    "yes"

ENV DOVECOT_ENABLE_AUTH                 "yes"

# define service ports
EXPOSE $DOVECOT_LMTP_LISTEN_PORT/tcp

# install software stack
RUN set -ex && \
    DEP='dovecot dovecot-lmtpd dovecot-pop3d' && \
    apk add --update --no-cache $DEP && \
    rm -rf /var/cache/apk/*

VOLUME "${DOVECOT_DIR}"
VOLUME "${DOVECOT_MAIL_STORAGE_LOCATION}"
