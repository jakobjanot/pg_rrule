EXTENSION = pg_ical
DATA = sql/pg_ical--1.0.0.sql
MODULE_big = pg_ical
OBJS = src/pg_ical.o

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
