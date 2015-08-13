<?xml version="1.0" encoding="UTF-8"?>
<xsl:stylesheet xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
               xmlns:xs="http://www.w3.org/2001/XMLSchema"
               xmlns:ve="http://schemas.openxmlformats.org/markup-compatibility/2006"
               xmlns:o="urn:schemas-microsoft-com:office:office"
               xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships"
               xmlns:m="http://schemas.openxmlformats.org/officeDocument/2006/math"
               xmlns:v="urn:schemas-microsoft-com:vml"
               xmlns:wp="http://schemas.openxmlformats.org/drawingml/2006/wordprocessingDrawing"
               xmlns:w10="urn:schemas-microsoft-com:office:word"
               xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main"
               xmlns:wne="http://schemas.microsoft.com/office/word/2006/wordml"
               xmlns:a="http://schemas.openxmlformats.org/drawingml/2006/main"
               xmlns:pic="http://schemas.openxmlformats.org/drawingml/2006/picture"
               xmlns:opentopic-index="http://www.idiominc.com/opentopic/index"
               xmlns:opentopic="http://www.idiominc.com/opentopic"
               xmlns:ot-placeholder="http://suite-sol.com/namespaces/ot-placeholder"
               xmlns:a14="http://schemas.microsoft.com/office/drawing/2010/main"
               xmlns:x="com.elovirta.ooxml"
               xmlns:java="org.dita.dost.util.ImgUtils"
               exclude-result-prefixes="x java xs opentopic opentopic-index ot-placeholder"
               version="2.0">
  
  <xsl:template match="*[contains(@class, ' topic/related-links ')]">
    <xsl:variable name="links" as="element()*"
                  select="*[contains(@class, ' topic/link ')] |
                          *[contains(@class, ' topic/linkpool ')]/*[contains(@class, ' topic/link ')]"/>
    <xsl:if test="exists($links)">
      <w:p>
        <w:pPr>
          <w:pStyle w:val="Subtitle"/>
        </w:pPr>
        <w:r>
          <w:t>Related topics</w:t>
        </w:r>
      </w:p>
      <xsl:apply-templates select="$links"/>
    </xsl:if>
  </xsl:template>
  
  <xsl:template match="*[contains(@class, ' topic/link ')]">
    <xsl:variable name="target" select="x:get-target(.)" as="element()?"/>
    <xsl:if test="exists($target)">
      <!--xsl:comment>
        <xs:text>target: </xs:text>
        <xsl:value-of select="name($target)"/>
      </xsl:comment-->
      <w:p>
        <w:pPr>
          <xsl:if test="position() ne last()">
            <w:spacing w:after="0"/>
          </xsl:if>
          <w:tabs>
            <w:tab w:val="left" w:pos="373"/>
            <w:tab w:val="right" w:leader="dot" w:pos="8290"/>
          </w:tabs>
        </w:pPr>
        <w:r>
          <w:fldChar w:fldCharType="begin"/>
        </w:r>
        <w:r>
          <w:instrText>
            <xsl:attribute name="xml:space">preserve</xsl:attribute>
            <xsl:text> REF _Ref</xsl:text>
            <xsl:value-of select="generate-id($target)"/>
            <xsl:text> </xsl:text>
            <xsl:text>\h </xsl:text>
          </w:instrText>
        </w:r>
        <w:r>
          <w:fldChar w:fldCharType="separate"/>
        </w:r>
        <xsl:apply-templates select="*[contains(@class, ' topic/linktext ')]/node()"/>
        <w:r>
          <w:fldChar w:fldCharType="end"/>
        </w:r>
      </w:p>
    </xsl:if>
  </xsl:template>
  
  <xsl:function name="x:get-target" as="element()?">
    <xsl:param name="link" as="element()?"/>
    <xsl:variable name="scope" select="if ($link/@scope) then $link/@scope else 'local'"/>
    <xsl:variable name="format" select="if ($link/@format) then $link/@format else 'dita'"/>
    <xsl:choose>
      <xsl:when test="$scope != 'local' or $format != 'dita'"/>
      <xsl:otherwise>
        <xsl:variable name="h" select="substring-after($link/@href, '#')"/>
        <xsl:variable name="topic" select="if (contains($h, '/')) then substring-before($h, '/') else $h" as="xs:string"/>
        <xsl:variable name="element" select="if (contains($h, '/')) then substring-after($h, '/') else ()" as="xs:string?"/>
        <xsl:choose>
          <xsl:when test="empty($element)">
            <xsl:sequence select="key('id', $topic, $root)[not(contains(@class, ' map/topicref '))][1]"/>
          </xsl:when>
          <xsl:when test="count(key('id', $element, $root)[not(contains(@class, ' map/topicref '))]) eq 1">
            <xsl:sequence select="key('id', $element, $root)[not(contains(@class, ' map/topicref '))]"/>
          </xsl:when>
          <xsl:otherwise>
            <xsl:sequence select="(key('id', $topic, $root)[not(contains(@class, ' map/topicref '))]/descendant::*[@id and @id = $element])[1]"/>
          </xsl:otherwise>
        </xsl:choose>
      </xsl:otherwise>
    </xsl:choose>
  </xsl:function>
  
  <xsl:template match="*[contains(@class, ' topic/xref ')]" name="topic.xref">
    <xsl:param name="contents" as="node()*">
      <xsl:apply-templates/>
    </xsl:param>
    <xsl:variable name="target" as="element()?" select="x:get-target(.)"/>
    <xsl:choose>
      <xsl:when test="@scope = 'external'">
        <w:hyperlink r:id="rIdHyperlink{@x:external-link-number}">
          <xsl:copy-of select="$contents"/>
        </w:hyperlink>
      </xsl:when>
      <xsl:when test="empty($target)">
        <xsl:copy-of select="$contents"/>
      </xsl:when>
      <xsl:when test="contains($target/@class, ' topic/topic ') and not(contains($target/@class, ' glossentry/glossentry '))">
        <xsl:apply-templates select="$target" mode="xref-prefix"/>
        <w:r>
          <w:fldChar w:fldCharType="begin"/>
        </w:r>
        <w:r>
          <w:instrText>
            <xsl:attribute name="xml:space">preserve</xsl:attribute>
            <xsl:text> </xsl:text>
            <xsl:choose>
              <xsl:when test="false()">PAGEREF </xsl:when>
              <xsl:otherwise>REF </xsl:otherwise>
            </xsl:choose>
            <xsl:value-of select="concat('_Num', generate-id($target))"/>
            <xsl:text> \h </xsl:text>
          </w:instrText>
        </w:r>
        <w:r>
          <w:fldChar w:fldCharType="separate"/>
        </w:r>
        <xsl:copy-of select="$contents"/>
        <w:r>
          <w:fldChar w:fldCharType="end"/>
        </w:r>
      </xsl:when>
      <xsl:when test="@type = 'fn'">
        <xsl:apply-templates select="$target"/>
      </xsl:when>
      <xsl:when test="@type = 'fig'">
        <xsl:apply-templates select="$target" mode="xref-prefix"/>
        <w:r>
          <w:fldChar w:fldCharType="begin"/>
        </w:r>
        <w:r>
          <w:instrText>
            <xsl:attribute name="xml:space">preserve</xsl:attribute>
            <xsl:text> REF </xsl:text>
            <xsl:value-of select="concat('_Num', generate-id($target))"/>
            <xsl:text> \h </xsl:text>
          </w:instrText>
        </w:r>
        <w:r>
          <w:fldChar w:fldCharType="separate"/>
        </w:r>
        <xsl:copy-of select="$contents"/>
        <w:r>
          <w:fldChar w:fldCharType="end"/>
        </w:r>
      </xsl:when>
      <xsl:when test="@type = 'table'">
        <xsl:apply-templates select="$target" mode="xref-prefix"/>
        <w:r>
          <w:fldChar w:fldCharType="begin"/>
        </w:r>
        <w:r>
          <w:instrText>
            <xsl:attribute name="xml:space">preserve</xsl:attribute>
            <xsl:text> REF </xsl:text>
            <xsl:value-of select="concat('_Num', generate-id($target))"/>
            <xsl:text> \h </xsl:text>
          </w:instrText>
        </w:r>
        <w:r>
          <w:fldChar w:fldCharType="separate"/>
        </w:r>
        <xsl:copy-of select="$contents"/>
        <w:r>
          <w:fldChar w:fldCharType="end"/>
        </w:r>
      </xsl:when>
      <xsl:when test="@type = 'callout'">
        <w:r>
          <w:t>(</w:t>
        </w:r>
        <w:r>
          <w:fldChar w:fldCharType="begin"/>
        </w:r>
        <w:r>
          <w:instrText>
            <xsl:attribute name="xml:space">preserve</xsl:attribute>
            <xsl:text> REF </xsl:text>
            <xsl:value-of select="concat('_Ref', generate-id($target))"/>
            <xsl:text> \n \h </xsl:text>
          </w:instrText>
        </w:r>
        <w:r>
          <w:fldChar w:fldCharType="separate"/>
        </w:r>
        <xsl:copy-of select="$contents"/>
        <w:r>
          <w:fldChar w:fldCharType="end"/>
        </w:r>
        <w:r>
          <w:t>)</w:t>
        </w:r>
      </xsl:when>
      <xsl:otherwise>
        <w:r>
          <w:fldChar w:fldCharType="begin"/>
        </w:r>
        <w:r>
          <w:instrText>
            <xsl:attribute name="xml:space">preserve</xsl:attribute>
            <xsl:text> </xsl:text>
            <xsl:choose>
              <xsl:when test="false()">PAGEREF </xsl:when>
              <xsl:otherwise>REF </xsl:otherwise>
            </xsl:choose>
            <xsl:value-of select="concat('_Ref', generate-id($target))"/>
            <xsl:text> \h </xsl:text>
          </w:instrText>
        </w:r>
        <w:r>
          <w:fldChar w:fldCharType="separate"/>
        </w:r>
        <xsl:copy-of select="$contents"/>
        <w:r>
          <w:fldChar w:fldCharType="end"/>
        </w:r>
      </xsl:otherwise>
    </xsl:choose>
  </xsl:template>
  
  <xsl:template match="node()" mode="xref-prefix"/>
  
  <xsl:template match="*[contains(@class, ' topic/table ')]" mode="xref-prefix">
    <w:r>
      <w:t>Table&#xA0;</w:t>
    </w:r>
  </xsl:template>
  
  <xsl:template match="*[contains(@class, ' topic/fig ')]" mode="xref-prefix">
    <w:r>
      <w:t>Figure&#xA0;</w:t>
    </w:r>
  </xsl:template>
  
  <xsl:template match="*[contains(@class, ' topic/xref ')]" mode="inline-style">
    <w:u w:val="single"/>
  </xsl:template>

  <xsl:template match="*[contains(@class, ' topic/xref ')][@scope = 'external']" mode="inline-style" priority="10">
    <!--w:color w:val="0000FF" w:themeColor="hyperlink"/>
    <w:u w:val="single"/-->
    <w:rStyle w:val="Hyperlink"/>
  </xsl:template>
  
</xsl:stylesheet>
