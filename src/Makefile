
# install the cftgen tool suite


TARGETDIR=/usr/local/aws/cf

install: install.bin

syntax.check:
	for f in bin/*.sh; do \
	  bash -n $$f || exit 1; \
	done

install.bin: syntax.check

	-mkdir -p $(TARGETDIR)/bin
	for f in bin/*.sh; do \
	  cp $$f $(TARGETDIR)/bin/`basename $$f .sh`; \
	done
