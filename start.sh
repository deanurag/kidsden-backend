#!/bin/sh

# Start script to run both Node.js applications

echo "Starting both backend services..."

# Start backend service in background
echo "Starting backend service on port 3000..."
cd /app/backend
PORT=3000 npm start &
BACKEND_PID=$!

# Start chatbackend service in background
echo "Starting chatbackend service on port 8000..."
cd /app/chatbackend
PORT=8000 npm start &
CHATBACKEND_PID=$!

# Function to handle shutdown gracefully
cleanup() {
    echo "Shutting down services..."
    kill $BACKEND_PID $CHATBACKEND_PID 2>/dev/null
    wait $BACKEND_PID $CHATBACKEND_PID 2>/dev/null
    echo "Services stopped."
    exit 0
}

# Trap signals for graceful shutdown
trap cleanup SIGTERM SIGINT

# Wait for both processes to complete
wait $BACKEND_PID $CHATBACKEND_PID