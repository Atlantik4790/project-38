# =========================================================
# Frontend Web App - Dockerfile
# Stack: Node.js + Express + request (per README frontend-tier code)
# =========================================================
 
# ---------- Stage 1: dependency build ----------
FROM node:24-alpine AS build
 
WORKDIR /usr/src/app
 
COPY package*.json ./
 
RUN npm install --omit=dev
 
COPY . .
 
# ---------- Stage 2: production runtime ----------
FROM node:24-alpine
 
WORKDIR /usr/src/app
 
ENV NODE_ENV=production
 
COPY --from=build /usr/src/app ./
 
# Frontend listens on port 3000 (hardcoded in index.js per README)
EXPOSE 3000
 
# API_URL is required at runtime, e.g.:
#   http://api:3001/data
ENV API_URL=""
 
USER node
 
CMD ["node", "index.js"]
