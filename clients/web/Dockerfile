FROM node:24.18.0-alpine AS build
WORKDIR /app/clients/web
ARG VITE_RNNOISE_ENABLED=true
ARG VITE_PUBLIC_ORIGIN
ARG SOURCE_REVISION=unknown
ENV VITE_RNNOISE_ENABLED=${VITE_RNNOISE_ENABLED}
ENV VITE_PUBLIC_ORIGIN=${VITE_PUBLIC_ORIGIN}
ENV SOURCE_REVISION=${SOURCE_REVISION}
COPY clients/web/package.json clients/web/package-lock.json ./
RUN npm ci
COPY clients/web/index.html clients/web/tsconfig.json clients/web/vite.config.ts ./
COPY clients/web/src ./src
COPY clients/web/public ./public
COPY contracts/client-build.json /app/contracts/client-build.json
RUN npm run build

FROM nginx:1.27.4-alpine
COPY clients/web/nginx.conf /etc/nginx/conf.d/default.conf
COPY --from=build /app/clients/web/dist /usr/share/nginx/html
EXPOSE 80
