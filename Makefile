EXTENSION = pg_ical
DATA = pg_ical--1.0.0.sql
MODULES = pg_ical

# PostgreSQL build system
PG_CONFIG = pg_config
PGXS := $(shell $(PG_CONFIG) --pgxs)

# libical flags
PG_CFLAGS += $(shell pkg-config --cflags libical)
SHLIB_LINK += $(shell pkg-config --libs libical)

include $(PGXS)
