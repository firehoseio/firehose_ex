FROM msaraiva/elixir-dev:1.2.0

WORKDIR /app
ADD . /app
RUN mix deps.get

CMD mix run --no-halt
