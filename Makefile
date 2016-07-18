DBNAME = softwareheritage-dev
DB_DUMPS = dumps/swh.dump dumps/swh.sql
DBNAME2 = softwareheritage-archiver-dev
DB_DUMPS2 = dumps/swh-archiver.dump dumps/swh-archiver.sql
PSQL = psql -X

all:
dumpdb: $(DB_DUMPS) $(DB_DUMPS2)
	@if ! echo | $(PSQL) $(DBNAME) ; then echo "Can't find $(DBNAME). Try make -C ../swh-storage/sql/ distclean filldb" ; false ; fi
	@if ! echo | $(PSQL) $(DBNAME2) ; then echo "Can't find $(DBNAME2). Try make -C ../swh-storage/sql/archiver/ distclean filldb" ; false ; fi
dumps/swh.dump:
	@if ! echo | $(PSQL) $(DBNAME) ; then echo "Can't find $(DBNAME). Try make -C ../swh-storage/sql/ distclean filldb" ; false ; fi
	pg_dump -F custom --no-owner $(DBNAME) > $@
dumps/swh.sql:
	@if ! echo | $(PSQL) $(DBNAME) ; then \
		echo "Can't find $(DBNAME). Try make -C ../swh-storage/sql/ distclean filldb" ; \
		false ; \
	fi
	pg_dump -F plain  --no-owner $(DBNAME) > $@
dumps/swh-archiver.dump:
	@if ! echo | $(PSQL) $(DBNAME2) ; then echo "Can't find $(DBNAME2). Try make -C ../swh-storage/sql/archiver/ distclean filldb" ; false ; fi
	pg_dump -F custom --no-owner $(DBNAME2) > $@
dumps/swh-archiver.sql:
	@if ! echo | $(PSQL) $(DBNAME2) ; then \
		echo "Can't find $(DBNAME2). Try make -C ../swh-storage/sql/archiver/ distclean filldb" ; \
		false ; \
	fi
	pg_dump -F plain  --no-owner $(DBNAME2) > $@

clean:
distclean: clean
	rm -f $(DB_DUMPS) $(DB_DUMPS2)
