set -eu

mkdir -p /var/www/starbase/config

: "${STARBASE_OIDC_ENDPOINT:=/web/login}"
: "${STARBASE_OIDC_AUTHORIZATION_ENDPOINT:=https://localhost:8443/realms/drs/protocol/openid-connect/auth}"
: "${STARBASE_OIDC_TOKEN_ENDPOINT:=https://localhost:8443/realms/drs/protocol/openid-connect/token}"
: "${STARBASE_OIDC_CLIENT_ID:=starbase-spa}"
: "${STARBASE_OIDC_SCOPE:=openid profile email}"
: "${STARBASE_OIDC_REDIRECT_PATH:=/auth/callback}"

cat > /var/www/starbase/config/starbase.yaml <<EOF
Title: ${STARBASE_TITLE:-Starbase}
Subtitle: ${STARBASE_SUBTITLE:-iRODS Grid Stack}
RestAPIBaseURL: ${STARBASE_REST_API_BASE_URL:-http://127.0.0.1:8080}
OIDCEndpoint: ${STARBASE_OIDC_ENDPOINT}
OIDCAuthorizationEndpoint: ${STARBASE_OIDC_AUTHORIZATION_ENDPOINT}
OIDCTokenEndpoint: ${STARBASE_OIDC_TOKEN_ENDPOINT}
OIDCClientID: ${STARBASE_OIDC_CLIENT_ID}
OIDCScope: ${STARBASE_OIDC_SCOPE}
OIDCRedirectPath: ${STARBASE_OIDC_REDIRECT_PATH}
S3AdminEnabled: ${STARBASE_S3_ADMIN_ENABLED:-true}

AuthMode:
  - Mode: native
    AuthName: iRODS native
  - Mode: pam
    AuthName: iRODS PAM
EOF

exec nginx -g "daemon off;"
