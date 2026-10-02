FROM node:24.18.0-alpine AS build
WORKDIR /app
ARG VITE_RNNOISE_ENABLED=true
ENV VITE_RNNOISE_ENABLED=${VITE_RNNOISE_ENABLED}
COPY package.json package-lock.json ./
RUN npm ci
COPY index.html tsconfig.json vite.config.ts ./
COPY src ./src
COPY public ./public
RUN npm run build

FROM nginx:1.27.4-alpine
COPY nginx.conf /etc/nginx/conf.d/default.conf
COPY --from=build /app/dist /usr/share/nginx/html
EXPOSE 80
