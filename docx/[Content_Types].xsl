<?xml version="1.0" encoding="UTF-8"?>
<xsl:stylesheet xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
                xmlns:xs="http://www.w3.org/2001/XMLSchema"
                xmlns="http://schemas.openxmlformats.org/package/2006/content-types"
                xmlns:x="com.elovirta.ooxml"
                xmlns:c="http://schemas.openxmlformats.org/package/2006/content-types"
                exclude-result-prefixes="xs x c"
                version="2.0">

  <xsl:param name="input.uri"/>
  <xsl:variable name="input" select="document($input.uri)"/>
  
  <xsl:variable name="prefix" select="'application/vnd.openxmlformats-officedocument.wordprocessingml.'"/>
  <xsl:variable name="suffix" select="'+xml'"/>

  <xsl:template match="c:Types">
    <xsl:copy>
      <xsl:apply-templates select="node() | @*"/>
      <xsl:if test="empty(c:Override[@ContentType = concat($prefix, 'comments', $suffix)])">
        <Override PartName="/word/comments.xml" ContentType="{$prefix}comments{$suffix}"/>
      </xsl:if>
      <xsl:if test="empty(c:Override[@ContentType = concat($prefix, 'footnotes', $suffix)])">
        <Override PartName="/word/footnotes.xml" ContentType="{$prefix}footnotes{$suffix}"/>
      </xsl:if>
      <xsl:if test="empty(c:Override[@ContentType = concat($prefix, 'numbering', $suffix)])">
        <Override PartName="/word/numbering.xml" ContentType="{$prefix}numbering{$suffix}"/>
      </xsl:if>
    </xsl:copy>
  </xsl:template>
  
  <xsl:template match="c:Override/@ContentType[. = 'application/vnd.ms-word.template.macroEnabledTemplate.main+xml']">
    <xsl:attribute name="{name()}">
      <xsl:text>application/vnd.ms-word.document.macroEnabled.main+xml</xsl:text>
    </xsl:attribute>
  </xsl:template>
  
  <xsl:template match="c:Override/@ContentType[. = 'application/vnd.openxmlformats-officedocument.wordprocessingml.template.main+xml']">
    <xsl:attribute name="{name()}">
      <xsl:text>application/vnd.openxmlformats-officedocument.wordprocessingml.document.main+xml</xsl:text>
    </xsl:attribute>
  </xsl:template>
  
  <xsl:template match="node() | @*" priority="-10">
    <xsl:copy>
      <xsl:apply-templates select="node() | @*"/>
    </xsl:copy>
  </xsl:template>
  
</xsl:stylesheet>