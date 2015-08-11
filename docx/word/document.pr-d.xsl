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
               xmlns:a14="http://schemas.microsoft.com/office/drawing/2010/main"
               xmlns:x="com.elovirta.ooxml"
               exclude-result-prefixes="x xs"
               version="2.0">

  <!-- monospaced -->
  <xsl:template match="*[contains(@class, ' pr-d/codeblock ')]" mode="block-style">
    <w:pStyle w:val="HTMLPreformatted"/>
  </xsl:template>

  <!-- monospaced -->
  <xsl:template match="*[contains(@class, ' pr-d/apiname ')]" mode="inline-style">
    <w:rStyle w:val="HTMLTypewriter"/>
  </xsl:template>
  
  <!-- monospaced -->
  <xsl:template match="*[contains(@class, ' pr-d/codeph ')]" mode="inline-style">
    <w:rStyle w:val="HTMLTypewriter"/>
  </xsl:template> 

</xsl:stylesheet>
