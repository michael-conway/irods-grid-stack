set -eu

mkdir -p /var/www/starbase/config

cat > /var/www/starbase/config/starbase.yaml <<EOF
Title: ${STARBASE_TITLE:-Starbase}
Subtitle: ${STARBASE_SUBTITLE:-iRODS Grid Stack}
RestAPIBaseURL: ${STARBASE_REST_API_BASE_URL:-http://127.0.0.1:8080}
S3AdminEnabled: ${STARBASE_S3_ADMIN_ENABLED:-true}

AuthMode:
  - Mode: native
    AuthName: iRODS native
  - Mode: pam
    AuthName: iRODS PAM
EOF

exec nginx -g "daemon off;"
