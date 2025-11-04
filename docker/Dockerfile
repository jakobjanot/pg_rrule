# Multi-stage build for pg_rrule PostgreSQL extension
FROM postgres:16 AS builder

# Install build dependencies
RUN apt-get update && apt-get install -y \
    build-essential \
    postgresql-server-dev-16 \
    libical-dev \
    pkg-config \
    && rm -rf /var/lib/apt/lists/*

# Copy source files
WORKDIR /build
COPY Makefile ./
COPY src/ ./src/
COPY sql/ ./sql/

# Build extension
RUN make

# Final image
FROM postgres:16

# Install runtime dependencies
RUN apt-get update && apt-get install -y \
    libical3 \
    && rm -rf /var/lib/apt/lists/*

# Copy built extension from builder
COPY --from=builder /build/pg_rrule.so /usr/lib/postgresql/16/lib/
COPY --from=builder /build/sql/pg_rrule.control /usr/share/postgresql/16/extension/
COPY --from=builder /build/sql/pg_rrule--1.0.0.sql /usr/share/postgresql/16/extension/

# Copy test file for easy access
COPY tests/test.sql /docker-entrypoint-initdb.d/

# Labels for GitHub Container Registry
LABEL org.opencontainers.image.source=https://github.com/jakobjanot/pg_rrule
LABEL org.opencontainers.image.description="PostgreSQL extension for iCalendar RRULE support"
LABEL org.opencontainers.image.licenses=MIT
