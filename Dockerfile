# ---- deps (instala dev deps p/ build do TS) ----
    FROM node:22-bookworm-slim AS deps
    WORKDIR /app
    
    # Evita baixar Chromium do puppeteer (vamos usar o do sistema)
    ENV PUPPETEER_SKIP_CHROMIUM_DOWNLOAD=true \
        NODE_ENV=development
    
    # Dependências nativas mínimas para eventuais builds
    RUN apt-get update && apt-get install -y --no-install-recommends \
        python3 make g++ ca-certificates git \
     && rm -rf /var/lib/apt/lists/*
    
    COPY package.json ./
    # Use o lock que você tiver. Dê preferência a um só (npm OU yarn). Exemplos:
    # COPY package-lock.json ./
    # RUN npm ci
    # --ou--
    # COPY yarn.lock ./
    # RUN corepack enable && yarn install --frozen-lockfile
    
    # Se você usa npm:
    COPY package-lock.json ./
    RUN npm ci
    
    # ---- build (compila TS -> dist) ----
    FROM node:22-bookworm-slim AS build
    WORKDIR /app
    ENV PUPPETEER_SKIP_CHROMIUM_DOWNLOAD=true
    COPY --from=deps /app/node_modules ./node_modules
    COPY . .
    # Se usa npm:
    RUN npm run build
    # Se usa yarn: RUN corepack enable && yarn build
    
    # ---- runtime (produção) ----
    FROM node:22-bookworm-slim AS runner
    WORKDIR /app
    
    ENV NODE_ENV=production \
        PUPPETEER_SKIP_CHROMIUM_DOWNLOAD=true \
        PUPPETEER_EXECUTABLE_PATH=/usr/bin/chromium
    
    # Chromium e fontes para o Whats/renderer
    RUN apt-get update && apt-get install -y --no-install-recommends \
        chromium fonts-liberation ttf-dejavu \
     && rm -rf /var/lib/apt/lists/*
    
    # Copia app pronto
    COPY --from=build /app ./
    
    # Pastas persistentes (mapeie volume no Railway)
    RUN mkdir -p /data/userDataDir /data/wppconnect_tokens
    
    # Variáveis recomendadas em runtime:
    # SECRET_KEY, PUBLIC_URL, PORT=21465, USER_DATA_DIR=/data/userDataDir, TOKEN_STORE=file
    EXPOSE 21465
    CMD ["node", "dist/server.js"]
    
