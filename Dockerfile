FROM node:20-alpine AS base

# Install dependencies only when needed
FROM base AS deps
RUN apk add --no-cache libc6-compat
WORKDIR /app

# Copy package.json and pnpm-lock.yaml
COPY package.json pnpm-lock.yaml* ./

# Install dependencies
RUN corepack enable pnpm && pnpm i --frozen-lockfile

# Build stage
FROM base AS builder
WORKDIR /app
COPY --from=deps /app/node_modules ./node_modules
COPY . .

# Set all build-time variables
ARG DATABASE_URI
ENV DATABASE_URI=${DATABASE_URI}
ARG PAYLOAD_SECRET
ENV PAYLOAD_SECRET=${PAYLOAD_SECRET}
ARG NEXT_PRIVATE_DRAFT_SECRET
ENV NEXT_PRIVATE_DRAFT_SECRET=${NEXT_PRIVATE_DRAFT_SECRET}
ARG NEXT_PRIVATE_REVALIDATION_KEY
ENV NEXT_PRIVATE_REVALIDATION_KEY=${NEXT_PRIVATE_REVALIDATION_KEY}
ARG PAYLOAD_PUBLIC_DRAFT_SECRET
ENV PAYLOAD_PUBLIC_DRAFT_SECRET=${PAYLOAD_PUBLIC_DRAFT_SECRET}
ARG REVALIDATION_KEY
ENV REVALIDATION_KEY=${REVALIDATION_KEY}
ARG NEXT_PUBLIC_IS_LIVE
ENV NEXT_PUBLIC_IS_LIVE=${NEXT_PUBLIC_IS_LIVE}
ARG NEXT_PUBLIC_SERVER_URL
ENV NEXT_PUBLIC_SERVER_URL=${NEXT_PUBLIC_SERVER_URL}
ARG PAYLOAD_PUBLIC_SERVER_URL
ENV PAYLOAD_PUBLIC_SERVER_URL=${PAYLOAD_PUBLIC_SERVER_URL}
ENV PAYLOAD_CONFIG_PATH=src/payload.config.ts
ENV NEXT_TELEMETRY_DISABLED=1
ENV NODE_ENV=production
ENV NEXT_BUILD_STANDALONE=true

# Generate types and run the build
RUN corepack enable pnpm && \
    pnpm generate:types && \
    NODE_OPTIONS="--max_old_space_size=4096" pnpm run build

# Production image, copy all the files and run next
FROM base AS runner
WORKDIR /app

ENV NODE_ENV production
ENV NEXT_TELEMETRY_DISABLED 1

RUN addgroup --system --gid 1001 nodejs
RUN adduser --system --uid 1001 nextjs

COPY --from=builder /app/public ./public


# Set the correct permission for prerender cache
RUN mkdir .next
RUN chown nextjs:nodejs .next

# Copy necessary files
COPY --from=builder --chown=nextjs:nodejs /app/.next/standalone ./
COPY --from=builder --chown=nextjs:nodejs /app/.next/static ./.next/static

USER nextjs

EXPOSE 3000

ENV PORT 3000
ENV HOSTNAME "0.0.0.0"

CMD ["node", "server.js"]
