EXTENSION = pg_ical
DATA = pg_ical--1.0.0.sql
MODULE_big = pg_ical
OBJS = pg_ical.o

# libical flags
PG_CPPFLAGS = $(shell pkg-config --cflags libical)
SHLIB_LINK = $(shell pkg-config --libs libical)

# PostgreSQL build system
PG_CONFIG = pg_config
PGXS := $(shell $(PG_CONFIG) --pgxs)
include $(PGXS)
