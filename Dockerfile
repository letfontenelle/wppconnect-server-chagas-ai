# ---- deps (instala dev deps e yarn clássico) ----
    FROM node:22-bookworm-slim AS deps
    WORKDIR /app
    
    ENV NODE_ENV=development \
        PUPPETEER_SKIP_CHROMIUM_DOWNLOAD=true
    
    # toolchain mínima + yarn clássico
    RUN apt-get update && apt-get install -y --no-install-recommends \
          python3 make g++ ca-certificates git \
      && npm i -g yarn@1.22.22 \
      && rm -rf /var/lib/apt/lists/*
    
    # Copiamos só o necessário para instalar deps
    COPY package.json ./
    # Se existir yarn.lock, ele será usado; se não existir, yarn vai resolver deps normalmente
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
        # no Debian 'chromium' instala /usr/bin/chromium
        PUPPETEER_EXECUTABLE_PATH=/usr/bin/chromium
    
    # Chromium e fontes
    RUN apt-get update && apt-get install -y --no-install-recommends \
          chromium fonts-liberation ttf-dejavu \
      && rm -rf /var/lib/apt/lists/*
    
    # App pronto para rodar
    COPY --from=build /app ./
    
    # Pastas para persistência (mapear volume no Railway em /data)
    RUN mkdir -p /data/userDataDir /data/wppconnect_tokens
    
    # Sugestão de envs no Railway
    
    
