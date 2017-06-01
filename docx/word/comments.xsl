<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<xsl:stylesheet xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
                xmlns:xs="http://www.w3.org/2001/XMLSchema"
                xmlns:wpc="http://schemas.microsoft.com/office/word/2010/wordprocessingCanvas"
                xmlns:mo="http://schemas.microsoft.com/office/mac/office/2008/main"
                xmlns:mc="http://schemas.openxmlformats.org/markup-compatibility/2006"
                xmlns:mv="urn:schemas-microsoft-com:mac:vml" xmlns:o="urn:schemas-microsoft-com:office:office"
                xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships"
                xmlns:m="http://schemas.openxmlformats.org/officeDocument/2006/math"
                xmlns:v="urn:schemas-microsoft-com:vml"
                xmlns:wp14="http://schemas.microsoft.com/office/word/2010/wordprocessingDrawing"
                xmlns:wp="http://schemas.openxmlformats.org/drawingml/2006/wordprocessingDrawing"
                xmlns:w10="urn:schemas-microsoft-com:office:word"
                xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main"
                xmlns:w14="http://schemas.microsoft.com/office/word/2010/wordml"
                xmlns:wpg="http://schemas.microsoft.com/office/word/2010/wordprocessingGroup"
                xmlns:wpi="http://schemas.microsoft.com/office/word/2010/wordprocessingInk"
                xmlns:wne="http://schemas.microsoft.com/office/word/2006/wordml"
                xmlns:wps="http://schemas.microsoft.com/office/word/2010/wordprocessingShape"
                xmlns:a14="http://schemas.microsoft.com/office/drawing/2010/main"
                xmlns:ve="http://schemas.openxmlformats.org/markup-compatibility/2006"
                xmlns:a="http://schemas.openxmlformats.org/drawingml/2006/main"
                xmlns:pic="http://schemas.openxmlformats.org/drawingml/2006/picture"
                xmlns:x="com.elovirta.ooxml"
                version="2.0"
                exclude-result-prefixes="x xs">

  <xsl:import href="document.xsl"/> 

  <xsl:template match="/">
    <w:comments mc:Ignorable="w14 wp14">
      <xsl:apply-templates select="//*[contains(@class, ' topic/draft-comment ')] |
                                   //processing-instruction('oxy_comment_start')"/>
    </w:comments>
  </xsl:template>
  
  <xsl:template match="*[contains(@class, ' topic/draft-comment ')]">
    <w:comment w:id="{@x:draft-comment-number}">
      <xsl:if test="@author">
        <xsl:attribute name="w:author" select="@author"/>
        <xsl:attribute name="w:initials">
          <xsl:for-each select="tokenize(@author, '\s+')">
            <xsl:value-of select="upper-case(substring(., 1, 1))"/>
          </xsl:for-each>
        </xsl:attribute>
      </xsl:if>
      <xsl:if test="@time">
        <xsl:attribute name="w:date" select="@time"/>
      </xsl:if>
      <w:p>
        <w:pPr>
          <w:pStyle w:val="CommentText"/>
        </w:pPr>
        <w:r>
          <w:rPr>
            <w:rStyle w:val="CommentReference"/>
          </w:rPr>
          <w:annotationRef/>
        </w:r>
      </w:p>
      <xsl:apply-templates/>      
    </w:comment>
  </xsl:template>
  
  <xsl:template match="processing-instruction('oxy_comment_start')">
    <xsl:variable name="attributes" as="element()">
      <res>
        <xsl:apply-templates select="." mode="x:parse-pi"/>
      </res>
    </xsl:variable>
    <w:comment w:id="{$attributes/@draft-comment-number}">
      <xsl:if test="$attributes/@author">
        <xsl:attribute name="w:author" select="$attributes/@author"/>
        <xsl:attribute name="w:initials">
          <xsl:for-each select="tokenize($attributes/@author, '\s+')">
            <xsl:value-of select="upper-case(substring(., 1, 1))"/>
          </xsl:for-each>
        </xsl:attribute>
      </xsl:if>
      <xsl:if test="$attributes/@timestamp">
        <xsl:attribute name="w:date" select="replace($attributes/@timestamp, '(\d{4})(\d{2})(\d{2})T(\d{2})(\d{2})(\d{2})([-+]\d{4}|Z)', '$1-$2-$3T$4:$5:$6$7')"/>
      </xsl:if>
      <w:p>
        <w:pPr>
          <w:pStyle w:val="CommentText"/>
        </w:pPr>
        <w:r>
          <w:rPr>
            <w:rStyle w:val="CommentReference"/>
          </w:rPr>
          <w:annotationRef/>
        </w:r>
        <w:r>
          <xsl:for-each select="tokenize($attributes/@comment, '&#xA;')">
            <xsl:if test="position() ne 1">
              <w:br/>
            </xsl:if>
            <w:t>
              <xsl:variable name="apos" as="xs:string">'</xsl:variable>
              <xsl:variable name="quot" as="xs:string">"</xsl:variable>
             <xsl:value-of select="replace(replace(.,
               '&amp;apos;', $apos),
               '&amp;quot;', $quot)"/>
            </w:t>  
          </xsl:for-each>
        </w:r>
      </w:p>
    </w:comment>
  </xsl:template>

</xsl:stylesheet>
