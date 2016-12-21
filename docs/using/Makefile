# Makefile for docbook presentations (slides)

BASE=using-provision-aws

# src is expected in     $(DOC-BASE-NAME).db5
# pdf will be written to $(DOC-BASE-NAME).pdf
# html will be in web/index.html

INCLUDES=ch-intro.db5 ch-conf-file.db5 ch-new-project.db5 \
	ap-resources.db5 \
	$(FRAGS)

FRAGS=

XSL_BASE=http://docbook.sourceforge.net/release/xsl-ns/current

FOP=fop

# assumes config off the top doc directory
XSL=./config/custom-fo.xsl

XSLTPROC=xsltproc
XSLTOPTS=--stringparam fop1.extensions 1
XSLT_HTML_OPTS=
HTML_XSL=$(XSL_BASE)/html/docbook.xsl

WEBDIR=web
WEB_TARGET=$(WEBDIR)/index.html

all: pdf web

pdf: $(BASE).pdf

$(BASE).pdf: $(BASE).db5 $(INCLUDES)

web: $(WEB_TARGET)

$(WEB_TARGET): $(BASE).db5 $(INCLUDES)
	$(XSLTPROC) -o $@ --xinclude $(XSLT_HTML_OPTS) $(HTML_XSL) $<

%.fo: %.xml
	$(XSLTPROC) -o $@  $(XSLTOPTS) --xinclude $(XSL) $<

%.fo: %.db5
	$(XSLTPROC) -o $@ $(XSLTOPTS) --xinclude $(XSL) $<

%.pdf: %.fo
	$(FOP) -fo $< -pdf $@


#%.html: %.db5
.db5.html:
	$(XSLTPROC) -o $@ --xinclude $(XSLT_HTML_OPTS) $(HTML_XSL) $<


clean:
	rm -f *~

.SUFFIXES: .pdf .html .pdf .xsl .xml .db5 .fo

.PHONY: web pdf all clean
