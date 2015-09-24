SUBMODULES = $(patsubst %/,%,$(dir $(wildcard */.git)))
EXPORTS =  $(patsubst %,%.fast-export.xz,$(SUBMODULES))

all: export
export: $(EXPORTS)

%.fast-export.xz: $(wildcard ../.git/modules/git-repos/%/refs/*/*)  # (re-)export if refs have changed
	(cd $* && git fast-export --all --signed-tags=verbatim) | xz -c > $@

distclean:
	rm -f $(EXPORTS)
