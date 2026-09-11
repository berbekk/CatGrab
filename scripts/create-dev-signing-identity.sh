#!/bin/bash
# Создаёт локальный самоподписанный сертификат для codesign.
# Зачем: ad-hoc подпись (`codesign -s -`) меняется при каждой сборке, и macOS сбрасывает
# выданный «Универсальный доступ». Со стабильным сертификатом права сохраняются между сборками.
# Сертификат живёт только в вашей связке ключей и не заменяет Developer ID для распространения.
set -euo pipefail

NAME="${PIEMENU_DEV_IDENTITY_NAME:-PieMenu Dev Signing}"
KEYCHAIN="${HOME}/Library/Keychains/login.keychain-db"
DAYS="${PIEMENU_DEV_IDENTITY_DAYS:-3650}"

if security find-identity -v -p codesigning | grep -q "\"${NAME}\""; then
  echo "Сертификат «${NAME}» уже есть. build.sh подхватит его автоматически."
  exit 0
fi

TMP="$(mktemp -d)"
trap 'rm -rf "${TMP}"' EXIT

# Системный LibreSSL: `security import` не понимает PKCS#12 от OpenSSL 3 без -legacy.
OPENSSL="/usr/bin/openssl"
PKCS12_EXTRA=()
if ! "${OPENSSL}" version >/dev/null 2>&1; then
  OPENSSL="openssl"
  if "${OPENSSL}" version | grep -q "^OpenSSL 3"; then
    PKCS12_EXTRA=(-legacy)
  fi
fi

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

"${OPENSSL}" req -x509 -newkey rsa:2048 -nodes -days "${DAYS}" \
  -config "${TMP}/openssl.cnf" \
  -keyout "${TMP}/key.pem" -out "${TMP}/cert.pem" >/dev/null 2>&1

P12_PASS="$("${OPENSSL}" rand -hex 16)"
"${OPENSSL}" pkcs12 -export ${PKCS12_EXTRA[@]+"${PKCS12_EXTRA[@]}"} \
  -inkey "${TMP}/key.pem" -in "${TMP}/cert.pem" \
  -out "${TMP}/identity.p12" -passout "pass:${P12_PASS}"

security import "${TMP}/identity.p12" -k "${KEYCHAIN}" -P "${P12_PASS}" \
  -T /usr/bin/codesign -T /usr/bin/security >/dev/null

echo "Сейчас macOS попросит пароль, чтобы доверять сертификату для подписи кода."
security add-trusted-cert -r trustRoot -p codeSign -k "${KEYCHAIN}" "${TMP}/cert.pem"

echo "Готово: «${NAME}». Пересоберите приложение: ./install.sh"
