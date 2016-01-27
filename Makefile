DBNAME = softwareheritage-dev
DB_DUMPS = dumps/swh.dump dumps/swh.sql
PSQL = psql -X

all:

dumpdb: $(DB_DUMPS)
	@if ! echo | $(PSQL) $(DBNAME) ; then echo "Can't find $(DBNAME). Try make -C ../swh-storage/sql/ distclean filldb" ; false ; fi
dumps/swh.dump:
	@if ! echo | $(PSQL) $(DBNAME) ; then echo "Can't find $(DBNAME). Try make -C ../swh-storage/sql/ distclean filldb" ; false ; fi
	pg_dump -F custom --no-owner $(DBNAME) > $@
dumps/swh.sql:
	@if ! echo | $(PSQL) $(DBNAME) ; then \
		echo "Can't find $(DBNAME). Try make -C ../swh-storage/sql/ distclean filldb" ; \
		false ; \
	fi
	pg_dump -F plain  --no-owner $(DBNAME) > $@

clean:
distclean: clean
	rm -f $(DB_DUMPS)
