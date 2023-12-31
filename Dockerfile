FROM node:18-slim as base

# To stop yarn install from over-logging.
ENV CI=1

RUN apt-get update || : && apt-get install -y \
    python3 \
    build-essential

RUN yarn cache clean

WORKDIR /app

COPY .yarn/releases .yarn/releases
COPY .yarnrc.yml .yarnrc.yml
COPY .yarn/plugins .yarn/plugins
COPY package.json package.json
COPY api/package.json api/package.json
COPY web/package.json web/package.json
COPY yarn.lock yarn.lock

RUN --mount=type=cache,target=/root/.yarn/berry/cache \
    --mount=type=cache,target=/root/.cache \
    yarn install --immutable --inline-builds

COPY redwood.toml .
COPY graphql.config.js .

# web build
# ------------------------------------------------
FROM base as web_build

COPY web web
RUN node_modules/.bin/redwood build web --no-prerender

# serve web
# ------------------------------------------------
FROM node:18-slim as serve_web

ENV CI=1 \
    NODE_ENV=production

WORKDIR /app

COPY .yarn/releases .yarn/releases
COPY .yarnrc.yml .yarnrc.yml
COPY .yarn/plugins .yarn/plugins
COPY web/package.json .
COPY yarn.lock yarn.lock

RUN --mount=type=cache,target=/root/.yarn/berry/cache \
    --mount=type=cache,target=/root/.cache \
    yarn workspaces focus web --production

COPY redwood.toml .
COPY graphql.config.js .

COPY --from=web_build /app/web/dist /app/web/dist

EXPOSE 8910

CMD ["node", "--conditions", "react-server", "./node_modules/@redwoodjs/vite/dist/runRscFeServer.js"]
