# ---- deps (instala dev deps e yarn clássico) ----
    FROM node:22-bookworm-slim AS deps
    WORKDIR /app
    
    ENV NODE_ENV=development \
        PUPPETEER_SKIP_CHROMIUM_DOWNLOAD=true
    
    # toolchain mínima + yarn 1.x
    RUN apt-get update && apt-get install -y --no-install-recommends \
          python3 make g++ ca-certificates git \
      && npm i -g yarn@1.22.22 \
      && rm -rf /var/lib/apt/lists/*
    
    # Copiamos só o necessário para instalar deps
    COPY package.json ./
    # Se existir yarn.lock, ele será usado; se não existir, yarn resolve deps normalmente
    COPY yarn.lock* ./
    
    RUN yarn install --frozen-lockfile || yarn install
    
    # ---- build (compila TS -> dist) ----
    FROM node:22-bookworm-slim AS build
    WORKDIR /app
    ENV PUPPETEER_SKIP_CHROMIUM_DOWNLOAD=true
    
    COPY --from=deps /app/node_modules ./node_modules
    COPY . .
    RUN yarn build
    
    # ---- runtime (produção) ----
    FROM node:22-bookworm-slim AS runner
    WORKDIR /app
    
    ENV NODE_ENV=production \
        PUPPETEER_SKIP_CHROMIUM_DOWNLOAD=true \
        # No Debian, o binário instalado pelo pacote 'chromium' é /usr/bin/chromium
        PUPPETEER_EXECUTABLE_PATH=/usr/bin/chromium
    
    # Chromium e fontes (DejaVu correto no Debian)
    RUN apt-get update && apt-get install -y --no-install-recommends \
          chromium fonts-liberation fonts-dejavu-core \
      && rm -rf /var/lib/apt/lists/*
    
    # App pronto para rodar
    COPY --from=build /app ./
    
    # Pastas para persistência (mapeie um volume do Railway em /data)
    RUN mkdir -p /data/userDataDir /data/wppconnect_tokens
    
    # Recomendações de ENV no Railway:
    # SECRET_KEY, PUBLIC_URL=https://SEU-APP.up.railway.app, PORT=21465,
    # USER_DATA_DIR=/data/userDataDir, TOKEN_STORE=file
    EXPOSE 21465
    CMD ["node", "dist/server.js"]    
    
    
