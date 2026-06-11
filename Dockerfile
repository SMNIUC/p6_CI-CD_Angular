# syntax=docker/dockerfile:1

# ---- Build stage ----
# Compile the Angular app into static files
FROM node:22-alpine AS build
WORKDIR /app

# Install dependencies first to leverage Docker layer caching
COPY package.json package-lock.json ./
RUN npm ci

# Build the production bundle
COPY . .
RUN npm run build

# ---- Runtime stage ----
# Serve the static files with nginx
FROM nginx:1.27-alpine

# Use the project's nginx configuration (serves from /app on port 80)
COPY nginx/nginx.conf /etc/nginx/nginx.conf

# Copy the compiled Angular app
COPY --from=build /app/dist/olympic-games-starter/browser /app

EXPOSE 80

CMD ["nginx", "-g", "daemon off;"]
