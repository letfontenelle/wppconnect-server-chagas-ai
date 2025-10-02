# ---- deps (dev) ----
    FROM node:20-alpine AS deps
    WORKDIR /app
    ENV PUPPETEER_SKIP_CHROMIUM_DOWNLOAD=true
    # dependências nativas para build do sharp
    RUN apk add --no-cache libc6-compat python3 make g++ vips-dev fftw-dev
    COPY package.json yarn.lock* package-lock.json* ./
    # Instala TODAS as deps (inclui typescript, tsc) para build
    RUN if [ -f yarn.lock ]; then yarn install --frozen-lockfile; else npm ci; fi
    
    # ---- build ----
    FROM node:20-alpine AS build
    WORKDIR /app
    ENV PUPPETEER_SKIP_CHROMIUM_DOWNLOAD=true
    COPY --from=deps /app/node_modules ./node_modules
    COPY . .
    # compila TS -> dist
    RUN if [ -f yarn.lock ]; then yarn build; else npm run build; fi
    
    # ---- runtime ----
    FROM node:20-alpine AS runner
    WORKDIR /app
    ENV NODE_ENV=production \
        PUPPETEER_SKIP_CHROMIUM_DOWNLOAD=true \
        PUPPETEER_EXECUTABLE_PATH=/usr/bin/chromium-browser
    # Chromium e dependências do puppeteer + vips p/ sharp em runtime
    RUN apk add --no-cache chromium nss freetype harfbuzz ca-certificates ttf-freefont vips
    COPY --from=build /app ./
    # (Opcional) crie diretórios persistentes; no Railway mapearemos volume
    RUN mkdir -p /app/userDataDir /app/wppconnect_tokens
    EXPOSE 21465
    # Usa PORT do Railway se fornecida
    CMD ["node","dist/server.js"]    
