<?xml version='1.0'?>
<xsl:stylesheet
    xmlns:d="http://docbook.org/ns/docbook"
    xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
    xmlns:fo="http://www.w3.org/1999/XSL/Format"
    exclude-result-prefixes="d"
    version="1.0">

<!-- Based on the New Mexico Tech customizations -->

<!-- Uses the ns versionof the style sheets, so objects must be -->
<!-- referenced as d: -->


  <xsl:import
      href="http://docbook.sourceforge.net/release/xsl-ns/current/fo/docbook.xsl"/>

  <xsl:import href="titlepage-fo.xsl"/>

  <xsl:include href="custom-common.xsl" />

  <xsl:param name="custom-fo-herald">
    <xsl:message>===== custom-fo.xsl =====</xsl:message>
  </xsl:param>


  <xsl:param name="generate.toc">
/appendix toc,title
article/appendix  nop
/article  toc,title,figure,table,example,equation,procedure
book      toc,title,figure,table,example,equation,procedure
/chapter  toc,title
part      toc,title
/preface  toc,title
reference toc,title
/sect1    toc
/sect2    toc
/sect3    toc
/sect4    toc
/sect5    toc
/section  toc
set       toc,title
  </xsl:param>


<!--Turn on double-sided printing-->
<xsl:param name="double.sided">1</xsl:param>

<!--Set the body font size-->
<xsl:param name="body.font.master">10</xsl:param>

<!--Set up the monospaced font-->
<xsl:attribute-set name="monospace.properties">
  <xsl:attribute name="font-family">
    <xsl:value-of select="$monospace.font.family"/>
  </xsl:attribute>
  <xsl:attribute name="font-size">
    <xsl:value-of select="font-size"
    /><xsl:text>0.9em</xsl:text>
  </xsl:attribute>
</xsl:attribute-set>

<!--Set up inner and outer side margins-->
<xsl:param name="page.margin.outer">0.75in</xsl:param>
<xsl:param name="page.margin.inner">1in</xsl:param>

<!--body.start.indent: Set the body indentation level-->
<xsl:param name="body.start.indent">3pc</xsl:param>


<!-- change the margins of the abstract -->

<xsl:attribute-set name="abstract.properties">
  <xsl:attribute name="start-indent">0.5in</xsl:attribute>
  <xsl:attribute name="end-indent">0.5in</xsl:attribute>
</xsl:attribute-set>

<!--insert.xref.page.number: Cross-reference by page no.-->
<xsl:param name="insert.xref.page.number">1</xsl:param>


<!--header.rule: Disable a ruled line below the running head-->
<xsl:param name="header.rule" select="0"/>

<xsl:param name="draft.mode" >no</xsl:param>

<!--region.before.extent: Height of the (empty) running header-->
<xsl:param name="region.before.extent">0.25in</xsl:param>

<!--normal.para.spacing: Spacing above and below paragraphs-->
<xsl:attribute-set name="normal.para.spacing">
  <xsl:attribute name="space-before.minimum">0.50em</xsl:attribute>
  <xsl:attribute name="space-before.optimum">0.60em</xsl:attribute>
  <xsl:attribute name="space-before.maximum">0.70em</xsl:attribute>
</xsl:attribute-set>

<!--list.block.spacing: Space before/after lists-->
<xsl:attribute-set name="list.block.spacing">
  <xsl:attribute name="space-before.minimum">0.70em</xsl:attribute>
  <xsl:attribute name="space-before.optimum">0.75em</xsl:attribute>
  <xsl:attribute name="space-before.maximum">0.80em</xsl:attribute>
  <xsl:attribute name="space-after.minimum">0.70em</xsl:attribute>
  <xsl:attribute name="space-after.optimum">0.75em</xsl:attribute>
  <xsl:attribute name="space-after.maximum">0.80em</xsl:attribute>
</xsl:attribute-set>

<!--list.item.spacing: Space between list items-->
<xsl:attribute-set name="list.item.spacing">
  <xsl:attribute name="space-before.minimum">0.50em</xsl:attribute>
  <xsl:attribute name="space-before.optimum">0.60em</xsl:attribute>
  <xsl:attribute name="space-before.maximum">0.70em</xsl:attribute>
</xsl:attribute-set>

<!--verbatim.properties: Spacing around verbatim blocks-->
<xsl:attribute-set name="verbatim.properties">
  <xsl:attribute name="space-before.minimum">0.4em</xsl:attribute>
  <xsl:attribute name="space-before.optimum">0.5em</xsl:attribute>
  <xsl:attribute name="space-before.maximum">0.6em</xsl:attribute>
  <xsl:attribute name="space-after.minimum">0.4em</xsl:attribute>
  <xsl:attribute name="space-after.optimum">0.5em</xsl:attribute>
  <xsl:attribute name="space-after.maximum">0.6em</xsl:attribute>
  <xsl:attribute name="border-width">0.1mm</xsl:attribute>
  <xsl:attribute name="border-style">solid</xsl:attribute>
  <xsl:attribute name="padding">1mm</xsl:attribute>
</xsl:attribute-set>

<!--Let these elements have their usual appearance in the TOC-->
<xsl:template
  match="d:filename|d:sgmltag|d:userinput|d:varname|d:code|d:application"
  mode="no.anchor.mode">
  <xsl:apply-templates select="." />
</xsl:template>

<!-- ** Header/Footer Customizations ** -->

<!--header.rule: Disable a ruled line below the running head-->
<xsl:param name="header.rule" select="0"/>

<!--Content of the running head, empty for us-->
<xsl:template name="header.content">
  <xsl:param name="pageclass" select="''"/>
  <xsl:param name="sequence" select="''"/>
  <xsl:param name="position" select="''"/>
  <xsl:param name="gentext-key" select="''"/>
</xsl:template>

<!--footer.content.properties: Appearance of the running footer-->
<xsl:attribute-set name="footer.content.properties">
  <xsl:attribute name="font-style">italic</xsl:attribute>
  <xsl:attribute name="font-size">9pt</xsl:attribute>
  <xsl:attribute name="font-family">
    <xsl:value-of select="$body.fontset"/>
  </xsl:attribute>
  <xsl:attribute name="margin-left">
    <xsl:value-of select="$title.margin.left"/>
  </xsl:attribute>
</xsl:attribute-set>

<!--footer.content: Pieces of the running footer-->
<xsl:template name="footer.content">
  <xsl:param name="pageclass" select="''"/>
  <xsl:param name="sequence" select="''"/>
  <xsl:param name="position" select="''"/>
  <xsl:param name="gentext-key" select="''"/>


  <fo:block>

    <xsl:choose>
      <xsl:when test="$pageclass = 'titlepage'">
        <!--no footer on title pages-->
      </xsl:when>

      <xsl:otherwise>       <!--Not a title page-->
        <xsl:choose>
          <xsl:when test="$double.sided = 0">   <!-- Single-sided -->
            <xsl:choose>
              <xsl:when test="$position = 'left'">
                <xsl:apply-templates select="."
                    mode="titleabbrev.markup"/>
              </xsl:when>
              <xsl:when test="$position = 'center'">
                <fo:page-number/>
              </xsl:when>
              <xsl:when test="$position = 'right'">
                <xsl:value-of select="$organization.name"/>
              </xsl:when>
            </xsl:choose>
          </xsl:when>       <!-- Single-sided -->


          <xsl:otherwise>   <!--Double-sided-->
            <xsl:choose>
              <xsl:when test="$position = 'left'">
                <xsl:choose>
                  <xsl:when test="$sequence = 'even' or
                                  $sequence = 'blank'">
                    <fo:page-number/>
                  </xsl:when>
                  <xsl:otherwise> <!-- left/odd -->
                    <xsl:value-of select="$organization.name"/>
                  </xsl:otherwise>
                </xsl:choose>
              </xsl:when>

              <xsl:when test="$position = 'center'">
                <xsl:apply-templates select="." mode="titleabbrev.markup"/>
              </xsl:when>


              <xsl:when test="$position = 'right'">
                <xsl:choose>
                  <xsl:when test="$sequence = 'even' or
                                  $sequence = 'blank'">

                    <xsl:value-of select="$organization.name"/>
                  </xsl:when>
                  <xsl:otherwise> <!-- left/odd -->
                    <fo:page-number/>
                  </xsl:otherwise>
                </xsl:choose>
              </xsl:when>
            </xsl:choose>
          </xsl:otherwise>  <!-- Double-sided -->
        </xsl:choose>
      </xsl:otherwise>      <!--Not a title page-->
    </xsl:choose>
  </fo:block>
</xsl:template>


<xsl:param name="section.autolabel">1</xsl:param>
<xsl:param name="section.label.includes.component.label">1</xsl:param>

<!--section.title.level1.properties: Level 1 titles-->
<xsl:attribute-set name="section.title.level1.properties"
                   use-attribute-sets="section.properties">

  <xsl:attribute name="border-bottom-style">solid</xsl:attribute>
  <xsl:attribute name="border-bottom-width">1pt</xsl:attribute>

  <xsl:attribute name="font-size">
    <xsl:value-of select="$body.font.master * 1.728"/>
    <xsl:text>pt</xsl:text>
  </xsl:attribute>
</xsl:attribute-set>

<!--section.title.level2.properties: Level 2 titles-->
<xsl:attribute-set name="section.title.level2.properties">
  <xsl:attribute name="font-size">
    <xsl:value-of select="$body.font.master * 1.44"/>
    <xsl:text>pt</xsl:text>
  </xsl:attribute>
</xsl:attribute-set>
<xsl:attribute-set name="section.title.level3.properties">
  <xsl:attribute name="font-size">
    <xsl:value-of select="$body.font.master * 1.2"/>
    <xsl:text>pt</xsl:text>
  </xsl:attribute>
</xsl:attribute-set>

<!--section.title.properties: Appearance of section titles-->
<xsl:attribute-set name="section.title.properties">
  <xsl:attribute name="font-family">
    <xsl:value-of select="$title.font.family"/>
  </xsl:attribute>
  <xsl:attribute name="font-weight">bold</xsl:attribute>
  <!-- font size is calculated dynamically by section.heading template -->
  <xsl:attribute name="keep-with-next.within-column">always</xsl:attribute>
  <xsl:attribute name="space-before.minimum">1.8em</xsl:attribute>
  <xsl:attribute name="space-before.optimum">2em</xsl:attribute>
  <xsl:attribute name="space-before.maximum">2.2em</xsl:attribute>
  <xsl:attribute name="text-align">left</xsl:attribute>
  <xsl:attribute name="start-indent">
    <xsl:value-of select="$title.margin.left"/>
  </xsl:attribute>
</xsl:attribute-set>

<!-- ** Inline Element Cuztomizations ** -->


<!--inline.italicsansseq: Select italic sans-serif font-->
<xsl:template name="inline.italicsansseq">
  <xsl:param name="content">
    <xsl:apply-templates/>
  </xsl:param>

  <fo:inline font-style="italic" font-family="sans-serif">
    <xsl:copy-of select="$content"/>
  </fo:inline>
</xsl:template>

<!--inline.smallcaps: Select caps-and-small-caps font-->
<xsl:template name="inline.smallcaps">
  <xsl:param name="content">
    <xsl:apply-templates/>
  </xsl:param>
  <fo:inline font-variant="small-caps" font-family="LatinModernRoman">
    <xsl:copy-of select="$content"/>
  </fo:inline>
</xsl:template>

<!-- Use italic sans for application and the gui elements -->
<xsl:template
    match="d:guibutton|d:guiicon|d:guilabel|d:guimenu|d:guimenuitem">
  <xsl:call-template name="inline.italicsansseq"/>
</xsl:template>

<xsl:template  match="d:application">
  <xsl:call-template name="inline.italicsansseq"/>
</xsl:template>

<!--Boldface emphasis-->
<xsl:template match="d:emphasis[@role='strong']">
  <xsl:call-template name="inline.boldseq"/>
</xsl:template>


<xsl:param name="shade.verbatim" select="1"/>
<xsl:attribute-set name="shade.verbatim.style">
  <xsl:attribute name="background-color">#eef8e8</xsl:attribute>
</xsl:attribute-set>



<xsl:template match="d:lineannotation">
  <fo:inline font-style="italic">
    <xsl:call-template name="inline.charseq"/>
  </fo:inline>
</xsl:template>


<!--monospace.verbatim.properties: Verbatim blocks-->
<xsl:attribute-set name="monospace.verbatim.properties">
  <xsl:attribute name="wrap-option">wrap</xsl:attribute>
  <xsl:attribute name="hyphenation-character">&#x00bb;</xsl:attribute>
  <xsl:attribute name="margin">0.5pt</xsl:attribute>
</xsl:attribute-set>

<!-- italicize firstterm-->
<xsl:template match="d:firstterm">
  <xsl:call-template name="inline.italicseq"/>
</xsl:template>

<!--keysym-->
<xsl:template match="d:keysym">
  <xsl:call-template name="inline.smallcaps"/>
</xsl:template>

<!--Inline math-->
<xsl:template match="d:phrase[@role='math']">
  <xsl:call-template name="inline.italicseq"/>
</xsl:template>

<!--Move URLs to footnotes-->
<xsl:param name="ulink.footnotes">1</xsl:param>

<!--xref-->
<xsl:param name="local.l10n.xml" select="document('')"/>
<l:i18n xmlns:l="http://docbook.sourceforge.net/xmlns/l10n/1.0">
  <l:l10n language="en">
    <l:context name="xref">
      <l:template name="page.citation" text=" (p. %p)"/>
    </l:context>
  </l:l10n>
</l:i18n>


<!-- Admonition Customizations -->

<!--Wraps the argument in a narrow gray border-->
<xsl:template name="nongraphical.admonition">
  <xsl:variable name="id">
    <xsl:call-template name="object.id"/>
  </xsl:variable>

  <fo:block space-before.minimum="0.8em"
            space-before.optimum="1em"
            space-before.maximum="1.2em"
            start-indent="0.25in"
            end-indent="0.25in"
            border="4pt solid #d0d0d0"
            padding="4pt"
            id="{$id}">
    <xsl:if test="$admon.textlabel != 0 or title">
      <fo:block keep-with-next='always'
                xsl:use-attribute-sets="admonition.title.properties">
         <xsl:apply-templates select="." mode="object.title.markup"/>
      </fo:block>
    </xsl:if>

    <fo:block xsl:use-attribute-sets="admonition.properties">
      <xsl:apply-templates/>
    </fo:block>
  </fo:block>
</xsl:template>

</xsl:stylesheet>
