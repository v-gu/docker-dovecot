#!/usr/bin/env bash

# init vars
DOVECOT_DIR="${DOVECOT_DIR:-${ROOT_DIR}/dovecot}"

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


# generate config
cat <<EOF > ${DOVECOT_DIR}/dovecot.conf
base_dir = ${DOVECOT_DIR}
protocols = lmtp imaps

mail_home=${DOVECOT_MAIL_HOME}
mail_location=${DOVECOT_MAIL_LOCATION}

# Disable SSL for now.
ssl = no
disable_plaintext_auth = no

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
      address = ${DOVECOT_LMTP_LISTEN_ADDR} 127.0.0.1 ::1
      port = ${DOVECOT_LMTP_LISTEN_PORT}
   }

   unixlistener /var/spool/postfix/private/dovecot-lmtp {
       # postfix uid=100 gid=101
       group = 101
       mode = 0600 user = 100
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
auth_verbose = yes
# Outlook and Windows Mail works only with LOGIN mechanism, not the standard PLAIN:
auth_mechanisms = plain login
EOF

if [[ -n "${DOVECOT_PASSWORD_FILE_CONTENTS}" ]]; then
    echo -e "${DOVECOT_PASSWORD_FILE_CONTENTS}" > ${DOVECOT_DIR}/passwords
    cat <<EOF >> ${DOVECOT_DIR}/dovecot.conf
passdb {
  driver = passwd-file
  args = scheme=sha512-crypt ${DOVECOT_DIR}/passwords

}
EOF
    if [[ "${DOVECOT_USERDB_USE_PASSWORD_FILE}" == "true" || "${DOVECOT_USERDB_USE_PASSWORD_FILE}" == "yes" ]]; then
        cat <<EOF >> ${DOVECOT_DIR}/dovecot.conf
usredb {
  driver = passwd-file
  args = ${DOVECOT_DIR}/passwords
  default_fields = uid=vmail gid=vmail
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
  override_fields = uid=vmail gid=vmail
}
EOF
fi

rm -rf /etc/dovecot
ln -s "${DOVECOT_DIR}" /etc/dovecot
cd "${DOVECOT_DIR}"

exec dovecot -F -c "${DOVECOT_DIR}/dovecot.conf"