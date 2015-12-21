<?xml version="1.0"?>

<xsl:stylesheet version="1.0" xmlns:xsl="http://www.w3.org/1999/XSL/Transform">
    <xsl:output method="text" encoding="UTF-8" media-type="text/plain"/>
<xsl:template match="/">
<xsl:for-each select="printout/section-01">
    <xsl:variable name='number-type' select="z13-isbn-issn-code"/>
    <xsl:variable name='standard_number1' select="z13-isbn-issn"/> 
    <xsl:variable name='standard_number2' select="concat($standard_number1,' ')"/> 
    <xsl:variable name='standard_number' select="substring-before($standard_number2,' ')"/>
{
    'transaction'   : '<xsl:value-of select="z37-id"/>',
    'request_type'  : 'Doc Del',
    'delivery_type' : 'Ship',
    'source'        : 'Aleph',
    'title'         : '<xsl:value-of select="z13-title"/>',
    'author'        : '<xsl:value-of select="z13-author"/>',
    'enum_chron'    : '<xsl:value-of select="z30-description"/>',
    'pages'         : '<xsl:value-of select="z37-pages"/>',
    'article_title' : '<xsl:value-of select="z37-title"/>',
    'article_author': '<xsl:value-of select="z37-author"/>',
    'barcode'       : '<xsl:value-of select="z30-barcode"/>',
    'isbn'          : '<xsl:if test="$number-type = '020'"><xsl:value-of select="$standard_number"/></xsl:if>',
    'issn'          : '<xsl:if test="$number-type = '022'"><xsl:value-of select="$standard_number"/></xsl:if>',
    'bib_number'    : '<xsl:value-of select="z13-doc-number"/>',
    'adm_number'    : '<xsl:value-of select="z30-doc-number"/>',
    'item_sequence' : '<xsl:value-of select="z30-item-sequence"/>',
    'call_number'   : '<xsl:value-of select="z30-call-no"/>',
    'send_to'       : '<xsl:copy-of select="z37-pickup-location"/>',
    'rush'          : '<xsl:value-of select="z37-rush-request"/>' 
}
</xsl:for-each>
</xsl:template>
</xsl:stylesheet>
