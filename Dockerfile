ARG ELIXIR_VERSION=1.18.3
ARG OTP_VERSION=27.3.4.8
ARG BUILD_DEBIAN_VERSION=bookworm-20260202-slim

FROM hexpm/elixir:${ELIXIR_VERSION}-erlang-${OTP_VERSION}-debian-${BUILD_DEBIAN_VERSION} AS build

ENV MIX_ENV=prod
ENV RUSTUP_HOME=/usr/local/rustup
ENV CARGO_HOME=/usr/local/cargo
ENV PATH=/usr/local/cargo/bin:${PATH}

RUN apt-get update && \
    apt-get install -y --no-install-recommends \
      build-essential \
      git \
      curl \
      ca-certificates && \
    curl https://sh.rustup.rs -sSf | sh -s -- -y --profile minimal --default-toolchain stable && \
    rm -rf /var/lib/apt/lists/*

WORKDIR /app

RUN mix local.hex --force && mix local.rebar --force

COPY mix.exs mix.lock ./
COPY config config
RUN mix deps.get --only $MIX_ENV
RUN mix deps.compile

COPY lib lib
COPY priv priv
COPY assets assets
COPY rel rel

RUN mix assets.deploy
RUN mix release

FROM debian:bookworm-slim AS app

RUN apt-get update && \
    apt-get install -y --no-install-recommends \
      ca-certificates \
      openssl \
      libstdc++6 \
      libncurses6 && \
    rm -rf /var/lib/apt/lists/*

WORKDIR /app

COPY --from=build /app/_build/prod/rel/vdr_demo ./

ENV HOME=/app \
    PHX_SERVER=true \
    PORT=4000

EXPOSE 4000

CMD ["bin/vdr_demo", "start"]
