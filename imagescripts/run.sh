#!/usr/bin/env bash

# init vars
DOVECOT_DIR="${DOVECOT_DIR:-${ROOT_DIR}/dovecot}"

DOVECOT_DOMAINS="${DOVECOT_DOMAINS}"

DOVECOT_LISTEN="${DOVECOT_LISTEN:-0.0.0.0}"
DOVECOT_ENABLED_PROTOCOLS="${DOVECOT_ENABLED_PROTOCOLS:-lmtp imap pop3}"

DOVECOT_ENABLE_AUTH="${DOVECOT_ENABLE_AUTH:-yes}"
DOVECOT_AUTH_MECHANISMS="${DOVECOT_AUTH_MECHANISMS:-plain login}"
DOVECOT_AUTH_VERBOSE="${DOVECOT_AUTH_VERBOSE:-no}"
DOVECOT_AUTH_DISABLE_PLAINTEXT="${DOVECOT_AUTH_DISABLE_PLAINTEXT:-yes}"

DOVECOT_MAIL_STORAGE_LOCATION="${DOVECOT_MAIL_STORAGE_LOCATION:-${ROOT_DIR}/vmail}"
DOVECOT_MAIL_HOME="${DOVECOT_MAIL_STORAGE_LOCATION}/%d/%n"
if [[ "${DOVECOT_MAIL_STORAGE_FORMAT}" == "sdbox" ]]; then
    DOVECOT_MAIL_LOCATION="sdbox:~/dbox"
elif [[ "${DOVECOT_MAIL_STORAGE_FORMAT}" == "mdbox" ]]; then
    DOVECOT_MAIL_LOCATION="mdbox:~/mdbox"
elif [[ "${DOVECOT_MAIL_STORAGE_FORMAT}" == "maildir" ]]; then
    DOVECOT_MAIL_LOCATION="maildir:~/Maildir"
elif [[ "${DOVECOT_MAIL_STORAGE_FORMAT}" == "mbox" ]]; then
    DOVECOT_MAIL_LOCATION="mbox:~/mail:INBOX=${DOVECOT_MAIL_STORAGE_LOCATION}/%u"
else
    DOVECOT_MAIL_LOCATION="sdbox:~/dbox"
fi

DOVECOT_PASSWORD_FILE_SCHEME="${DOVECOT_PASSWORD_FILE_SCHEME:-sha512-crypt}"
DOVECOT_USERDB_DEFAULT_UID="${DOVECOT_USERDB_DEFAULT_UID:-nobody}"
DOVECOT_USERDB_DEFAULT_GID="${DOVECOT_USERDB_DEFAULT_GID:-nobody}"

DOVECOT_SSL_DIR="${DOVECOT_SSL_DIR:-${ROOT_DIR}/tls}"

# generate config
cat <<EOF > ${DOVECOT_DIR}/dovecot.conf
log_path=/dev/stdout
protocols = ${DOVECOT_ENABLED_PROTOCOLS}
listen = ${DOVECOT_LISTEN}

mail_home=${DOVECOT_MAIL_HOME}
mail_location=${DOVECOT_MAIL_LOCATION}
first_valid_uid=0
first_valid_gid=0
EOF

if [[ "${DOVECOT_MANDATORY_SSL}" == "true" || "${DOVECOT_MANDATORY_SSL}" == "yes" ]]; then
    cat <<EOF >> ${DOVECOT_DIR}/dovecot.conf

# SSL
ssl = required
disable_plaintext_auth = ${DOVECOT_AUTH_DISABLE_PLAINTEXT}
EOF

    default_ssl_assigned=false
    IFS=' ' read -ra domains <<< "${DOVECOT_DOMAINS}"
    for i in "${domains[@]}"; do
        if [ "${default_ssl_assigned}" == false ]; then
            cat <<EOF >> ${DOVECOT_DIR}/dovecot.conf
ssl_cert = <${DOVECOT_SSL_DIR}/${i}/${i}.crt
ssl_key = <${DOVECOT_SSL_DIR}/${i}/${i}.key
EOF
            default_ssl_assigned=true
        fi

        cat <<EOF >> ${DOVECOT_DIR}/dovecot.conf
local_name ${i} {
  ssl_cert = <${DOVECOT_SSL_DIR}/${i}/${i}.crt
  ssl_key = <${DOVECOT_SSL_DIR}/${i}/${i}.key
}
EOF
    done
else
    cat <<EOF >> ${DOVECOT_DIR}/dovecot.conf

# SSL
ssl = no
disable_plaintext_auth = ${DOVECOT_AUTH_DISABLE_PLAINTEXT}
EOF
fi

cat <<EOF >> ${DOVECOT_DIR}/dovecot.conf

# If you're using POP3, you'll need this:
pop3_uidl_format = %g

EOF

# service configurations:
cat <<EOF >> ${DOVECOT_DIR}/dovecot.conf

# Service configuration:
EOF

# service: lmtp
cat <<EOF >> ${DOVECOT_DIR}/dovecot.conf

service lmtp {
   inet_listener lmtp {
      address = ${DOVECOT_LMTP_LISTEN_ADDR}
      port = ${DOVECOT_LMTP_LISTEN_PORT}
   }
}
EOF

## service: auth
if [[ "${DOVECOT_ENABLE_AUTH}" == "true" || "${DOVECOT_ENABLE_AUTH}" == "yes" ]]; then
    cat <<EOF >> ${DOVECOT_DIR}/dovecot.conf

service auth {
    inet_listener {
        port = ${DOVECOT_AUTH_LISTEN_PORT}
    }
}
EOF
fi

# Authentication
cat <<EOF >> ${DOVECOT_DIR}/dovecot.conf

# Authentication configuration:
auth_verbose = ${DOVECOT_AUTH_VERBOSE}
# Outlook and Windows Mail works only with LOGIN mechanism, not the standard PLAIN:
auth_mechanisms = ${DOVECOT_AUTH_MECHANISMS}
EOF

if [[ -n "${DOVECOT_PASSWORD_FILE_CONTENTS}" ]]; then
    echo -e "${DOVECOT_PASSWORD_FILE_CONTENTS}" > ${DOVECOT_DIR}/passwords
    cat <<EOF >> ${DOVECOT_DIR}/dovecot.conf
passdb {
  driver = passwd-file
  args = scheme=${DOVECOT_PASSWORD_FILE_SCHEME} ${DOVECOT_DIR}/passwords

}
EOF
    if [[ "${DOVECOT_USERDB_USE_PASSWORD_FILE}" == "true" || "${DOVECOT_USERDB_USE_PASSWORD_FILE}" == "yes" ]]; then
        cat <<EOF >> ${DOVECOT_DIR}/dovecot.conf
userdb {
  driver = passwd-file
  args = ${DOVECOT_DIR}/passwords
  default_fields = uid=${DOVECOT_USERDB_DEFAULT_UID} gid=${DOVECOT_USERDB_DEFAULT_GID}
}
EOF
    fi
else
    cat <<EOF >> ${DOVECOT_DIR}/dovecot.conf
passdb {
  driver = pam
}
userdb {
  driver = passwd
  args = blocking=no
  default_fields = uid=${DOVECOT_USERDB_DEFAULT_UID} gid=${DOVECOT_USERDB_DEFAULT_GID}
}
EOF
fi

# mailbox settings
cat <<EOF >> ${DOVECOT_DIR}/dovecot.conf

namespace inbox {
  #prefix = INBOX. # the namespace prefix isn't added again to the mailbox names.
  inbox = yes
  # ...

  mailbox Trash {
    auto = subscribe
    special_use = \Trash
  }
  mailbox Drafts {
    auto = subscribe
    special_use = \Drafts
  }
  mailbox Sent {
    auto = subscribe # autocreate and autosubscribe the Sent mailbox
    special_use = \Sent
  }
  mailbox "Sent Messages" {
    auto = subscribe
    special_use = \Sent
  }
  mailbox Spam {
    auto = subscribe # autocreate Spam, but don't autosubscribe
    special_use = \Junk
  }
  mailbox virtual/All { # if you have a virtual "All messages" mailbox
    auto = no
    special_use = \All
  }
}
EOF

rm -rf /etc/dovecot
ln -s "${DOVECOT_DIR}" /etc/dovecot
cd "${DOVECOT_DIR}"
chown "${DOVECOT_USERDB_DEFAULT_UID}:${DOVECOT_USERDB_DEFAULT_GID}" "${DOVECOT_MAIL_STORAGE_LOCATION}"

exec dovecot -F -c "${DOVECOT_DIR}/dovecot.conf"
