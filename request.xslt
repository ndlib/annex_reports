<?xml version="1.0"?>

<xsl:stylesheet version="1.0" xmlns:xsl="http://www.w3.org/1999/XSL/Transform">
    <xsl:output method="text" encoding="UTF-8" media-type="text/plain"/>
<xsl:template match="/">
<xsl:for-each select="printout/section-01">
    <xsl:variable name='number-type' select="z13-isbn-issn-code"/>
    <xsl:variable name='standard_number1' select="z13-isbn-issn"/> 
    <xsl:variable name='standard_number2' select="concat($standard_number1,' ')"/> 
    <xsl:variable name='standard_number' select="substring-before($standard_number2,' ')"/>
    <xsl:variable name='date' select="z37-open-date"/>
        <xsl:variable name="month" select="substring-before($date,'/')" />
        <xsl:variable name="day" select="substring-before(substring-after($date,'/'),'/')" />
        <xsl:variable name="year" select="substring-after(substring-after($date,'/'),'/')" />
        <xsl:variable name='date2' select="concat($year,'-',$month,'-',$day)"/>
    <xsl:variable name='time' select="z37-open-hour"/>
    <xsl:variable name='date_time' select="concat($date2,' ',$time)"/>
{
    "transaction"   : "<xsl:value-of select="z37-request-number"/>",
    "request_type"  : "Doc Del",
    "delivery_type" : "Loan",
    "pickup"        : "<xsl:value-of select="z37-pickup-location"/>",
    "request_date"  : "<xsl:value-of select="$date_time"/>",
    "source"        : "Aleph",
    "title"         : "<xsl:value-of select="z13-title"/>",
    "author"        : "<xsl:value-of select="z13-author"/>",
    "description"   : "<xsl:value-of select="z30-description"/>",
    "pages"         : "<xsl:value-of select="z37-pages"/>",
    "article_title" : "<xsl:value-of select="z37-title"/>",
    "article_author": "<xsl:value-of select="z37-author"/>",
    "barcode"       : "<xsl:value-of select="z30-barcode"/>",
    "isbn"          : "<xsl:if test="$number-type = '020'"><xsl:value-of select="$standard_number"/></xsl:if>",
    "issn"          : "<xsl:if test="$number-type = '022'"><xsl:value-of select="$standard_number"/></xsl:if>",
    "bib_number"    : "<xsl:value-of select="z13-doc-number"/>",
    "adm_number"    : "<xsl:value-of select="z30-doc-number"/>",
    "item_sequence" : "<xsl:value-of select="z30-item-sequence"/>",
    "call_number"   : "<xsl:value-of select="z30-call-no"/>",
    "send_to"       : "<xsl:copy-of select="z37-pickup-location"/>",
    "rush"          : "<xsl:value-of select="z37-rush-request"/>",
    "institution"   : "<xsl:value-of select="z305-bor-type"/>",
    "department"    : "<xsl:value-of select="z302-field-3"/>",
    "user_status"   : "<xsl:value-of select="z305-bor-status"/>"
}
</xsl:for-each>
</xsl:template>
</xsl:stylesheet>
