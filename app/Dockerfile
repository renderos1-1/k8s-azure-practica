FROM node:22-alpine
WORKDIR /app
COPY package*.json ./
RUN npm install --omit=dev --no-audit --no-fund && npm cache clean --force
COPY src ./src
ENV NODE_ENV=production PORT=3000
USER node
EXPOSE 3000
CMD ["node", "src/server.js"]
