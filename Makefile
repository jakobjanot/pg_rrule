EXTENSION = pg_rrule
DATA = sql/pg_rrule--1.0.0.sql
MODULE_big = pg_rrule
OBJS = src/pg_rrule.o

# PGXS expects control file in root - symlink handled externally
# Don't clean it
EXTRA_CLEAN =

# libical flags
PG_CPPFLAGS = $(shell pkg-config --cflags libical)
SHLIB_LINK = $(shell pkg-config --libs libical)

# PostgreSQL build system
PG_CONFIG = pg_config
PGXS := $(shell $(PG_CONFIG) --pgxs)
include $(PGXS)

# Disable LLVM bitcode generation (requires clang which may not be available)
%.bc:
	@echo "Skipping bitcode generation"
