# Stage 1: Build
FROM elixir:1.18 AS build

RUN apt-get update && apt-get install -y build-essential git nodejs npm \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /app

RUN mix local.hex --force && mix local.rebar --force

ENV MIX_ENV=prod

COPY mix.exs mix.lock ./
COPY config config
RUN mix deps.get --only prod
RUN mix deps.compile

# Install JS deps and build assets
COPY assets/package.json assets/
RUN npm install --prefix assets --omit=dev
COPY assets assets
COPY priv priv
RUN mix assets.deploy

COPY lib lib
RUN mix compile
RUN mix release

# Stage 2: Run
FROM elixir:1.18

WORKDIR /app

COPY --from=build /app/_build/prod/rel/supercollider_cubes ./

ENV PHX_SERVER=true

EXPOSE 4000

CMD ["bin/supercollider_cubes", "start"]
