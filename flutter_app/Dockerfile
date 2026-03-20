# ============================================================
# Multi-stage Flutter Web build
# Stage 1: Build Flutter web with base-href /idmgmt/
# Stage 2: Serve with nginx
# ============================================================

# Stage 1 — Flutter Build
FROM ghcr.io/cirruslabs/flutter:3.24.0 AS builder

# Declare build args (passed from docker-compose build.args)
ARG FIREBASE_API_KEY
ARG FIREBASE_APP_ID
ARG FIREBASE_MESSAGING_ID
ARG FIREBASE_PROJECT_ID
ARG FIREBASE_AUTH_DOMAIN
ARG FIREBASE_STORAGE_BUCKET
ARG GOOGLE_WEB_CLIENT_ID

WORKDIR /app

# Copy pubspec first for layer caching
COPY pubspec.yaml pubspec.lock* ./
RUN flutter pub get

# Copy source
COPY . .

# Create placeholder assets to prevent build errors
RUN mkdir -p assets/images assets/animations assets/icons

# Build for web with /idmgmt/ base href
RUN flutter build web \
    --release \
    --base-href /idmgmt/ \
    --dart-define=FIREBASE_API_KEY=${FIREBASE_API_KEY} \
    --dart-define=FIREBASE_APP_ID=${FIREBASE_APP_ID} \
    --dart-define=FIREBASE_MESSAGING_ID=${FIREBASE_MESSAGING_ID} \
    --dart-define=FIREBASE_PROJECT_ID=${FIREBASE_PROJECT_ID} \
    --dart-define=FIREBASE_AUTH_DOMAIN=${FIREBASE_AUTH_DOMAIN} \
    --dart-define=FIREBASE_STORAGE_BUCKET=${FIREBASE_STORAGE_BUCKET} \
    --dart-define=GOOGLE_WEB_CLIENT_ID=${GOOGLE_WEB_CLIENT_ID} \
    --web-renderer canvaskit

# Stage 2 — Serve with nginx
FROM nginx:1.25-alpine

# Copy built Flutter web
COPY --from=builder /app/build/web /usr/share/nginx/html/idmgmt

# Nginx config for SPA routing under /idmgmt
COPY nginx.conf /etc/nginx/conf.d/default.conf

EXPOSE 80

CMD ["nginx", "-g", "daemon off;"]
