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
ENV DOVECOT_IMAP_LISTEN_PORT            143
ENV DOVECOT_IMAPS_LISTEN_PORT           993
ENV DOVECOT_POP3_LISTEN_PORT            110
ENV DOVECOT_POP3S_LISTEN_PORT           995
ENV DOVECOT_AUTH_LISTEN_PORT            11000

# static since it has volume attached
ENV DOVECOT_MAIL_STORAGE_LOCATION       "${ROOT_DIR}/vmail"

ENV DOVECOT_MAIL_STORAGE_FORMAT         sdbox
ENV DOVECOT_PASSWORD_FILE_SCHEME        "sha512-crypt"
ENV DOVECOT_PASSWORD_FILE_CONTENTS      ""
ENV DOVECOT_USERDB_USE_PASSWORD_FILE    "yes"
ENV DOVECOT_USERDB_DEFAULT_UID          "nobody"
ENV DOVECOT_USERDB_DEFAULT_GID          "nobody"

ENV DOVECOT_ENABLED_PROTOCOLS           "lmtp imap"

ENV DOVECOT_ENABLE_AUTH                 "yes"
ENV DOVECOT_AUTH_VERBOSE                "no"
ENV DOVECOT_AUTH_MECHANISMS             "plain login"
ENV DOVECOT_AUTH_DISABLE_PLAINTEXT      "yes"
ENV DOVECOT_MANDATORY_SSL               "no"
ENV DOVECOT_SSL_CERT_FILE               "${ROOT_DIR}/tls/dovecot.cert"
ENV DOVECOT_SSL_KEY_FILE                "${ROOT_DIR}/tls/dovecot.key"

# define service ports
EXPOSE $DOVECOT_LMTP_LISTEN_PORT/tcp \
       $DOVECOT_IMAP_LISTEN_PORT/tcp \
       $DOVECOT_IMAPS_LISTEN_PORT/tcp \
       $DOVECOT_POP3_LISTEN_PORT/tcp \
       $DOVECOT_POP3S_LISTEN_PORT/tcp \
       $DOVECOT_AUTH_LISTEN_PORT/tcp

# install software stack
RUN set -ex && \
    DEP='dovecot dovecot-lmtpd dovecot-pop3d' && \
    apk add --update --no-cache $DEP && \
    rm -rf /var/cache/apk/*

VOLUME "${DOVECOT_DIR}"
VOLUME "${DOVECOT_MAIL_STORAGE_LOCATION}"
