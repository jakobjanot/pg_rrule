# Multi-stage build for pg_ical PostgreSQL extension
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
COPY Makefile pg_ical.c pg_ical.control pg_ical--1.0.0.sql ./

# Build extension
RUN make

# Final image
FROM postgres:16

# Install runtime dependencies
RUN apt-get update && apt-get install -y \
    libical3 \
    && rm -rf /var/lib/apt/lists/*

# Copy built extension from builder
COPY --from=builder /build/pg_ical.so /usr/lib/postgresql/16/lib/
COPY --from=builder /build/pg_ical.control /usr/share/postgresql/16/extension/
COPY --from=builder /build/pg_ical--1.0.0.sql /usr/share/postgresql/16/extension/

# Copy test file for easy access
COPY test.sql /docker-entrypoint-initdb.d/

# Labels for GitHub Container Registry
LABEL org.opencontainers.image.source=https://github.com/jakobjanot/pg_ical
LABEL org.opencontainers.image.description="PostgreSQL extension for iCalendar RRULE support"
LABEL org.opencontainers.image.licenses=MIT
