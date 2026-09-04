FROM node:24-alpine AS base

WORKDIR /usr/src/app


# Backend image
FROM base AS backend

COPY backend/package*.json ./
RUN npm ci --omit=dev

COPY backend/ .

USER node

EXPOSE 3001

CMD ["node", "index.js"]


# Frontend image
FROM base AS frontend

COPY frontend/package*.json ./
RUN npm ci --omit=dev

COPY frontend/ .

USER node

EXPOSE 3000

CMD ["node", "index.js"]
