#!/bin/bash
# Создаёт самоподписанный сертификат для подписи релизов в GitHub Actions — без платного аккаунта Apple.
#
# Зачем: без сертификата каждая сборка подписана ad-hoc, у каждой версии своя «личность», и после
# обновления macOS заново спрашивает «Универсальный доступ» и «Мониторинг ввода». Когда все версии
# подписаны одним сертификатом, выданные доступы переживают обновления.
# Предупреждение Gatekeeper при первом запуске это не убирает — для этого нужна нотаризация Apple.
#
# Сертификат создаётся один раз. Храните папку с ним в надёжном месте: новый сертификат — это снова
# «новое приложение» для macOS, и пользователям придётся выдать доступы ещё раз.
set -euo pipefail

NAME="${CATGRAB_RELEASE_IDENTITY_NAME:-CatGrab Release Signing}"
OUT_DIR="${1:-${HOME}/CatGrab-release-signing}"
DAYS=7300

if [ -e "${OUT_DIR}/certificate.p12" ]; then
  echo "${OUT_DIR}/certificate.p12 already exists — reuse it instead of creating a new identity."
  exit 1
fi
mkdir -p "${OUT_DIR}"
chmod 700 "${OUT_DIR}"

TMP="$(mktemp -d)"
trap 'rm -rf "${TMP}"' EXIT

cat > "${TMP}/openssl.cnf" <<EOF
[req]
distinguished_name = dn
x509_extensions = codesign
prompt = no
[dn]
CN = ${NAME}
[codesign]
keyUsage = critical, digitalSignature
extendedKeyUsage = critical, codeSigning
basicConstraints = critical, CA:false
subjectKeyIdentifier = hash
EOF

# Системный LibreSSL: `security import` на раннере не понимает PKCS#12 от OpenSSL 3 без -legacy.
/usr/bin/openssl req -x509 -newkey rsa:2048 -nodes -days "${DAYS}" \
  -config "${TMP}/openssl.cnf" -keyout "${TMP}/key.pem" -out "${TMP}/cert.pem" >/dev/null 2>&1

PASSWORD="$(/usr/bin/openssl rand -hex 16)"
/usr/bin/openssl pkcs12 -export -inkey "${TMP}/key.pem" -in "${TMP}/cert.pem" \
  -out "${OUT_DIR}/certificate.p12" -passout "pass:${PASSWORD}"
printf '%s\n' "${PASSWORD}" > "${OUT_DIR}/password.txt"
chmod 600 "${OUT_DIR}/certificate.p12" "${OUT_DIR}/password.txt"

base64 -i "${OUT_DIR}/certificate.p12" | tr -d '\n' | pbcopy

cat <<EOF

Created ${OUT_DIR}/certificate.p12 (password in password.txt). Keep this folder private and backed up.

Add three secrets in GitHub → your repository → Settings → Secrets and variables → Actions:

  SIGNING_CERTIFICATE_P12_BASE64   already copied to the clipboard — just paste it
  SIGNING_CERTIFICATE_PASSWORD     ${PASSWORD}
  SIGNING_IDENTITY                 ${NAME}

The next release tag is signed with it automatically.
EOF
