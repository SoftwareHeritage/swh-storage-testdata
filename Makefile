BASES = swh swh-archiver swh-scheduler swh-indexer swh-scheduler-updater
EXTS = dump sql
DUMPS = $(foreach ext,$(EXTS),$(foreach base,$(BASES), dumps/$(base).$(ext)))

PSQL = psql -X

all:
dumpdb: $(DUMPS)

dumps/%.dump:
	pg_dump --no-owner -F custom $(subst swh,softwareheritage,$*)-dev > $@

dumps/%.sql:
	pg_dump --no-owner -F plain $(subst swh,softwareheritage,$*)-dev > $@

clean:
distclean: clean
	rm -f $(DUMPS)
