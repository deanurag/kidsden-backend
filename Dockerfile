# Multi-stage Dockerfile for both backend and chatbackend Node.js applications
FROM node:18 AS base

# Create app directories
WORKDIR /app

# Create directories for both applications
RUN mkdir -p /app/backend /app/chatbackend

# Copy package.json files first for better Docker layer caching
COPY backend/package*.json /app/backend/
COPY chatbackend/package*.json /app/chatbackend/

# Install dependencies for backend
WORKDIR /app/backend
RUN npm ci --only=production

# Install dependencies for chatbackend
WORKDIR /app/chatbackend
RUN npm ci --only=production

# Copy application source code
COPY backend/ /app/backend/
COPY chatbackend/ /app/chatbackend/

# Create a startup script to run both applications
WORKDIR /app
COPY start.sh /app/start.sh
# Fix line endings and make executable
RUN sed -i 's/\r$//' /app/start.sh && chmod +x /app/start.sh

# Expose ports for both applications
# Backend typically runs on 3000, chatbackend on 8000
EXPOSE 3000 8000

# Use the startup script to run both applications
CMD ["/app/start.sh"]