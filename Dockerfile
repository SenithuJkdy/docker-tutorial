# # Use official Node.js image
# FROM node:18

# # Set working directory inside the container
# WORKDIR /app

# # Copy package files and install dependencies
# COPY package*.json ./
# RUN npm install

# # Copy the rest of the app
# COPY . .

# # Expose port
# EXPOSE 2000

# # Start the app
# CMD ["npm", "start"]

# -----------------------------------
# Build stage
FROM node:18-alpine AS builder
WORKDIR /app
COPY . .
RUN npm install

# Runtime stage
FROM node:18-alpine
WORKDIR /app
COPY --from=builder /app .
CMD ["npm", "start"]
