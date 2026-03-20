FROM node:20-alpine

WORKDIR /app

# Install build deps for native modules (sharp)
RUN apk add --no-cache python3 make g++ vips-dev

COPY package*.json ./
RUN npm install --only=production

COPY src/ ./src/

# Create upload and log directories
RUN mkdir -p uploads/{photos,logos,documents,attachments,temp} logs

EXPOSE 3001

HEALTHCHECK --interval=15s --timeout=10s --retries=3 \
  CMD wget -qO /dev/null http://localhost:3001/idmgmt/api/health || exit 1

CMD ["node", "src/index.js"]
