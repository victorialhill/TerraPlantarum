FROM python:3.13-slim AS build
COPY --from=ghcr.io/astral-sh/uv:0.11.1 /uv /bin/uv
ENV UV_COMPILE_BYTECODE=1 \
    UV_LINK_MODE=copy \
    UV_PYTHON_DOWNLOADS=never
WORKDIR /app

COPY ["pyproject.toml", "uv.lock", "./"]
RUN uv sync --locked --no-dev


FROM python:3.13-slim AS final
WORKDIR /app
COPY --from=build /app/.venv /app/.venv
ENV PATH="/app/.venv/bin:$PATH"
EXPOSE 3000
