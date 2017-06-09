<?xml version="1.0" encoding="UTF-8" ?>
<xsl:stylesheet version="2.0" xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
  xmlns:mml="http://www.w3.org/1998/Math/MathML" xmlns:xs="http://www.w3.org/2001/XMLSchema"
  xmlns:m="http://schemas.openxmlformats.org/officeDocument/2006/math"
  xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main"
  xmlns:x="com.elovirta.ooxml" exclude-result-prefixes="mml x xs">

  <xsl:template match="mml:math">
    <xsl:variable name="content" as="node()*">
      <xsl:apply-templates mode="add-space"/>
    </xsl:variable>
    <xsl:choose>
      <xsl:when test="@display = 'block'">
        <m:oMathPara>
          <m:oMath>
            <xsl:apply-templates select="$content"/>
          </m:oMath>
        </m:oMathPara>
      </xsl:when>
      <xsl:otherwise>
        <m:oMath>
          <xsl:apply-templates select="$content"/>
        </m:oMath>
      </xsl:otherwise>
    </xsl:choose>
  </xsl:template>

  <xsl:template match="mml:mi | mml:mo | mml:ms | mml:mn" mode="add-space">
    <xsl:copy>
      <xsl:apply-templates select="node() | @*" mode="#current"/>
    </xsl:copy>
    <!-- XXX: Add space between elements to disable grouping -->
    <xsl:if
      test="
        following-sibling::*[1][self::mml:mi | self::mml:mo | self::mml:ms | self::mml:mn] and
        exists(parent::mml:math | parent::mml:mrow)">
      <mml:mspace width="0"/>
    </xsl:if>
  </xsl:template>
  
  <xsl:template match="mml:maction" mode="add-space">
    <xsl:choose>
      <xsl:when test="@actiontype = 'toggle'">
        <xsl:variable name="position" as="xs:integer" select="(@selection, 1)[1]"/>
        <xsl:apply-templates select="*[$position]" mode="#current"/>
      </xsl:when>
      <xsl:otherwise>
        <xsl:apply-templates select="*[1]" mode="#current"/>
      </xsl:otherwise>
    </xsl:choose>
  </xsl:template>

  <xsl:template match="node() | @*" mode="add-space" priority="-10">
    <xsl:copy>
      <xsl:apply-templates select="node() | @*" mode="#current"/>
    </xsl:copy>
  </xsl:template>

  <xsl:template name="OutputText">
    <xsl:param name="sInput" as="xs:string"/>
    <!-- TODO: This should be done as preprocessing -->
    <xsl:value-of
      select="replace(translate($sInput, '&#xa0;&#x2062;&#x200B;', ' '), '&#x2A75;', '==')"/>
  </xsl:template>

  <!-- Template that determines whether or the given node 
	     ndCur is a token element that doesn't have an mglyph as 
			 a child.
	-->
  <xsl:function name="x:FNonGlyphToken" as="xs:boolean">
    <xsl:param name="ndCur" as="element()?"/>
    <xsl:sequence
      select="
        exists(
        $ndCur/self::mml:mi[not(mml:mglyph)] |
        $ndCur/self::mml:mn[not(mml:mglyph)] |
        $ndCur/self::mml:mo[not(mml:mglyph)] |
        $ndCur/self::mml:ms[not(mml:mglyph)] |
        $ndCur/self::mml:mtext[not(mml:mglyph)])"
    />
  </xsl:function>

  <!-- Template used to determine if the current token element (ndCur) is the beginning of a run. 
			 A token element is the beginning of if:
			 
			 the count of preceding elements is 0 
			 or 
			 the directory preceding element is not a non-glyph token.
	-->
  <xsl:function name="x:isStartOfRun" as="xs:boolean">
    <xsl:param name="ndCur" as="element()?"/>
    <xsl:variable name="fPrecSibNonGlyphToken" as="xs:boolean"
      select="x:FNonGlyphToken($ndCur/preceding-sibling::*[1])"/>
    <xsl:sequence select="empty($ndCur/preceding-sibling::*) or not($fPrecSibNonGlyphToken)"/>
  </xsl:function>


  <!-- Template that determines if ndCur is the argument of an nary expression. 
			 
			 ndCur is the argument of an nary expression if:
			 
			 1.  The preceding sibling is one of the following:  munder, mover, msub, msup, munder, msubsup, munderover
			 and
			 2.  The preceding sibling's child is an nary char as specified by the template "isNary"
	-->
  <xsl:function name="x:FIsNaryArgument" as="xs:boolean">
    <xsl:param name="ndCur" as="element()?"/>

    <xsl:variable name="fNary" as="xs:boolean"
      select="x:isNary($ndCur/preceding-sibling::*[1]/*[1])"/>
    <xsl:sequence
      select="$ndCur/preceding-sibling::*[1][self::mml:munder | self::mml:mover | self::mml:munderover | self::mml:msub | self::mml:msup | self::mml:msubsup] and $fNary"
    />
  </xsl:function>

  <!-- %%Template: mml:mrow | mml:mstyle

		 if this row is the next sibling of an n-ary (i.e. any of 
         mover, munder, munderover, msupsub, msup, or msub with 
         the base being an n-ary operator) then ignore this. Otherwise
         pass through -->
  <xsl:template match="mml:mrow | mml:mstyle">
    <xsl:if test="not(x:FIsNaryArgument(.))">
      <xsl:choose>
        <xsl:when test="x:FLinearFrac(.)">
          <xsl:call-template name="MakeLinearFraction">
            <xsl:with-param name="ndCur" select="."/>
          </xsl:call-template>
        </xsl:when>
        <xsl:otherwise>
          <xsl:choose>
            <xsl:when test="x:isFunction(.)">
              <xsl:call-template name="WriteFunc"/>
            </xsl:when>
            <xsl:otherwise>
              <xsl:apply-templates select="*"/>
            </xsl:otherwise>
          </xsl:choose>
        </xsl:otherwise>
      </xsl:choose>
    </xsl:if>
  </xsl:template>

  <xsl:template
    match="
      mml:mi[not(mml:mglyph)] |
      mml:mn[not(mml:mglyph)] |
      mml:mo[not(mml:mglyph)] |
      mml:ms[not(mml:mglyph)] |
      mml:mtext[not(mml:mglyph)]">

    <!-- tokens with mglyphs as children are tranformed
			 in a different manner than "normal" token elements.  
			 Where normal token elements are token elements that
			 contain only text -->
    <xsl:variable name="fStartOfRun" as="xs:boolean" select="x:isStartOfRun(.)"/>

    <!--In MathML, successive characters that are all part of one string are sometimes listed as separate 
			tags based on their type (identifier (mi), name (mn), operator (mo), quoted (ms), literal text (mtext)), 
			where said tags act to link one another into one logical run.  In order to wrap the text of successive mi's, 
			mn's, and mo's into one m:t, we need to denote where a run begins.  The beginning of a run is the first mi, mn, 
			or mo whose immediately preceding sibling either doesn't exist or is something other than a "normal" mi, mn, mo, 
			ms, or mtext tag-->


    <xsl:variable name="fShouldCollect" as="xs:boolean">
      <!-- If this mi/mo/mn/ms . . . is part the numerator or denominator of a linear fraction, then don't collect. -->
      <xsl:variable name="fLinearFracParent" as="xs:boolean" select="x:FLinearFrac(parent::*)"/>
      <!-- If this mi/mo/mn/ms . . . is part of the name of a function, then don't collect. -->
      <xsl:variable name="fFunctionName" as="xs:boolean" select="x:isFunction(parent::*)"/>
      <xsl:sequence
        select="
          (not($fLinearFracParent) and not($fFunctionName)) and
          (parent::mml:mrow or parent::mml:mstyle or
          parent::mml:msqrt or parent::mml:menclose or
          parent::mml:math or parent::mml:mphantom or
          parent::mml:mtd or parent::mml:maction)"
      />
    </xsl:variable>

    <!--In MathML, the meaning of the different parts that make up mathematical structures, such as a fraction 
			having a numerator and a denominator, is determined by the relative order of those different parts.  
			For instance, In a fraction, the numerator is the first child and the denominator is the second child.  
			To allow for more complex structures, MathML allows one to link a group of mi, mn, and mo's together 
			using the mrow, or mstyle tags.  The mi, mn, and mo's found within any of the above tags are considered 
			one run.  Therefore, if the parent of any mi, mn, or mo is found to be an mrow or mstyle, then the contiguous 
			mi, mn, and mo's will be considered one run.-->
    <xsl:choose>
      <xsl:when test="$fShouldCollect">
        <xsl:choose>
          <xsl:when test="$fStartOfRun">
            <!--If this is the beginning of the run, pass all run attributes to CreateRunWithSameProp.-->
            <xsl:call-template name="CreateRunWithSameProp">
              <xsl:with-param name="mathbackground" select="@mathbackground"/>
              <xsl:with-param name="mathcolor" select="@mathcolor"/>
              <xsl:with-param name="mathvariant" select="@mathvariant"/>
              <!-- Deprecated -->
              <xsl:with-param name="color" select="@color"/>
              <xsl:with-param name="font-family" select="@fontfamily"/>
              <!-- Deprecated -->
              <xsl:with-param name="fontsize" select="@fontsize"/>
              <!-- Deprecated -->
              <xsl:with-param name="fontstyle" select="@fontstyle"/>
              <!-- Deprecated -->
              <xsl:with-param name="fontweight" select="@fontweight"/>
              <xsl:with-param name="mathsize" select="@mathsize"/>
              <xsl:with-param name="ndTokenFirst" select="."/>
            </xsl:call-template>
          </xsl:when>
        </xsl:choose>
      </xsl:when>
      <xsl:otherwise>
        <!--Only one element will be part of run-->
        <m:r>
          <!--Create Run Properties based on current node's attributes-->
          <xsl:call-template name="CreateRunProp">
            <xsl:with-param name="mathvariant" select="@mathvariant"/>
            <!-- Deprecated -->
            <xsl:with-param name="fontstyle" select="@fontstyle"/>
            <!-- Deprecated -->
            <xsl:with-param name="fontweight" select="@fontweight"/>
            <xsl:with-param name="mathcolor" select="@mathcolor"/>
            <xsl:with-param name="mathsize" select="@mathsize"/>
            <!-- Deprecated -->
            <xsl:with-param name="color" select="@color"/>
            <!-- Deprecated -->
            <xsl:with-param name="fontsize" select="@fontsize"/>
            <xsl:with-param name="ndCur" select="."/>
            <xsl:with-param name="fNor" select="x:FNor(.)"/>
          </xsl:call-template>
          <m:t>
            <xsl:call-template name="OutputText">
              <xsl:with-param name="sInput" select="normalize-space(.)"/>
            </xsl:call-template>
          </m:t>
        </m:r>
      </xsl:otherwise>
    </xsl:choose>
  </xsl:template>

  <!-- %%Template: CreateRunWithSameProp
	-->
  <xsl:template name="CreateRunWithSameProp">
    <xsl:param name="mathbackground" as="xs:string?"/>
    <xsl:param name="mathcolor" as="xs:string?"/>
    <xsl:param name="mathvariant" as="xs:string?"/>
    <xsl:param name="color" as="xs:string?"/>
    <xsl:param name="font-family" as="xs:string?"/>
    <xsl:param name="fontsize" as="xs:string?"/>
    <xsl:param name="fontstyle" as="xs:string?"/>
    <xsl:param name="fontweight" as="xs:string?"/>
    <xsl:param name="mathsize" as="xs:string?"/>
    <xsl:param name="ndTokenFirst" as="element()"/>

    <!--Given mathcolor, color, mstyle's (ancestor) color, and precedence of 
			said attributes, determine the actual color of the current run-->
    <xsl:variable name="sColorPropCur" as="xs:string?">
      <xsl:choose>
        <xsl:when test="$mathcolor != ''">
          <xsl:value-of select="$mathcolor"/>
        </xsl:when>
        <xsl:when test="$color != ''">
          <xsl:value-of select="$color"/>
        </xsl:when>
        <xsl:when test="$ndTokenFirst/ancestor::mml:mstyle[@color][1]/@color != ''">
          <xsl:value-of select="$ndTokenFirst/ancestor::mml:mstyle[@color][1]/@color"/>
        </xsl:when>
      </xsl:choose>
    </xsl:variable>

    <!--Given mathsize, and fontsize and precedence of said attributes, 
			determine the actual font size of the current run-->
    <xsl:variable name="sSzCur" as="xs:string?">
      <xsl:choose>
        <xsl:when test="$mathsize != ''">
          <xsl:value-of select="$mathsize"/>
        </xsl:when>
        <xsl:when test="$fontsize != ''">
          <xsl:value-of select="$fontsize"/>
        </xsl:when>
      </xsl:choose>
    </xsl:variable>

    <!--Given mathvariant, fontstyle, and fontweight, and precedence of 
			the attributes, determine the actual font of the current run-->
    <xsl:variable name="sFontCur" as="xs:string">
      <xsl:call-template name="GetFontCur">
        <xsl:with-param name="mathvariant" select="$mathvariant"/>
        <xsl:with-param name="fontstyle" select="$fontstyle"/>
        <xsl:with-param name="fontweight" select="$fontweight"/>
        <xsl:with-param name="ndCur" select="$ndTokenFirst"/>
      </xsl:call-template>
    </xsl:variable>

    <!-- The omml equivalent structure for mml:mtext is an omml run with the run property m:nor (normal) set.
         Therefore, we can only collect mtexts with  other mtext elements.  Suppose the $ndTokenFirst is an 
         mml:mtext, then if any of its following siblings are to be grouped, they must also be mml:text elements.  
         The inverse is also true, suppose the $ndTokenFirst isn't an mml:mtext, then if any of its following siblings 
         are to be grouped with $ndTokenFirst, they can't be mml:mtext elements-->
    <xsl:variable name="fNdTokenFirstIsMText" as="xs:boolean"
      select="exists($ndTokenFirst/self::mml:mtext)"/>

    <!--In order to determine the length of the run, we will find the number of nodes before the inital node in the run and
			the number of nodes before the first node that DOES NOT belong to the current run.  The number of nodes that will
			be printed is One Less than the difference between the latter and the former-->

    <!--Find index of current node-->
    <xsl:variable name="nndBeforeFirst" select="count($ndTokenFirst/preceding-sibling::*)"
      as="xs:integer"/>

    <!--Find index of next change in run properties.
		
		    The basic idea is that we want to find the position of the last node in the longest 
				sequence of nodes, starting from ndTokenFirst, that can be grouped into a run.  For
				example, nodes A and B can be grouped together into the same run iff they have the same 
				props.
				
				To accomplish this grouping, we want to find the next sibling to ndTokenFirst that shouldn't be 
				included in the run of text.  We do this by counting the number of elements that precede the first
				such element that doesn't belong.  The xpath that accomplishes this is below.
				    
						Count the number of siblings the precede the first element after ndTokenFirst that shouldn't belong.
						count($ndTokenFirst/following-sibling::*[ . . . ][1]/preceding-sibling::*)
						
				Now, the hard part to this is what is represented by the '. . .' above.  This conditional expression is 
				defining what elements *don't* belong to the current run.  The conditions are as follows:
				
				The element is not a token element (mi, mn, mo, ms, or mtext)
				
				or
				
				The token element contains a glyph child (this is handled separately).
				
				or
				
				The token is an mtext and the run didn't start with an mtext, or the token isn't an mtext and the run started 
				with an mtext.  We do this check because mtext transforms into an omml m:nor property, and thus, these mtext
				token elements need to be grouped separately from other token elements.
				
				// We do an or not( . . . ), because it was easier to define what token elements match than how they don't match.
				// Thus, this inner '. . .' defines how token attributes equate to one another.  We add the 'not' outside of to accomplish
				// the goal of the outer '. . .', which is the find the next element that *doesn't* match.
				or not(
				   The background colors match.
					 
					 and
					 
							The current font (sFontCur) matches the mathvariant
					 
							or
							
							sFontCur is normal and matches the current font characteristics
							
							or 
							
							sFontCur is italic and matches the current font characteristics
							
							or 
							
							. . .
				
					 and
					 
					 The font family matches the current font family.
					 ) // end of not().-->
    <xsl:variable name="nndBeforeLim" as="xs:integer"
      select="
        count($ndTokenFirst/following-sibling::*
        [(not(self::mml:mi) and not(self::mml:mn) and not(self::mml:mo) and not(self::mml:ms) and not(self::mml:mtext))
        or
        (self::mml:mi[mml:mglyph] or self::mml:mn[mml:mglyph] or self::mml:mo[mml:mglyph] or self::mml:ms[mml:mglyph] or self::mml:mtext[mml:mglyph])
        or
        (($fNdTokenFirstIsMText and not(self::mml:mtext)) or (not($fNdTokenFirstIsMText) and self::mml:mtext))
        or
        not(
        ((($sFontCur = @mathvariant)
        or
        ($sFontCur = 'normal'
        and ((@mathvariant = 'normal')
        or (empty(@mathvariant)
        and (
        ((@fontstyle = 'normal') and (not(@fontweight = 'bold')))
        or (self::mml:mi and string-length(normalize-space(.)) gt 1)
        or (self::mml:mn and string(number(self::mml:mn/text())) = 'NaN')
        )
        )
        )
        )
        or
        ($sFontCur = 'italic'
        and ((@mathvariant = 'italic')
        or (empty(@mathvariant)
        and (
        ((@fontstyle = 'italic') and (not(@fontweight = 'bold')))
        or
        ((self::mml:mn and string(number(self::mml:mn/text())) != 'NaN')
        or self::mml:mo
        or (self::mml:mi and string-length(normalize-space(.)) &lt;= 1)
        )
        )
        )
        )
        )
        or
        ($sFontCur = 'bold'
        and ((@mathvariant = 'bold')
        or (empty(@mathvariant)
        and (
        ((@fontweight = 'bold')
        and ((@fontstyle = 'normal') or (self::mml:mi and string-length(normalize-space(.)) &lt;= 1))
        )
        )
        )
        )
        )
        or
        (($sFontCur = 'bi' or $sFontCur = 'bold-italic')
        and (
        (@mathvariant = 'bold-italic')
        or (empty(@mathvariant)
        and (
        ((@fontweight = 'bold') and (@fontstyle = 'italic'))
        or ((@fontweight = 'bold')
        and (self::mml:mn
        or self::mml:mo
        or (self::mml:mi and string-length(normalize-space(.)) &lt;= 1)))
        )
        )
        )
        )
        or
        (($sFontCur = ''
        and (
        (empty(@mathvariant)
        and empty(@fontstyle)
        and empty(@fontweight)
        )
        or
        (@mathvariant = 'italic')
        or (
        (empty(@mathvariant))
        and (
        (((@fontweight = 'normal')
        and (@fontstyle = 'italic'))
        )
        or
        ((empty(@fontweight)))
        and (@fontstyle = 'italic')
        or
        ((empty(@fontweight)))
        and empty(@fontstyle)
        )
        )
        )
        ))
        or
        ($sFontCur = 'normal'
        and ((self::mml:mi
        and empty(@mathvariant)
        and empty(@fontstyle)
        and empty(@fontweight)
        and (string-length(normalize-space(.)) gt 1)
        )
        or ((self::mml:ms or self::mml:mtext)
        and empty(@mathvariant)
        and (empty(@fontstyle) or @fontstyle)
        and empty(@fontstyle)
        and (empty(@fontweight) or @fontweight)
        )
        )
        )
        )
        and
        (($font-family = @fontfamily)
        or (($font-family = '' or not($font-family))
        and empty(@fontfamily)
        )
        )
        ))
        ][1]/preceding-sibling::*)"/>

    <xsl:variable name="cndRun" select="$nndBeforeLim - $nndBeforeFirst" as="xs:integer"/>

    <!--Contiguous groups of like-property mi, mn, and mo's are separated by non- mi, mn, mo tags, or mi,mn, or mo
			tags with different properties.  nndBeforeLim is the number of nodes before the next tag which separates contiguous 
			groups of like-property mi, mn, and mo's.  Knowing this delimiting tag allows for the aggregation of the correct 
			number of mi, mn, and mo tags.-->
    <m:r>

      <!--The beginning and ending of the current run has been established. Now we should open a run element-->
      <xsl:choose>

        <!--If cndRun > 0, then there is a following diffrent prop, or non- Token, 
						although there may or may not have been a preceding different prop, or non-
						Token-->
        <xsl:when test="$cndRun gt 0">
          <xsl:call-template name="CreateRunProp">
            <xsl:with-param name="mathvariant" select="$mathvariant"/>
            <xsl:with-param name="fontstyle" select="$fontstyle"/>
            <xsl:with-param name="fontweight" select="$fontweight"/>
            <xsl:with-param name="mathcolor" select="$mathcolor"/>
            <xsl:with-param name="mathsize" select="$mathsize"/>
            <xsl:with-param name="color" select="$color"/>
            <xsl:with-param name="fontsize" select="$fontsize"/>
            <xsl:with-param name="ndCur" select="$ndTokenFirst"/>
            <xsl:with-param name="fNor" select="x:FNor($ndTokenFirst)"/>
          </xsl:call-template>
          <m:t>
            <xsl:call-template name="OutputText">
              <xsl:with-param name="sInput">
                <xsl:choose>
                  <xsl:when test="$ndTokenFirst/self::mml:ms">
                    <xsl:call-template name="OutputMs">
                      <xsl:with-param name="msCur" select="$ndTokenFirst"/>
                    </xsl:call-template>
                  </xsl:when>
                  <xsl:otherwise>
                    <xsl:value-of select="normalize-space($ndTokenFirst)"/>
                  </xsl:otherwise>
                </xsl:choose>
                <xsl:for-each select="$ndTokenFirst/following-sibling::*[position() lt $cndRun]">
                  <xsl:choose>
                    <xsl:when test="self::mml:ms">
                      <xsl:call-template name="OutputMs">
                        <xsl:with-param name="msCur" select="."/>
                      </xsl:call-template>
                    </xsl:when>
                    <xsl:otherwise>
                      <xsl:value-of select="normalize-space(.)"/>
                    </xsl:otherwise>
                  </xsl:choose>
                </xsl:for-each>
              </xsl:with-param>
            </xsl:call-template>
          </m:t>
        </xsl:when>
        <xsl:otherwise>

          <!--if cndRun lt;= 0, then iNextNonToken = 0, 
						and iPrecNonToken gt;= 0.  In either case, b/c there 
						is no next different property or non-Token 
						(which is implied by the nndBeforeLast being equal to 0) 
						you can put all the remaining mi, mn, and mo's into one 
						group.-->
          <xsl:call-template name="CreateRunProp">
            <xsl:with-param name="mathvariant" select="$mathvariant"/>
            <xsl:with-param name="fontstyle" select="$fontstyle"/>
            <xsl:with-param name="fontweight" select="$fontweight"/>
            <xsl:with-param name="mathcolor" select="$mathcolor"/>
            <xsl:with-param name="mathsize" select="$mathsize"/>
            <xsl:with-param name="color" select="$color"/>
            <xsl:with-param name="fontsize" select="$fontsize"/>
            <xsl:with-param name="ndCur" select="$ndTokenFirst"/>
            <xsl:with-param name="fNor" select="x:FNor($ndTokenFirst)"/>
          </xsl:call-template>
          <m:t>

            <!--Create the Run, first output current, then in a 
							for-each, because all the following siblings are
							mn, mi, and mo's that conform to the run's properties,
							group them together-->
            <xsl:call-template name="OutputText">
              <xsl:with-param name="sInput">
                <xsl:choose>
                  <xsl:when test="$ndTokenFirst/self::mml:ms">
                    <xsl:call-template name="OutputMs">
                      <xsl:with-param name="msCur" select="$ndTokenFirst"/>
                    </xsl:call-template>
                  </xsl:when>
                  <xsl:otherwise>
                    <xsl:value-of select="normalize-space($ndTokenFirst)"/>
                  </xsl:otherwise>
                </xsl:choose>
                <xsl:for-each
                  select="$ndTokenFirst/following-sibling::*[self::mml:mi or self::mml:mn or self::mml:mo or self::mml:ms or self::mml:mtext]">
                  <xsl:choose>
                    <xsl:when test="self::mml:ms">
                      <xsl:call-template name="OutputMs">
                        <xsl:with-param name="msCur" select="."/>
                      </xsl:call-template>
                    </xsl:when>
                    <xsl:otherwise>
                      <xsl:value-of select="normalize-space(.)"/>
                    </xsl:otherwise>
                  </xsl:choose>
                </xsl:for-each>
              </xsl:with-param>
            </xsl:call-template>
          </m:t>
        </xsl:otherwise>
      </xsl:choose>
    </m:r>

    <!--The run was terminated by an mi, mn, mo, ms, or mtext with different properties, 
				therefore, call-template CreateRunWithSameProp, using cndRun+1 node as new start node-->
    <xsl:if
      test="
        $nndBeforeLim != 0
        and ($ndTokenFirst/following-sibling::*[$cndRun]/self::mml:mi or
        $ndTokenFirst/following-sibling::*[$cndRun]/self::mml:mn or
        $ndTokenFirst/following-sibling::*[$cndRun]/self::mml:mo or
        $ndTokenFirst/following-sibling::*[$cndRun]/self::mml:ms or
        $ndTokenFirst/following-sibling::*[$cndRun]/self::mml:mtext)
        and (count($ndTokenFirst/following-sibling::*[$cndRun]/mml:mglyph) = 0)">
      <xsl:call-template name="CreateRunWithSameProp">
        <xsl:with-param name="mathbackground"
          select="$ndTokenFirst/following-sibling::*[$cndRun]/@mathbackground"/>
        <xsl:with-param name="mathcolor"
          select="$ndTokenFirst/following-sibling::*[$cndRun]/@mathcolor"/>
        <xsl:with-param name="mathvariant"
          select="$ndTokenFirst/following-sibling::*[$cndRun]/@mathvariant"/>
        <xsl:with-param name="color" select="$ndTokenFirst/following-sibling::*[$cndRun]/@color"/>
        <xsl:with-param name="font-family"
          select="$ndTokenFirst/following-sibling::*[$cndRun]/@fontfamily"/>
        <xsl:with-param name="fontsize"
          select="$ndTokenFirst/following-sibling::*[$cndRun]/@fontsize"/>
        <xsl:with-param name="fontstyle"
          select="$ndTokenFirst/following-sibling::*[$cndRun]/@fontstyle"/>
        <xsl:with-param name="fontweight"
          select="$ndTokenFirst/following-sibling::*[$cndRun]/@fontweight"/>
        <xsl:with-param name="mathsize"
          select="$ndTokenFirst/following-sibling::*[$cndRun]/@mathsize"/>
        <xsl:with-param name="ndTokenFirst" select="$ndTokenFirst/following-sibling::*[$cndRun]"/>
      </xsl:call-template>
    </xsl:if>
  </xsl:template>

  <!-- %%Template: FNor
				 Given the context of ndCur, determine if ndCur should be omml's normal style.
	-->
  <xsl:function name="x:FNor" as="xs:boolean">
    <xsl:param name="ndCur" as="element()"/>
    <!-- Is the current node an mml:mtext, or if this is an mglyph whose parent is 
           an mml:mtext. -->
    <!-- Override mi formatting to disable Word auto-formatting -->
    <xsl:sequence
      select="
        $ndCur/self::mml:mtext or
        ($ndCur/self::mml:mglyph/parent::mml:mtext) or
        $ndCur/self::mml:mi"
    />
  </xsl:function>


  <!-- %%Template: CreateRunProp
	-->
  <xsl:template name="CreateRunProp">
    <xsl:param name="mathbackground" as="xs:string?"/>
    <xsl:param name="mathcolor" as="xs:string?"/>
    <xsl:param name="mathvariant" as="xs:string?"/>
    <xsl:param name="color" as="xs:string?"/>
    <xsl:param name="font-family" as="xs:string?"/>
    <xsl:param name="fontsize" as="xs:string?"/>
    <xsl:param name="fontstyle" as="xs:string?"/>
    <xsl:param name="fontweight" as="xs:string?"/>
    <xsl:param name="mathsize" as="xs:string?"/>
    <xsl:param name="ndCur" as="node()?"/>
    <xsl:param name="fontfamily" as="xs:string?"/>
    <xsl:param name="fNor" as="xs:boolean"/>
    <xsl:variable name="mstyleColor" select="$ndCur/ancestor::mml:mstyle[@color][1]/@color"
      as="xs:string?"/>
    <xsl:call-template name="CreateMathRPR">
      <xsl:with-param name="mathvariant" select="$mathvariant"/>
      <xsl:with-param name="fontstyle" select="$fontstyle"/>
      <xsl:with-param name="fontweight" select="$fontweight"/>
      <xsl:with-param name="ndCur" select="$ndCur"/>
      <xsl:with-param name="fNor" select="$fNor"/>
    </xsl:call-template>
    <!-- Exception for characters not supported by Times New Roman -->
    <xsl:choose xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main">
      <xsl:when test=". = '⋮'">
        <w:rFonts w:ascii="Cambria Math" w:hAnsi="Cambria Math"/>
      </xsl:when>
    </xsl:choose>
  </xsl:template>

  <!-- %%Template: CreateMathRPR
	-->
  <xsl:template name="CreateMathRPR">
    <xsl:param name="mathvariant" as="xs:string?"/>
    <xsl:param name="fontstyle" as="xs:string?"/>
    <xsl:param name="fontweight" as="xs:string?"/>
    <xsl:param name="ndCur" as="node()?"/>
    <xsl:param name="fNor" as="xs:boolean"/>
    <xsl:param name="styles" as="element()*" tunnel="yes">
      <xsl:apply-templates select="ancestor::*" mode="inline-style"/>
    </xsl:param>
    <xsl:variable name="sFontCur" as="xs:string">
      <xsl:call-template name="GetFontCur">
        <xsl:with-param name="mathvariant" select="$mathvariant"/>
        <xsl:with-param name="fontstyle" select="$fontstyle"/>
        <xsl:with-param name="fontweight" select="$fontweight"/>
        <xsl:with-param name="ndCur" select="$ndCur"/>
      </xsl:call-template>
    </xsl:variable>
    <xsl:variable name="mrPr" as="element()*">
      <xsl:call-template name="CreateMathScrStyProp">
        <xsl:with-param name="font" select="$sFontCur"/>
        <xsl:with-param name="fNor" select="$fNor"/>
      </xsl:call-template>
    </xsl:variable>
    <xsl:if test="exists($mrPr)">
      <m:rPr>
        <xsl:copy-of select="$mrPr"/>
      </m:rPr>
    </xsl:if>
    <xsl:variable name="font" as="element()*">
      <!--
      <w:rFonts w:ascii="Cambria Math" w:hAnsi="Cambria Math"/>
      -->
      <xsl:if test="$ndCur/self::mml:mi and empty($mathvariant)">
        <w:i/>
      </xsl:if>
      <xsl:choose>
        <xsl:when test="$sFontCur = 'bold'">
          <w:b/>
        </xsl:when>
        <xsl:when test="$sFontCur = 'italic'">
          <w:i/>
        </xsl:when>
        <xsl:when test="$sFontCur = 'script'"> </xsl:when>
        <xsl:when test="$sFontCur = 'bold-script'">
          <w:b/>
        </xsl:when>
        <xsl:when test="$sFontCur = 'double-struck'"> </xsl:when>
        <xsl:when test="$sFontCur = 'fraktur'"> </xsl:when>
        <xsl:when test="$sFontCur = 'bold-fraktur'">
          <w:b/>
        </xsl:when>
        <xsl:when test="$sFontCur = 'sans-serif'"> </xsl:when>
        <xsl:when test="$sFontCur = 'bold-sans-serif'">
          <w:b/>
        </xsl:when>
        <xsl:when test="$sFontCur = 'sans-serif-italic'"> </xsl:when>
        <xsl:when test="$sFontCur = 'sans-serif-bold-italic'">
          <w:b/>
          <w:i/>
        </xsl:when>
        <xsl:when test="$sFontCur = 'monospace'"/>
        <xsl:when test="$sFontCur = 'bi' or $sFontCur = 'bold-italic'">
          <w:b/>
          <w:i/>
        </xsl:when>
      </xsl:choose>
    </xsl:variable>
    <xsl:if test="exists(($styles, $font))">
      <w:rPr>
        <xsl:for-each-group select="$styles, $font" group-by="name()">
          <xsl:copy-of select="current-group()[1]"/>
        </xsl:for-each-group>
      </w:rPr>
    </xsl:if>
  </xsl:template>

  <!-- %%Template: GetFontCur
	-->
  <xsl:template name="GetFontCur" as="xs:string">
    <xsl:param name="ndCur" as="node()?"/>
    <xsl:param name="mathvariant" as="xs:string?"/>
    <xsl:param name="fontstyle" as="xs:string?"/>
    <xsl:param name="fontweight" as="xs:string?"/>
    <xsl:choose>
      <xsl:when test="$mathvariant != ''">
        <xsl:value-of select="$mathvariant"/>
      </xsl:when>
      <xsl:when test="not($ndCur)">
        <xsl:value-of select="'italic'"/>
      </xsl:when>
      <xsl:when test="$ndCur/self::mml:mi">
        <xsl:value-of select="'italic'"/>
      </xsl:when>
      <!--xsl:when
        test="($ndCur/self::mml:mi and (string-length(normalize-space($ndCur)) &lt;= 1))
								      or ($ndCur/self::mml:mn and string(number($ndCur/text())) != 'NaN')
								      or ($ndCur/self::mml:mo)">

        <!- - The default for the above three cases is fontstyle=italic fontweight=normal.- ->
        <xsl:choose>
          <xsl:when test="$fontstyle = 'normal' and $fontweight = 'bold'">
            <!- - In omml, a sty of 'b' (which is what bold is translated into)
						     implies a normal fontstyle - ->
            <xsl:value-of select="'bold'"/>
          </xsl:when>
          <xsl:when test="$fontstyle = 'normal'">
            <xsl:value-of select="'normal'"/>
          </xsl:when>
          <xsl:when test="$fontstyle = 'italic'">
            <xsl:value-of select="'italic'"/>
          </xsl:when>
          <xsl:when test="$fontweight = 'bold'">
            <xsl:value-of select="'bi'"/>
          </xsl:when>
          <xsl:otherwise>
            <xsl:value-of select="'normal'"/>
          </xsl:otherwise>
        </xsl:choose>
      </xsl:when-->
      <xsl:otherwise>
        <!--Default is fontweight = 'normal' and fontstyle='normal'-->
        <xsl:choose>
          <xsl:when test="$fontstyle = 'italic' and $fontweight = 'bold'">
            <xsl:value-of select="'bi'"/>
          </xsl:when>
          <xsl:when test="$fontstyle = 'italic'">
            <xsl:value-of select="'italic'"/>
          </xsl:when>
          <xsl:when test="$fontweight = 'bold'">
            <xsl:value-of select="'bold'"/>
          </xsl:when>
          <xsl:otherwise>
            <xsl:value-of select="'normal'"/>
          </xsl:otherwise>
        </xsl:choose>
      </xsl:otherwise>
    </xsl:choose>
  </xsl:template>


  <!-- %%Template: CreateMathScrStyProp
	-->
  <xsl:template name="CreateMathScrStyProp" as="element()*">
    <xsl:param name="font" as="xs:string"/>
    <xsl:param name="fNor" select="false()" as="xs:boolean"/>
    <xsl:if test="$fNor">
      <m:nor/>
    </xsl:if>
    <xsl:choose>
      <xsl:when test="$font = 'normal' and not($fNor)">
        <m:sty m:val="p"/>
      </xsl:when>
      <xsl:when test="$font = 'bold'">
        <m:sty m:val="b"/>
      </xsl:when>
      <xsl:when test="$font = 'italic'">
        <m:sty m:val="i"/>
      </xsl:when>
      <xsl:when test="$font = 'script'">
        <m:scr m:val="script"/>
      </xsl:when>
      <xsl:when test="$font = 'bold-script'">
        <m:scr m:val="script"/>
        <m:sty m:val="b"/>
      </xsl:when>
      <xsl:when test="$font = 'double-struck'">
        <m:scr m:val="double-struck"/>
        <m:sty m:val="p"/>
      </xsl:when>
      <xsl:when test="$font = 'fraktur'">
        <m:scr m:val="fraktur"/>
        <m:sty m:val="p"/>
      </xsl:when>
      <xsl:when test="$font = 'bold-fraktur'">
        <m:scr m:val="fraktur"/>
        <m:sty m:val="b"/>
      </xsl:when>
      <xsl:when test="$font = 'sans-serif'">
        <m:scr m:val="sans-serif"/>
        <m:sty m:val="p"/>
      </xsl:when>
      <xsl:when test="$font = 'bold-sans-serif'">
        <m:scr m:val="sans-serif"/>
        <m:sty m:val="b"/>
      </xsl:when>
      <xsl:when test="$font = 'sans-serif-italic'">
        <m:scr m:val="sans-serif"/>
      </xsl:when>
      <xsl:when test="$font = 'sans-serif-bold-italic'">
        <m:scr m:val="sans-serif"/>
        <m:sty m:val="bi"/>
      </xsl:when>
      <xsl:when test="$font = 'monospace'"/>
      <!-- We can't do monospace, so leave empty -->
      <xsl:when test="$font = 'bold'">
        <m:sty m:val="b"/>
      </xsl:when>
      <xsl:when test="$font = 'bi' or $font = 'bold-italic'">
        <m:sty m:val="bi"/>
      </xsl:when>
    </xsl:choose>
  </xsl:template>

  <xsl:function name="x:FBar" as="xs:boolean">
    <xsl:param name="sLineThickness" as="xs:string?"/>
    <xsl:variable name="sLowerLineThickness" as="xs:string" select="lower-case($sLineThickness)"/>
    <xsl:choose>
      <xsl:when
        test="
          string-length($sLowerLineThickness) = 0
          or $sLowerLineThickness = 'thin'
          or $sLowerLineThickness = 'medium'
          or $sLowerLineThickness = 'thick'">
        <xsl:sequence select="true()"/>
      </xsl:when>
      <xsl:otherwise>
        <xsl:sequence select="x:FStrContainsNonZeroDigit($sLowerLineThickness)"/>
      </xsl:otherwise>
    </xsl:choose>
  </xsl:function>

  <xsl:template match="mml:mfrac">
    <xsl:variable name="fBar" as="xs:boolean" select="x:FBar(@linethickness)"/>

    <m:f>
      <m:fPr>
        <m:type>
          <xsl:attribute name="m:val">
            <xsl:choose>
              <xsl:when test="not($fBar)">noBar</xsl:when>
              <xsl:when test="@bevelled = 'true'">skw</xsl:when>
              <xsl:otherwise>bar</xsl:otherwise>
            </xsl:choose>
          </xsl:attribute>
        </m:type>
      </m:fPr>
      <m:num>
        <xsl:call-template name="CreateArgProp"/>
        <xsl:apply-templates select="*[1]"/>
      </m:num>
      <m:den>
        <xsl:call-template name="CreateArgProp"/>
        <xsl:apply-templates select="*[2]"/>
      </m:den>
    </m:f>
  </xsl:template>

  <xsl:template match="mml:menclose | mml:msqrt">
    <xsl:variable name="sLowerCaseNotation" as="xs:string?"
      select="
        if (@notation) then
          lower-case(@notation)
        else
          ()"/>

    <xsl:choose>
      <!-- Take care of default -->
      <xsl:when
        test="
          $sLowerCaseNotation = 'radical'
          or not($sLowerCaseNotation)
          or $sLowerCaseNotation = ''
          or self::mml:msqrt">
        <m:rad>
          <m:radPr>
            <m:degHide m:val="on"/>
          </m:radPr>
          <m:deg>
            <xsl:call-template name="CreateArgProp"/>
          </m:deg>
          <m:e>
            <xsl:call-template name="CreateArgProp"/>
            <xsl:apply-templates select="*"/>
          </m:e>
        </m:rad>
      </xsl:when>
      <xsl:otherwise>
        <xsl:choose>
          <xsl:when test="$sLowerCaseNotation = 'actuarial' or $sLowerCaseNotation = 'longdiv'"/>
          <xsl:otherwise>
            <m:borderBox>
              <!-- Dealing with more complex notation attribute -->
              <xsl:variable name="fBox" as="xs:boolean">
                <xsl:choose>
                  <!-- Word doesn't have circle and roundedbox concepts, therefore, map both to a 
                       box. -->
                  <xsl:when
                    test="
                      contains($sLowerCaseNotation, 'box')
                      or contains($sLowerCaseNotation, 'circle')
                      or contains($sLowerCaseNotation, 'roundedbox')">
                    <xsl:sequence select="true()"/>
                  </xsl:when>
                  <xsl:otherwise>
                    <xsl:sequence select="false()"/>
                  </xsl:otherwise>
                </xsl:choose>
              </xsl:variable>
              <xsl:variable name="fTop" as="xs:boolean"
                select="contains($sLowerCaseNotation, 'top')"/>
              <xsl:variable name="fBot" as="xs:boolean"
                select="contains($sLowerCaseNotation, 'bottom')"/>
              <xsl:variable name="fLeft" as="xs:boolean"
                select="contains($sLowerCaseNotation, 'left')"/>
              <xsl:variable name="fRight" as="xs:boolean"
                select="contains($sLowerCaseNotation, 'right')"/>
              <xsl:variable name="fStrikeH" as="xs:boolean"
                select="contains($sLowerCaseNotation, 'horizontalstrike')"/>
              <xsl:variable name="fStrikeV" as="xs:boolean"
                select="contains($sLowerCaseNotation, 'verticalstrike')"/>
              <xsl:variable name="fStrikeBLTR" as="xs:boolean"
                select="contains($sLowerCaseNotation, 'updiagonalstrike')"/>
              <xsl:variable name="fStrikeTLBR" as="xs:boolean"
                select="contains($sLowerCaseNotation, 'downdiagonalstrike')"/>

              <!-- Should we create borderBoxPr? 
                   We should if the enclosure isn't Word's default, which is
                   a plain box -->
              <xsl:if
                test="
                  $fStrikeH
                  or $fStrikeV
                  or $fStrikeBLTR
                  or $fStrikeTLBR
                  or (not($fBox)
                  and not($fTop
                  and $fBot
                  and $fLeft
                  and $fRight)
                  )">
                <m:borderBoxPr>
                  <xsl:if test="not($fBox)">
                    <xsl:if test="not($fTop)">
                      <m:hideTop m:val="on"/>
                    </xsl:if>
                    <xsl:if test="not($fBot)">
                      <m:hideBot m:val="on"/>
                    </xsl:if>
                    <xsl:if test="not($fLeft)">
                      <m:hideLeft m:val="on"/>
                    </xsl:if>
                    <xsl:if test="not($fRight)">
                      <m:hideRight m:val="on"/>
                    </xsl:if>
                  </xsl:if>
                  <xsl:if test="$fStrikeH">
                    <m:strikeH m:val="on"/>
                  </xsl:if>
                  <xsl:if test="$fStrikeV">
                    <m:strikeV m:val="on"/>
                  </xsl:if>
                  <xsl:if test="$fStrikeBLTR">
                    <m:strikeBLTR m:val="on"/>
                  </xsl:if>
                  <xsl:if test="$fStrikeTLBR">
                    <m:strikeTLBR m:val="on"/>
                  </xsl:if>
                </m:borderBoxPr>
              </xsl:if>
              <m:e>
                <xsl:call-template name="CreateArgProp"/>
                <xsl:apply-templates select="*"/>
              </m:e>
            </m:borderBox>
          </xsl:otherwise>
        </xsl:choose>
      </xsl:otherwise>
    </xsl:choose>
  </xsl:template>

  <!-- %%Template: CreateArgProp
	-->
  <xsl:template name="CreateArgProp" as="element()?">
    <xsl:if test="not(count(ancestor-or-self::mml:mstyle[@scriptlevel = ('0', '1', '2')]) = 0)">
      <m:argPr>
        <m:scrLvl>
          <xsl:attribute name="m:val"
            select="ancestor-or-self::mml:mstyle[@scriptlevel][1]/@scriptlevel"/>
        </m:scrLvl>
      </m:argPr>
    </xsl:if>
  </xsl:template>

  <xsl:template match="mml:mroot">
    <m:rad>
      <m:radPr>
        <m:degHide m:val="off"/>
      </m:radPr>
      <m:deg>
        <xsl:call-template name="CreateArgProp"/>
        <xsl:apply-templates select="*[2]"/>
      </m:deg>
      <m:e>
        <xsl:call-template name="CreateArgProp"/>
        <xsl:apply-templates select="*[1]"/>
      </m:e>
    </m:rad>
  </xsl:template>

  <!-- MathML has no concept of a linear fraction.  When transforming a linear fraction
       from Omml to MathML, we create the following MathML:
       
       <mml:mrow>
         <mml:mrow>
            // numerator
         </mml:mrow>
         <mml:mo>/</mml:mo>
         <mml:mrow>
            // denominator
         </mml:mrow>
       </mml:mrow>
       
       This template looks for four things:
          1.  ndCur is an mml:mrow
          2.  ndCur has three children
          3.  The second child is an <mml:mo>
          4.  The second child's text is '/'
       
       -->
  <xsl:function name="x:FLinearFrac" as="xs:boolean">
    <xsl:param name="ndCur" as="element()?"/>
    <xsl:variable name="sNdText" as="xs:string" select="normalize-space($ndCur/*[2])"/>

    <xsl:choose>
      <!-- I spy a linear fraction -->
      <xsl:when
        test="
          $ndCur/self::mml:mrow
          and count($ndCur/*) = 3
          and $ndCur/*[2][self::mml:mo]
          and $sNdText = '/'">
        <xsl:sequence select="true()"/>
      </xsl:when>
      <xsl:otherwise>
        <xsl:sequence select="false()"/>
      </xsl:otherwise>
    </xsl:choose>
  </xsl:function>


  <!-- Though presentation mathml can certainly typeset any generic function with the
	     appropriate function operator spacing, presentation MathML has no concept of 
			 a function structure like omml does.  In order to preserve the omml <func> 
			 element, we must establish how an omml <func> element looks in mml.  This 
			 is shown below:
       
       <mml:mrow>
         <mml:mrow>
            // function name
         </mml:mrow>
         <mml:mo>&#x02061;</mml:mo>
         <mml:mrow>
            // function argument
         </mml:mrow>
       </mml:mrow>
       
       This template looks for six things to be true:
					1.  ndCur is an mml:mrow
					2.  ndCur has three children
					3.  The first child is an <mml:mrow>
					4.  The second child is an <mml:mo>
					5.  The third child is an <mml:mrow>
					6.  The second child's text is '&#x02061;'
       -->
  <xsl:function name="x:isFunction" as="xs:boolean">
    <xsl:param name="ndCur" as="element()?"/>
    <xsl:variable name="sNdText" as="xs:string" select="normalize-space($ndCur/*[2])"/>

    <xsl:choose>
      <!-- Is this an omml function -->
      <xsl:when
        test="
          count($ndCur/*) = 3
          and $ndCur/self::*[self::mml:mrow]
          and $ndCur/*[2][self::mml:mo]
          and $sNdText = '&#x02061;'">
        <xsl:sequence select="true()"/>
      </xsl:when>
      <xsl:otherwise>
        <xsl:sequence select="false()"/>
      </xsl:otherwise>
    </xsl:choose>
  </xsl:function>


  <!-- Given the node of the linear fraction's parent mrow, 
       make a linear fraction -->
  <xsl:template name="MakeLinearFraction">
    <xsl:param name="ndCur" select="." as="element()?"/>
    <m:f>
      <m:fPr>
        <m:type m:val="lin"/>
      </m:fPr>
      <m:num>
        <xsl:call-template name="CreateArgProp"/>
        <xsl:apply-templates select="$ndCur/*[1]"/>
      </m:num>
      <m:den>
        <xsl:call-template name="CreateArgProp"/>
        <xsl:apply-templates select="$ndCur/*[3]"/>
      </m:den>
    </m:f>
  </xsl:template>


  <!-- Given the node of the function's parent mrow, 
       make an omml function -->
  <xsl:template name="WriteFunc">
    <m:func>
      <m:fName>
        <xsl:apply-templates select="*[1]"/>
      </m:fName>
      <m:e>
        <xsl:apply-templates select="*[3]"/>
      </m:e>
    </m:func>
  </xsl:template>


  <!-- MathML doesn't have the concept of nAry structures.  The best approximation
       to these is to have some under/over or sub/sup followed by an mrow or mstyle.
       
       In the case that we've come across some under/over or sub/sup that contains an 
       nAry operator, this function handles the following sibling to the nAry structure.
       
       If the following sibling is:
       
          mml:mstyle, then apply templates to the children of this mml:mstyle
          
          mml:mrow, determine if this mrow is a linear fraction 
          (see comments for FlinearFrac template).
              If so, make an Omml linear fraction.
              If not, apply templates as was done for mml:mstyle.
       
       -->
  <xsl:template name="NaryHandleMrowMstyle">
    <xsl:param name="ndCur" select="." as="element()?"/>
    <!-- if the next sibling is an mrow, pull it in by 
							doing whatever we would have done to its children. 
							The mrow itself will be skipped, see template above. -->
    <xsl:choose>
      <xsl:when test="$ndCur[self::mml:mrow]">
        <xsl:choose>
          <xsl:when test="x:FLinearFrac($ndCur)">
            <xsl:call-template name="MakeLinearFraction">
              <xsl:with-param name="ndCur" select="$ndCur"/>
            </xsl:call-template>
          </xsl:when>
          <xsl:otherwise>
            <xsl:choose>
              <xsl:when test="x:isFunction(.)">
                <xsl:call-template name="WriteFunc"/>
              </xsl:when>
              <xsl:otherwise>
                <xsl:apply-templates select="$ndCur/*"/>
              </xsl:otherwise>
            </xsl:choose>
          </xsl:otherwise>
        </xsl:choose>
      </xsl:when>
      <xsl:when test="$ndCur[self::mml:mstyle]">
        <xsl:apply-templates select="$ndCur/*"/>
      </xsl:when>
    </xsl:choose>
  </xsl:template>


  <!-- MathML munder/mover can represent several Omml constructs 
       (m:bar, m:limLow, m:limUpp, m:acc, m:groupChr, etc.).  The following 
       templates (FIsBar, FIsAcc, and FIsGroupChr) are used to determine 
			 which of these Omml constructs an munder/mover should be translated into. -->

  <!-- Note:  ndCur should only be an munder/mover MathML element.
  
       ndCur should be interpretted as an m:bar if
          1)  its respective accent attribute is not true
          2)  its second child is an mml:mo
          3)  the character of the mml:mo is the correct under/over bar. -->
  <xsl:function name="x:FIsBar" as="xs:boolean">
    <xsl:param name="ndCur" as="element()?"/>
    <xsl:variable name="fUnder" as="xs:boolean" select="exists($ndCur[self::mml:munder])"/>
    <xsl:variable name="fAccent" as="xs:boolean"
      select="lower-case(($ndCur/@accentunder, $ndCur/@accent)[1]) = 'true'"/>

    <xsl:choose>
      <!-- The script is unaccented and the second child is an mo -->
      <xsl:when test="
          not($fAccent)
          and $ndCur/*[2]/self::mml:mo">
        <xsl:variable name="sOperator" as="xs:string" select="$ndCur/*[2]"/>
        <xsl:choose>
          <!-- Should we write an underbar? -->
          <xsl:when test="$fUnder">
            <xsl:sequence select="$sOperator = '&#x00332;'"/>
          </xsl:when>
          <!-- Should we write an overbar? -->
          <xsl:otherwise>
            <xsl:sequence select="$sOperator = '&#x000AF;'"/>
          </xsl:otherwise>
        </xsl:choose>
      </xsl:when>
      <xsl:otherwise>
        <xsl:sequence select="false()"/>
      </xsl:otherwise>
    </xsl:choose>
  </xsl:function>

  <!-- Note:  ndCur should only be an mover MathML element.
  
       ndCur should be interpretted as an m:acc if
          1)  its accent attribute is true
          2)  its second child is an mml:mo
          3)  there is only zero or one character in the mml:mo -->
  <xsl:function name="x:FIsAcc" as="xs:boolean">
    <xsl:param name="ndCur" as="element()?"/>

    <xsl:variable name="fAccent" as="xs:boolean" select="lower-case($ndCur/@accent) = 'true'"/>
    <xsl:choose>
      <!-- The script is accented and the second child is an mo -->
      <xsl:when test="
          $fAccent
          and $ndCur/*[2][self::mml:mo]">
        <xsl:variable name="sOperator" as="xs:string" select="$ndCur/*[2]"/>
        <xsl:choose>
          <!-- There is only one operator, this is a valid Omml accent! -->
          <xsl:when test="string-length($sOperator) &lt;= 1">
            <xsl:sequence select="true()"/>
          </xsl:when>
          <!-- More than one accented operator.  This isn't a valid
               omml accent -->
          <xsl:otherwise>
            <xsl:sequence select="false()"/>
          </xsl:otherwise>
        </xsl:choose>
      </xsl:when>
      <!-- Not accented, not an operator, or both, but in any case, this is
           not an Omml accent. -->
      <xsl:otherwise>
        <xsl:sequence select="false()"/>
      </xsl:otherwise>
    </xsl:choose>
  </xsl:function>


  <!-- Is ndCur a groupChr? 
			 ndCur is a groupChr if:
			 
				 1.  The accent is false (note:  accent attribute 
						 for munder is accentunder). 
				 2.  ndCur is an munder or mover.
				 3.  ndCur has two children
				 4.  Of these two children, one is an mml:mo and the other is an mml:mrow
				 5.  The number of characters in the mml:mo is 1.
			 
			 If all of the above are true, then return 1, else return 0.
	-->
  <xsl:function name="x:FIsGroupChr" as="xs:boolean">
    <xsl:param name="ndCur" as="element()?"/>
    <xsl:variable name="fUnder" as="xs:boolean" select="exists($ndCur/self::mml:munder)"/>
    <xsl:variable name="sLowerCaseAccent" as="xs:string?">
      <xsl:choose>
        <xsl:when test="$fUnder">
          <xsl:value-of select="lower-case($ndCur/@accentunder)"/>
        </xsl:when>
        <xsl:when test="$ndCur/@accent">
          <xsl:value-of select="lower-case($ndCur/@accent)"/>
        </xsl:when>
      </xsl:choose>
    </xsl:variable>

    <xsl:variable name="fAccentFalse" as="xs:boolean" select="$sLowerCaseAccent = 'false'"/>

    <xsl:choose>
      <xsl:when
        test="
          $fAccentFalse
          and $ndCur[self::mml:munder or self::mml:mover]
          and count($ndCur/*) = 2
          and (($ndCur/*[1][self::mml:mrow] and $ndCur/*[2][self::mml:mo])
          or ($ndCur/*[1][self::mml:mo] and $ndCur/*[2][self::mml:mrow]))">
        <xsl:variable name="sOperator" as="xs:string" select="$ndCur/mml:mo"/>
        <xsl:sequence select="string-length($sOperator) &lt;= 1"/>
      </xsl:when>
      <xsl:otherwise>
        <xsl:sequence select="false()"/>
      </xsl:otherwise>
    </xsl:choose>
  </xsl:function>


  <!-- %%Template: match munder
	-->
  <xsl:template match="mml:munder">
    <xsl:variable name="fNary" as="xs:boolean" select="x:isNary(*[1])"/>
    <xsl:choose>
      <xsl:when test="$fNary">
        <m:nary>
          <xsl:call-template name="CreateNaryProp">
            <xsl:with-param name="chr" select="normalize-space(*[1])"/>
            <xsl:with-param name="sMathmlType" select="'munder'"/>
          </xsl:call-template>
          <m:sub>
            <xsl:call-template name="CreateArgProp"/>
            <xsl:apply-templates select="*[2]"/>
          </m:sub>
          <m:sup>
            <xsl:call-template name="CreateArgProp"/>
          </m:sup>
          <m:e>
            <xsl:call-template name="CreateArgProp"/>
            <xsl:call-template name="NaryHandleMrowMstyle">
              <xsl:with-param name="ndCur" select="following-sibling::*[1]"/>
            </xsl:call-template>
          </m:e>
        </m:nary>
      </xsl:when>
      <xsl:otherwise>
        <!-- Should this munder be interpreted as an OMML m:bar? -->
        <xsl:variable name="fIsBar" as="xs:boolean" select="x:FIsBar(.)"/>
        <xsl:choose>
          <xsl:when test="$fIsBar">
            <m:bar>
              <m:barPr>
                <m:pos m:val="bot"/>
              </m:barPr>
              <m:e>
                <xsl:call-template name="CreateArgProp"/>
                <xsl:apply-templates select="*[1]"/>
              </m:e>
            </m:bar>
          </xsl:when>
          <xsl:otherwise>
            <!-- It isn't an integral or underbar, is this a groupChr? -->
            <xsl:variable name="fGroupChr" as="xs:boolean" select="x:FIsGroupChr(.)"/>
            <xsl:choose>
              <xsl:when test="$fGroupChr">
                <m:groupChr>
                  <xsl:call-template name="CreateGroupChrPr">
                    <xsl:with-param name="chr" select="mml:mo"/>
                    <xsl:with-param name="pos">
                      <xsl:choose>
                        <xsl:when test="*[1][self::mml:mrow]">bot</xsl:when>
                        <xsl:otherwise>top</xsl:otherwise>
                      </xsl:choose>
                    </xsl:with-param>
                    <xsl:with-param name="vertJc">top</xsl:with-param>
                  </xsl:call-template>
                  <m:e>
                    <xsl:apply-templates select="mml:mrow"/>
                  </m:e>
                </m:groupChr>
              </xsl:when>
              <xsl:otherwise>
                <!-- Generic munder -->
                <m:limLow>
                  <m:e>
                    <xsl:call-template name="CreateArgProp"/>
                    <xsl:apply-templates select="*[1]"/>
                  </m:e>
                  <m:lim>
                    <xsl:call-template name="CreateArgProp"/>
                    <xsl:apply-templates select="*[2]"/>
                  </m:lim>
                </m:limLow>
              </xsl:otherwise>
            </xsl:choose>
          </xsl:otherwise>
        </xsl:choose>
      </xsl:otherwise>
    </xsl:choose>
  </xsl:template>


  <!-- Given the values for chr, pos, and vertJc, create an omml
	     groupChr's groupChrPr -->
  <xsl:template name="CreateGroupChrPr">
    <xsl:param name="chr" as="xs:string">&#x23df;</xsl:param>
    <xsl:param name="pos" select="'bot'" as="xs:string"/>
    <xsl:param name="vertJc" select="'top'" as="xs:string"/>
    <m:groupChrPr>
      <m:chr m:val="{$chr}"/>
      <m:pos m:val="{$pos}"/>
      <m:vertJc m:val="{$vertJc}"/>
    </m:groupChrPr>
  </xsl:template>


  <!-- %%Template: match mover
	-->
  <xsl:template match="mml:mover">
    <xsl:variable name="fNary" as="xs:boolean" select="x:isNary(*[1])"/>
    <xsl:choose>
      <xsl:when test="$fNary">
        <m:nary>
          <xsl:call-template name="CreateNaryProp">
            <xsl:with-param name="chr" select="normalize-space(*[1])"/>
            <xsl:with-param name="sMathmlType" select="'mover'"/>
          </xsl:call-template>
          <m:sub>
            <xsl:call-template name="CreateArgProp"/>
          </m:sub>
          <m:sup>
            <xsl:call-template name="CreateArgProp"/>
            <xsl:apply-templates select="*[2]"/>
          </m:sup>
          <m:e>
            <xsl:call-template name="CreateArgProp"/>
            <xsl:call-template name="NaryHandleMrowMstyle">
              <xsl:with-param name="ndCur" select="following-sibling::*[1]"/>
            </xsl:call-template>
          </m:e>
        </m:nary>
      </xsl:when>
      <xsl:otherwise>
        <!-- Should this munder be interpreted as an OMML m:bar or m:acc? -->

        <!-- Check to see if this is an m:bar -->
        <xsl:variable name="fIsBar" as="xs:boolean" select="x:FIsBar(.)"/>
        <xsl:choose>
          <xsl:when test="$fIsBar">
            <m:bar>
              <m:barPr>
                <m:pos m:val="top"/>
              </m:barPr>
              <m:e>
                <xsl:call-template name="CreateArgProp"/>
                <xsl:apply-templates select="*[1]"/>
              </m:e>
            </m:bar>
          </xsl:when>
          <xsl:otherwise>
            <!-- Not an m:bar, should it be an m:acc? -->
            <xsl:variable name="fIsAcc" as="xs:boolean" select="x:FIsAcc(.)"/>
            <xsl:choose>
              <xsl:when test="$fIsAcc">
                <m:acc>
                  <m:accPr>
                    <m:chr m:val="{*[2]}"/>
                  </m:accPr>
                  <m:e>
                    <xsl:call-template name="CreateArgProp"/>
                    <xsl:apply-templates select="*[1]"/>
                  </m:e>
                </m:acc>
              </xsl:when>
              <xsl:otherwise>
                <!-- This isn't an integral, overbar or accent, 
								     could it be a groupChr? -->
                <xsl:variable name="fGroupChr" as="xs:boolean" select="x:FIsGroupChr(.)"/>
                <xsl:choose>
                  <xsl:when test="$fGroupChr">
                    <m:groupChr>
                      <xsl:call-template name="CreateGroupChrPr">
                        <xsl:with-param name="chr" select="mml:mo"/>
                        <xsl:with-param name="pos">
                          <xsl:choose>
                            <xsl:when test="*[1][self::mml:mrow]">top</xsl:when>
                            <xsl:otherwise>bot</xsl:otherwise>
                          </xsl:choose>
                        </xsl:with-param>
                        <xsl:with-param name="vertJc">bot</xsl:with-param>
                      </xsl:call-template>
                      <m:e>
                        <xsl:apply-templates select="mml:mrow"/>
                      </m:e>
                    </m:groupChr>
                  </xsl:when>
                  <xsl:otherwise>
                    <!-- Generic mover -->
                    <m:limUpp>
                      <m:e>
                        <xsl:call-template name="CreateArgProp"/>
                        <xsl:apply-templates select="*[1]"/>
                      </m:e>
                      <m:lim>
                        <xsl:call-template name="CreateArgProp"/>
                        <xsl:apply-templates select="*[2]"/>
                      </m:lim>
                    </m:limUpp>
                  </xsl:otherwise>
                </xsl:choose>
              </xsl:otherwise>
            </xsl:choose>
          </xsl:otherwise>
        </xsl:choose>
      </xsl:otherwise>
    </xsl:choose>
  </xsl:template>


  <!-- %%Template: match munderover
	-->
  <xsl:template match="mml:munderover">
    <xsl:variable name="fNary" as="xs:boolean" select="x:isNary(*[1])"/>
    <xsl:choose>
      <xsl:when test="$fNary">
        <m:nary>
          <xsl:call-template name="CreateNaryProp">
            <xsl:with-param name="chr" select="normalize-space(*[1])"/>
            <xsl:with-param name="sMathmlType" select="'munderover'"/>
          </xsl:call-template>
          <m:sub>
            <xsl:call-template name="CreateArgProp"/>
            <xsl:apply-templates select="*[2]"/>
          </m:sub>
          <m:sup>
            <xsl:call-template name="CreateArgProp"/>
            <xsl:apply-templates select="*[3]"/>
          </m:sup>
          <m:e>
            <xsl:call-template name="CreateArgProp"/>
            <xsl:call-template name="NaryHandleMrowMstyle">
              <xsl:with-param name="ndCur" select="following-sibling::*[1]"/>
            </xsl:call-template>
          </m:e>
        </m:nary>
      </xsl:when>
      <xsl:otherwise>
        <m:limUpp>
          <m:e>
            <xsl:call-template name="CreateArgProp"/>
            <m:limLow>
              <m:e>
                <xsl:call-template name="CreateArgProp"/>
                <xsl:apply-templates select="*[1]"/>
              </m:e>
              <m:lim>
                <xsl:call-template name="CreateArgProp"/>
                <xsl:apply-templates select="*[2]"/>
              </m:lim>
            </m:limLow>
          </m:e>
          <m:lim>
            <xsl:call-template name="CreateArgProp"/>
            <xsl:apply-templates select="*[3]"/>
          </m:lim>
        </m:limUpp>
      </xsl:otherwise>
    </xsl:choose>
  </xsl:template>

  <!-- %%Template: match mfenced -->
  <xsl:template match="mml:mfenced">
    <m:d>
      <xsl:variable name="fChSeparatorsValid"
        select="
          if (exists(@separators)) then
            1
          else
            0"
        as="xs:integer"/>
      <xsl:call-template name="CreateDelimProp">
        <xsl:with-param name="fChOpenValid"
          select="
            if (exists(@open)) then
              1
            else
              0"/>
        <xsl:with-param name="chOpen" select="@open"/>
        <xsl:with-param name="fChSeparatorsValid" select="$fChSeparatorsValid"/>
        <xsl:with-param name="chSeparators" select="@separators"/>
        <xsl:with-param name="fChCloseValid"
          select="
            if (exists(@close)) then
              1
            else
              0"/>
        <xsl:with-param name="chClose" select="@close"/>
      </xsl:call-template>
      <xsl:choose>
        <xsl:when test="not($fChSeparatorsValid = 1) and empty(*[not(self::mml:mtext)])">
          <m:e>
            <xsl:call-template name="CreateArgProp"/>
            <xsl:for-each select="*">
              <xsl:if test="position() != 1">
                <m:r>
                  <m:rPr>
                    <m:nor/>
                  </m:rPr>
                  <m:t>,</m:t>
                </m:r>
              </xsl:if>
              <xsl:apply-templates select="."/>
            </xsl:for-each>
          </m:e>
        </xsl:when>
        <xsl:otherwise>
          <xsl:for-each select="*">
            <m:e>
              <xsl:call-template name="CreateArgProp"/>
              <xsl:apply-templates select="."/>
            </m:e>
          </xsl:for-each>
        </xsl:otherwise>
      </xsl:choose>
    </m:d>
  </xsl:template>

  <!-- %%Template: CreateDelimProp
	
		Given the characters to use as open, close and separators for 
		the delim object, create the m:dPr (delim properties). 		
		
		MathML can have any number of separators in an mfenced object, but 
		OMML can only represent one separator for each d (delim) object.
		So, we pick the first separator specified. 		
	-->
  <xsl:template name="CreateDelimProp">
    <xsl:param name="fChOpenValid" as="xs:integer"/>
    <xsl:param name="chOpen" as="xs:string?"/>
    <xsl:param name="fChSeparatorsValid" as="xs:integer"/>
    <xsl:param name="chSeparators" as="xs:string?"/>
    <xsl:param name="fChCloseValid" as="xs:integer"/>
    <xsl:param name="chClose" as="xs:string?"/>
    <xsl:variable name="chSep" select="substring($chSeparators, 1, 1)" as="xs:string"/>

    <!-- do we need a dPr at all? If everything's at its default value, then 
			don't bother at all -->
    <xsl:if
      test="
        ($fChOpenValid and not($chOpen = '(')) or
        ($fChCloseValid and not($chClose = ')')) or
        not($chSep = '|')">
      <m:dPr>
        <m:shp m:val="match"/>
        <!--
        <m:ctrlPr>
          <w:rPr>
            <w:rFonts w:ascii="Cambria Math" w:hAnsi="Cambria Math"/>
            <w:i w:val="0"/>
          </w:rPr>
        </m:ctrlPr>
        -->
        <!-- the default for MathML and OMML is '('. -->
        <xsl:if test="$fChOpenValid and not($chOpen = '(')">
          <m:begChr m:val="{$chOpen}"/>
        </xsl:if>

        <!-- the default for MathML is ',' and for OMML is '|' -->

        <xsl:choose>
          <!-- matches OMML's default, don't bother to write anything out -->
          <xsl:when test="$chSep = '|'"/>

          <!-- Not specified, use MathML's default. We test against 
					the existence of the actual attribute, not the substring -->
          <xsl:when test="not($fChSeparatorsValid)">
            <m:sepChr m:val=","/>
          </xsl:when>

          <xsl:otherwise>
            <m:sepChr m:val="{$chSep}"/>
          </xsl:otherwise>
        </xsl:choose>

        <!-- the default for MathML and OMML is ')'. -->
        <xsl:if test="$fChCloseValid and not($chClose = ')')">
          <m:endChr m:val="{$chClose}"/>
        </xsl:if>
      </m:dPr>
    </xsl:if>
  </xsl:template>

  <xsl:template name="LQuoteFromMs">
    <xsl:param name="msCur" select="." as="element()"/>
    <xsl:choose>
      <xsl:when test="(not($msCur/@lquote) or $msCur/@lquote = '')">
        <xsl:text>"</xsl:text>
      </xsl:when>
      <xsl:otherwise>
        <xsl:value-of select="$msCur/@lquote"/>
      </xsl:otherwise>
    </xsl:choose>
  </xsl:template>

  <xsl:template name="RQuoteFromMs" as="xs:string">
    <xsl:param name="msCur" select="." as="element()"/>
    <xsl:choose>
      <xsl:when test="(not($msCur/@rquote) or $msCur/@rquote = '')">
        <xsl:text>"</xsl:text>
      </xsl:when>
      <xsl:otherwise>
        <xsl:value-of select="$msCur/@rquote"/>
      </xsl:otherwise>
    </xsl:choose>
  </xsl:template>

  <!-- %%Template: OutputMs
	-->
  <xsl:template name="OutputMs">
    <xsl:param name="msCur" as="element()"/>

    <xsl:variable name="chLquote" as="xs:string">
      <xsl:call-template name="LQuoteFromMs">
        <xsl:with-param name="msCur" select="$msCur"/>
      </xsl:call-template>
    </xsl:variable>

    <xsl:variable name="chRquote" as="xs:string">
      <xsl:call-template name="RQuoteFromMs">
        <xsl:with-param name="msCur" select="$msCur"/>
      </xsl:call-template>
    </xsl:variable>

    <xsl:value-of select="$chLquote"/>
    <xsl:value-of select="normalize-space($msCur)"/>
    <xsl:value-of select="$chRquote"/>
  </xsl:template>

  <!-- %%Template: match msub
	-->
  <xsl:template match="mml:msub">
    <xsl:variable name="fNary" as="xs:boolean" select="x:isNary(*[1])"/>
    <xsl:choose>
      <xsl:when test="$fNary">
        <m:nary>
          <xsl:call-template name="CreateNaryProp">
            <xsl:with-param name="chr" select="normalize-space(*[1])"/>
            <xsl:with-param name="sMathmlType" select="'msub'"/>
          </xsl:call-template>
          <m:sub>
            <xsl:call-template name="CreateArgProp"/>
            <xsl:apply-templates select="*[2]"/>
          </m:sub>
          <m:sup>
            <xsl:call-template name="CreateArgProp"/>
          </m:sup>
          <m:e>
            <xsl:call-template name="CreateArgProp"/>
            <xsl:call-template name="NaryHandleMrowMstyle">
              <xsl:with-param name="ndCur" select="following-sibling::*[1]"/>
            </xsl:call-template>
          </m:e>
        </m:nary>
      </xsl:when>
      <xsl:otherwise>
        <m:sSub>
          <m:e>
            <xsl:call-template name="CreateArgProp"/>
            <xsl:apply-templates select="*[1]"/>
          </m:e>
          <m:sub>
            <xsl:call-template name="CreateArgProp"/>
            <xsl:apply-templates select="*[2]"/>
          </m:sub>
        </m:sSub>
      </xsl:otherwise>
    </xsl:choose>
  </xsl:template>

  <!-- %%Template: match msup
	-->
  <xsl:template match="mml:msup">
    <xsl:variable name="fNary" as="xs:boolean" select="x:isNary(*[1])"/>
    <xsl:choose>
      <xsl:when test="$fNary">
        <m:nary>
          <xsl:call-template name="CreateNaryProp">
            <xsl:with-param name="chr" select="normalize-space(*[1])"/>
            <xsl:with-param name="sMathmlType" select="'msup'"/>
          </xsl:call-template>
          <m:sub>
            <xsl:call-template name="CreateArgProp"/>
          </m:sub>
          <m:sup>
            <xsl:call-template name="CreateArgProp"/>
            <xsl:apply-templates select="*[2]"/>
          </m:sup>
          <m:e>
            <xsl:call-template name="CreateArgProp"/>
            <xsl:call-template name="NaryHandleMrowMstyle">
              <xsl:with-param name="ndCur" select="following-sibling::*[1]"/>
            </xsl:call-template>
          </m:e>
        </m:nary>
      </xsl:when>
      <xsl:otherwise>
        <m:sSup>
          <m:e>
            <xsl:call-template name="CreateArgProp"/>
            <xsl:apply-templates select="*[1]"/>
          </m:e>
          <m:sup>
            <xsl:call-template name="CreateArgProp"/>
            <xsl:apply-templates select="*[2]"/>
          </m:sup>
        </m:sSup>
      </xsl:otherwise>
    </xsl:choose>
  </xsl:template>

  <!-- %%Template: match msubsup
	-->
  <xsl:template match="mml:msubsup">
    <xsl:variable name="fNary" as="xs:boolean" select="x:isNary(*[1])"/>
    <xsl:choose>
      <xsl:when test="$fNary">
        <m:nary>
          <xsl:call-template name="CreateNaryProp">
            <xsl:with-param name="chr" select="normalize-space(*[1])"/>
            <xsl:with-param name="sMathmlType" select="'msubsup'"/>
          </xsl:call-template>
          <m:sub>
            <xsl:call-template name="CreateArgProp"/>
            <xsl:apply-templates select="*[2]"/>
          </m:sub>
          <m:sup>
            <xsl:call-template name="CreateArgProp"/>
            <xsl:apply-templates select="*[3]"/>
          </m:sup>
          <m:e>
            <xsl:call-template name="CreateArgProp"/>
            <xsl:call-template name="NaryHandleMrowMstyle">
              <xsl:with-param name="ndCur" select="following-sibling::*[1]"/>
            </xsl:call-template>
          </m:e>
        </m:nary>
      </xsl:when>
      <xsl:otherwise>
        <m:sSubSup>
          <m:e>
            <xsl:call-template name="CreateArgProp"/>
            <xsl:apply-templates select="*[1]"/>
          </m:e>
          <m:sub>
            <xsl:call-template name="CreateArgProp"/>
            <xsl:apply-templates select="*[2]"/>
          </m:sub>
          <m:sup>
            <xsl:call-template name="CreateArgProp"/>
            <xsl:apply-templates select="*[3]"/>
          </m:sup>
        </m:sSubSup>
      </xsl:otherwise>
    </xsl:choose>
  </xsl:template>

  <!-- %%Template: SplitScripts 
	
		Takes an collection of nodes, and splits them
		odd and even into sup and sub scripts. Used for dealing with
		mmultiscript.
		
		This template assumes you want to output both a sub and sup element.
		-->
  <xsl:template name="SplitScripts">
    <xsl:param name="ndScripts" as="element()*"/>
    <m:sub>
      <xsl:call-template name="CreateArgProp"/>
      <xsl:apply-templates select="$ndScripts[(position() mod 2) = 1]"/>
    </m:sub>
    <m:sup>
      <xsl:call-template name="CreateArgProp"/>
      <xsl:apply-templates select="$ndScripts[(position() mod 2) = 0]"/>
    </m:sup>
  </xsl:template>

  <!-- %%Template: match mmultiscripts
	
		There is some subtlety with the mml:mprescripts element. Everything that comes before 
		that is considered a script (as opposed to a pre-script), but it need not be present.
	-->
  <xsl:template match="mml:mmultiscripts">

    <!-- count the nodes. Everything that comes after a mml:mprescripts is considered a pre-script;
			Everything that does not have an mml:mprescript as a preceding-sibling (and is not itself 
			mml:mprescript) is a script, except for the first child which is always the base.
			The mml:none element is a place holder for a sub/sup element slot.
			
			mmultisript pattern:
			<mmultiscript>
				(base)
				(sub sup)* // Where <none/> can replace a sub/sup entry to preserve pattern.
				<mprescripts />
				(presub presup)*
			</mmultiscript>
			-->
    <!-- Count of presecript nodes that we'd print (this is essentially anything but the none placeholder. -->
    <xsl:variable name="cndPrescriptStrict" as="xs:integer"
      select="count(mml:mprescripts[1]/following-sibling::*[not(self::mml:none)])"/>
    <!-- Count of all super script excluding mml:none -->
    <xsl:variable name="cndSuperScript" as="xs:integer"
      select="
        count(*[not(preceding-sibling::mml:mprescripts)
        and not(self::mml:mprescripts)
        and ((position() mod 2) = 1)
        and not(self::mml:none)]) - 1"/>
    <!-- Count of all sup script excluding mml:none -->
    <xsl:variable name="cndSubScript" as="xs:integer"
      select="
        count(*[not(preceding-sibling::mml:mprescripts)
        and not(self::mml:mprescripts)
        and ((position() mod 2) = 0)
        and not(self::mml:none)])"/>
    <!-- Count of all scripts excluding mml:none -->
    <xsl:variable name="cndScriptStrict" select="$cndSuperScript + $cndSubScript" as="xs:integer"/>
    <!-- Count of all scripts including mml:none.  This is essentially all nodes before the 
		first mml:mprescripts except the base. -->
    <xsl:variable name="cndScript" as="xs:integer"
      select="count(*[not(preceding-sibling::mml:mprescripts) and not(self::mml:mprescripts)]) - 1"/>

    <xsl:choose>
      <!-- The easy case first. No prescripts, and no script ... just a base -->
      <xsl:when test="$cndPrescriptStrict &lt;= 0 and $cndScriptStrict &lt;= 0">
        <xsl:apply-templates select="*[1]"/>
      </xsl:when>

      <!-- Next, if there are no prescripts -->
      <xsl:when test="$cndPrescriptStrict &lt;= 0">
        <!-- we know we have some scripts or else we would have taken the earlier
					  branch. -->
        <xsl:choose>
          <!-- We have both sub and super scripts-->
          <xsl:when test="$cndSuperScript gt 0 and $cndSubScript gt 0">
            <m:sSubSup>
              <m:e>
                <xsl:call-template name="CreateArgProp"/>
                <xsl:apply-templates select="*[1]"/>
              </m:e>

              <!-- Every child except the first is a script.  Do the split -->
              <xsl:call-template name="SplitScripts">
                <xsl:with-param name="ndScripts" select="*[position() gt 1]"/>
              </xsl:call-template>
            </m:sSubSup>
          </xsl:when>
          <!-- Just a sub script -->
          <xsl:when test="$cndSubScript gt 0">
            <m:sSub>
              <m:e>
                <xsl:call-template name="CreateArgProp"/>
                <xsl:apply-templates select="*[1]"/>
              </m:e>

              <!-- No prescripts and no super scripts, therefore, it's a sub. -->
              <m:sub>
                <xsl:apply-templates select="*[position() gt 1]"/>
              </m:sub>
            </m:sSub>
          </xsl:when>
          <!-- Just super script -->
          <xsl:otherwise>
            <m:sSup>
              <m:e>
                <xsl:call-template name="CreateArgProp"/>
                <xsl:apply-templates select="*[1]"/>
              </m:e>

              <!-- No prescripts and no sub scripts, therefore, it's a sup. -->
              <m:sup>
                <xsl:apply-templates select="*[position() gt 1]"/>
              </m:sup>
            </m:sSup>
          </xsl:otherwise>
        </xsl:choose>
      </xsl:when>

      <!-- Next, if there are no scripts -->
      <xsl:when test="$cndScriptStrict &lt;= 0">
        <!-- we know we have some prescripts or else we would have taken the earlier
					  branch. So, create an sPre and split the elements -->
        <m:sPre>
          <m:e>
            <xsl:call-template name="CreateArgProp"/>
            <xsl:apply-templates select="*[1]"/>
          </m:e>

          <!-- The prescripts come after the mml:mprescript and if we get here
							we know there exists some elements after the mml:mprescript element. 
							
							The prescript element has no sub/subsup variation, therefore, even if
							we're only writing sub, we need to write out both the sub and sup element.
							-->
          <xsl:call-template name="SplitScripts">
            <xsl:with-param name="ndScripts" select="mml:mprescripts[1]/following-sibling::*"/>
          </xsl:call-template>
        </m:sPre>
      </xsl:when>

      <!-- Finally, the case with both prescripts and scripts. Create an sPre 
				element to house the prescripts, with a sub/sup/subsup element at its base. -->
      <xsl:otherwise>
        <m:sPre>
          <m:e>
            <xsl:choose>
              <!-- We have both sub and super scripts-->
              <xsl:when test="$cndSuperScript gt 0 and $cndSubScript gt 0">
                <m:sSubSup>
                  <m:e>
                    <xsl:call-template name="CreateArgProp"/>
                    <xsl:apply-templates select="*[1]"/>
                  </m:e>

                  <!-- scripts come before the mml:mprescript but after the first child, so their
								 positions will be 2, 3, ... ($nndScript + 1) -->
                  <xsl:call-template name="SplitScripts">
                    <xsl:with-param name="ndScripts"
                      select="*[(position() gt 1) and (position() &lt;= ($cndScript + 1))]"/>
                  </xsl:call-template>
                </m:sSubSup>
              </xsl:when>
              <!-- Just a sub script -->
              <xsl:when test="$cndSubScript gt 0">
                <m:sSub>
                  <m:e>
                    <xsl:call-template name="CreateArgProp"/>
                    <xsl:apply-templates select="*[1]"/>
                  </m:e>

                  <!-- We have prescripts but no super scripts, therefore, do a sub 
									and apply templates to all tokens counted by cndScript. -->
                  <m:sub>
                    <xsl:apply-templates
                      select="*[position() gt 1 and (position() &lt;= ($cndScript + 1))]"/>
                  </m:sub>
                </m:sSub>
              </xsl:when>
              <!-- Just super script -->
              <xsl:otherwise>
                <m:sSup>
                  <m:e>
                    <xsl:call-template name="CreateArgProp"/>
                    <xsl:apply-templates select="*[1]"/>
                  </m:e>

                  <!-- We have prescripts but no sub scripts, therefore, do a sub 
									and apply templates to all tokens counted by cndScript. -->
                  <m:sup>
                    <xsl:apply-templates
                      select="*[position() gt 1 and (position() &lt;= ($cndScript + 1))]"/>
                  </m:sup>
                </m:sSup>
              </xsl:otherwise>
            </xsl:choose>
          </m:e>

          <!-- The prescripts come after the mml:mprescript and if we get here
							we know there exists one such element -->
          <xsl:call-template name="SplitScripts">
            <xsl:with-param name="ndScripts" select="mml:mprescripts[1]/following-sibling::*"/>
          </xsl:call-template>
        </m:sPre>
      </xsl:otherwise>
    </xsl:choose>
  </xsl:template>

  <!-- Template that determines if ndCur is an equation array.
				
			 ndCur is an equation array if:
			 
			 1.  There are are no frame lines
			 2.  There are no column lines
			 3.  There are no row lines
			 4.  There is no row with more than 1 column  
			 5.  There is no row with fewer than 1 column
			 6.  There are no labeled rows.
			 
	-->
  <xsl:function name="x:FIsEqArray" as="xs:boolean">
    <xsl:param name="ndCur" as="element()?"/>

    <!-- There should be no frame, columnlines, or rowlines -->
    <xsl:sequence
      select="
        (not($ndCur/@frame) or $ndCur/@frame = '' or $ndCur/@frame = 'none')
        and (not($ndCur/@columnlines) or $ndCur/@columnlines = '' or $ndCur/@columnlines = 'none')
        and (not($ndCur/@rowlines) or $ndCur/@rowlines = '' or $ndCur/@rowlines = 'none')
        and not($ndCur/mml:mtr[count(mml:mtd) gt 1])
        and not($ndCur/mml:mtr[count(mml:mtd) lt 1])
        and not($ndCur/mml:mlabeledtr)"
    />
  </xsl:function>

  <!-- Template used to determine if we should ignore a collection when iterating through 
	     a mathml equation array row.
	
			 So far, the only thing that needs to be ignored is the argument of an nary.  We
			 can ignore this since it is output when we apply-templates to the munder[over]/msub[sup].
	-->
  <xsl:function name="x:FIgnoreCollection" as="xs:boolean">
    <xsl:param name="ndCur" as="element()?"/>

    <xsl:variable name="fNaryArgument" as="xs:boolean" select="x:FIsNaryArgument($ndCur)"/>
    <xsl:sequence select="$fNaryArgument"/>
  </xsl:function>

  <!-- Template used to determine if we've already encountered an maligngroup or malignmark.
	
			 This is needed because omml has an implicit spacing alignment (omml spacing alignment = 
			 mathml's maligngroup element) at the beginning of each equation array row.  Therefore, 
			 the first maligngroup (implied or explicit) we encounter does not need to be output.  
			 This template recursively searches up the xml tree and looks at previous siblings to see 
			 if they have a descendant that is an maligngroup or malignmark.  We look for the malignmark 
			 to find the implicit maligngroup.
	-->
  <xsl:function name="x:FFirstAlignAlreadyFound" as="xs:boolean">
    <xsl:param name="ndCur" as="element()?"/>

    <xsl:choose>
      <xsl:when
        test="
          count($ndCur/preceding-sibling::*[descendant-or-self::mml:maligngroup
          or descendant-or-self::mml:malignmark]) gt 0">
        <xsl:sequence select="true()"/>
      </xsl:when>
      <xsl:when test="not($ndCur/parent::mml:mtd)">
        <xsl:sequence select="x:FFirstAlignAlreadyFound($ndCur/parent::*)"/>
      </xsl:when>
      <xsl:otherwise>
        <xsl:sequence select="false()"/>
      </xsl:otherwise>
    </xsl:choose>
  </xsl:function>

  <!-- This template builds a string that is result of concatenating a given string several times. 
	
			 Given strToRepeat, create a string that has strToRepeat repeated iRepitions times. 
	-->
  <xsl:function name="x:repeat" as="xs:string">
    <xsl:param name="strToRepeat" as="xs:string"/>
    <xsl:param name="iRepetitions" as="xs:integer"/>
    <xsl:value-of>
     <xsl:for-each select="0 to ($iRepetitions - 1) ">
       <xsl:value-of select="$strToRepeat"/>
     </xsl:for-each>
    </xsl:value-of>
  </xsl:function>

  <!-- This template determines if ndCur is a special collection.
			 By special collection, I mean is ndCur the outer element of some special grouping 
			 of mathml elements that actually represents some over all omml structure.
			 
			 For instance, is ndCur a linear fraction, or an omml function.
	-->
  <xsl:function name="x:FSpecialCollection" as="xs:boolean">
    <xsl:param name="ndCur" as="element()?"/>
    <xsl:choose>
      <xsl:when test="$ndCur/self::mml:mrow">
        <xsl:variable name="fLinearFraction" as="xs:boolean" select="x:FLinearFrac($ndCur)"/>
        <xsl:variable name="fFunc" as="xs:boolean" select="x:isFunction($ndCur)"/>
        <xsl:sequence select="$fLinearFraction or $fFunc"/>
      </xsl:when>
      <xsl:otherwise>
        <xsl:sequence select="false()"/>
      </xsl:otherwise>
    </xsl:choose>
  </xsl:function>

  <!-- This template iterates through the children of an equation array row (mtr) and outputs
	     the equation.
			 
			 This template does all the work to output ampersands and skip the right elements when needed.
	-->
  <xsl:template name="ProcessEqArrayRow">
    <xsl:param name="ndCur" select="." as="element()?"/>

    <xsl:for-each select="$ndCur/*">
      <xsl:variable name="fSpecialCollection" as="xs:boolean" select="x:FSpecialCollection(.)"/>
      <xsl:variable name="fIgnoreCollection" as="xs:boolean" select="x:FIgnoreCollection(.)"/>
      <xsl:choose>
        <!-- If we have an alignment element output the ampersand. -->
        <xsl:when test="self::mml:maligngroup or self::mml:malignmark">
          <!-- Omml has an implied spacing alignment at the beginning of each equation.
					     Therefore, if this is the first ampersand to be output, don't actually output. -->
          <xsl:variable name="fFirstAlignAlreadyFound" as="xs:boolean"
            select="x:FFirstAlignAlreadyFound(.)"/>
          <!-- Don't output unless it is an malignmark or we have already previously found an alignment point. -->
          <xsl:if test="self::mml:malignmark or $fFirstAlignAlreadyFound">
            <m:r>
              <m:t>&amp;</m:t>
            </m:r>
          </xsl:if>
        </xsl:when>
        <!-- If this node is an non-special mrow or mstyle and we aren't supposed to ignore this collection, then
				     go ahead an apply templates to this node. -->
        <xsl:when
          test="not($fIgnoreCollection) and ((self::mml:mrow and not($fSpecialCollection)) or self::mml:mstyle)">
          <xsl:call-template name="ProcessEqArrayRow">
            <xsl:with-param name="ndCur" select="."/>
          </xsl:call-template>
        </xsl:when>
        <!-- At this point we have some mathml structure (fraction, nary, non-grouping element, etc.) -->
        <!-- If this mathml structure has alignment groups or marks as children, then extract those since
				     omml can't handle that. -->
        <xsl:when test="descendant::mml:maligngroup or descendant::mml:malignmark">
          <xsl:variable name="cMalignGroups" as="xs:integer"
            select="count(descendant::mml:maligngroup)"/>
          <xsl:variable name="cMalignMarks" as="xs:integer"
            select="count(descendant::mml:malignmark)"/>
          <!-- Output all maligngroups and malignmarks as '&' -->
          <xsl:if test="$cMalignGroups + $cMalignMarks gt 0">
            <m:r>
              <m:t>
                <xsl:call-template name="OutputText">
                  <xsl:with-param name="sInput" select="x:repeat('&amp;', $cMalignGroups + $cMalignMarks)"/>
                </xsl:call-template>
              </m:t>
            </m:r>
          </xsl:if>
          <!-- Now that the '&' have been extracted, just apply-templates to this node.-->
          <xsl:apply-templates select="."/>
        </xsl:when>
        <!-- If there are no alignment points as descendants, then go ahead and output this node. -->
        <xsl:otherwise>
          <xsl:apply-templates select="."/>
        </xsl:otherwise>
      </xsl:choose>
    </xsl:for-each>
  </xsl:template>

  <!-- This template transforms mtable into its appropriate omml type.
	
			 There are two possible omml constructs that an mtable can become:  a matrix or 
			 an equation array.
			 
			 Because omml has no generic table construct, the omml matrix is the best approximate
			 for a mathml table.
			 
			 Our equation array transformation is very simple.  The main goal of this transform is to
			 allow roundtripping omml eq arrays through mathml.  The template ProcessEqArrayRow was never
			 intended to account for many of the alignment flexibilities that are present in mathml like 
			 using the alig attribute, using alignmark attribute in token elements, etc.
			 
			 The restrictions on this transform require <malignmark> and <maligngroup> elements to be outside of
			 any non-grouping mathml elements (that is, mrow and mstyle).  Moreover, these elements cannot be the children of
			 mrows that represent linear fractions or functions.  Also, <malignmark> cannot be a child
			 of token attributes.
			 
			 In the case that the above 
	
	-->
  <xsl:template match="mml:mtable">
    <xsl:variable name="fEqArray" as="xs:boolean" select="x:FIsEqArray(.)"/>
    <xsl:choose>
      <xsl:when test="$fEqArray">
        <m:eqArr>
          <xsl:for-each select="mml:mtr">
            <m:e>
              <xsl:call-template name="ProcessEqArrayRow">
                <xsl:with-param name="ndCur" select="mml:mtd"/>
              </xsl:call-template>
            </m:e>
          </xsl:for-each>
        </m:eqArr>
      </xsl:when>
      <xsl:otherwise>
        <xsl:variable name="cMaxElmtsInRow" as="xs:integer" select="x:CountMaxElmtsInRow(*[1], 0)"/>
        <m:m>
          <m:mPr>
            <m:baseJc m:val="center"/>
            <m:plcHide m:val="true"/>
            <m:mcs>
              <m:mc>
                <m:mcPr>
                  <m:count m:val="{$cMaxElmtsInRow}"/>
                  <m:mcJc m:val="center"/>
                </m:mcPr>
              </m:mc>
            </m:mcs>
          </m:mPr>
          <xsl:for-each select="*">
            <xsl:choose>
              <xsl:when test="self::mml:mtr or self::mml:mlabeledtr">
                <m:mr>
                  <xsl:choose>
                    <xsl:when test="self::mml:mtr">
                      <xsl:for-each select="*">
                        <m:e>
                          <xsl:apply-templates select="."/>
                        </m:e>
                      </xsl:for-each>
                      <xsl:call-template name="CreateEmptyElmt">
                        <xsl:with-param name="cEmptyMtd" select="$cMaxElmtsInRow - count(*)"/>
                      </xsl:call-template>
                    </xsl:when>
                    <xsl:otherwise>
                      <xsl:for-each select="*[position() gt 1]">
                        <m:e>
                          <xsl:apply-templates select="."/>
                        </m:e>
                      </xsl:for-each>
                      <xsl:call-template name="CreateEmptyElmt">
                        <xsl:with-param name="cEmptyMtd" select="$cMaxElmtsInRow - (count(*) - 1)"/>
                      </xsl:call-template>
                    </xsl:otherwise>
                  </xsl:choose>
                </m:mr>
              </xsl:when>
              <xsl:otherwise>
                <m:mr>
                  <m:e>
                    <xsl:apply-templates select="."/>
                  </m:e>
                  <xsl:call-template name="CreateEmptyElmt">
                    <xsl:with-param name="cEmptyMtd" select="$cMaxElmtsInRow - 1"/>
                  </xsl:call-template>
                </m:mr>
              </xsl:otherwise>
            </xsl:choose>
          </xsl:for-each>
        </m:m>
      </xsl:otherwise>
    </xsl:choose>
  </xsl:template>

  <xsl:template match="m:mtd">
    <xsl:apply-templates select="*"/>
  </xsl:template>

  <xsl:template name="CreateEmptyElmt" as="element()*">
    <xsl:param name="cEmptyMtd" as="xs:integer"/>
    <xsl:if test="$cEmptyMtd gt 0">
      <m:e/>
      <xsl:call-template name="CreateEmptyElmt">
        <xsl:with-param name="cEmptyMtd" select="$cEmptyMtd - 1"/>
      </xsl:call-template>
    </xsl:if>
  </xsl:template>

  <xsl:function name="x:CountMaxElmtsInRow" as="xs:integer">
    <xsl:param name="ndCur" as="element()?"/>
    <xsl:param name="cMaxElmtsInRow" as="xs:integer"/>
    <xsl:choose>
      <xsl:when test="not($ndCur)">
        <xsl:value-of select="$cMaxElmtsInRow"/>
      </xsl:when>
      <xsl:otherwise>
        <xsl:variable name="maxElmtsInRow" as="xs:integer">
          <xsl:choose>
            <xsl:when test="$ndCur/self::mml:mlabeledtr">
              <xsl:choose>
                <xsl:when test="(count($ndCur/*) - 1) gt $cMaxElmtsInRow">
                  <xsl:sequence select="count($ndCur/*) - 1"/>
                </xsl:when>
                <xsl:otherwise>
                  <xsl:sequence select="$cMaxElmtsInRow"/>
                </xsl:otherwise>
              </xsl:choose>
            </xsl:when>
            <xsl:when test="$ndCur/self::mml:mtr">
              <xsl:choose>
                <xsl:when test="count($ndCur/*) gt $cMaxElmtsInRow">
                  <xsl:sequence select="count($ndCur/*)"/>
                </xsl:when>
                <xsl:otherwise>
                  <xsl:sequence select="$cMaxElmtsInRow"/>
                </xsl:otherwise>
              </xsl:choose>
            </xsl:when>
            <xsl:otherwise>
              <xsl:choose>
                <xsl:when test="1 gt $cMaxElmtsInRow">
                  <xsl:sequence select="1"/>
                </xsl:when>
                <xsl:otherwise>
                  <xsl:sequence select="$cMaxElmtsInRow"/>
                </xsl:otherwise>
              </xsl:choose>
            </xsl:otherwise>
          </xsl:choose>
        </xsl:variable>
        <xsl:sequence select="x:CountMaxElmtsInRow($ndCur/following-sibling::*[1], $maxElmtsInRow)"
        />
      </xsl:otherwise>
    </xsl:choose>
  </xsl:function>

  <xsl:template name="GetMglyphAltText">
    <xsl:param name="ndCur" select="." as="element()?"/>
    <xsl:value-of select="normalize-space($ndCur/@alt)"/>
  </xsl:template>

  <xsl:template match="mml:mglyph">
    <m:r>
      <m:rPr>
        <m:nor/>
      </m:rPr>
      <m:t>
        <xsl:call-template name="OutputText">
          <xsl:with-param name="sInput">
            <xsl:call-template name="GetMglyphAltText">
              <xsl:with-param name="ndCur" select="."/>
            </xsl:call-template>
          </xsl:with-param>
        </xsl:call-template>
      </m:t>
    </m:r>
  </xsl:template>

  <!-- Omml doesn't really support mglyph, so just output the alt text -->
  <xsl:template
    match="
      mml:mi[mml:mglyph] |
      mml:mn[mml:mglyph] |
      mml:mo[mml:mglyph] |
      mml:ms[mml:mglyph] |
      mml:mtext[mml:mglyph]">
    <xsl:variable name="mathvariant" as="xs:string?" select="@mathvariant"/>
    <!-- Deprecated -->
    <xsl:variable name="fontstyle" as="xs:string?" select="@fontstyle"/>
    <!-- Deprecated -->
    <xsl:variable name="fontweight" as="xs:string?" select="@fontweight"/>
    <xsl:variable name="mathcolor" as="xs:string?" select="@mathcolor"/>
    <xsl:variable name="mathsize" as="xs:string?" select="@mathsize"/>
    <!-- Deprecated -->
    <xsl:variable name="color" as="xs:string?" select="@color"/>
    <!-- Deprecated -->
    <xsl:variable name="fontsize" as="xs:string?" select="@fontsize"/>
    <xsl:variable name="fNor" as="xs:boolean" select="x:FNor(.)"/>

    <!-- Output MS Left Quote (if need be) -->
    <xsl:if test="self::mml:ms">
      <xsl:variable name="chLquote" as="xs:string">
        <xsl:call-template name="LQuoteFromMs">
          <xsl:with-param name="msCur" select="."/>
        </xsl:call-template>
      </xsl:variable>
      <m:r>
        <xsl:call-template name="CreateRunProp">
          <xsl:with-param name="mathvariant" select="$mathvariant"/>
          <xsl:with-param name="fontstyle" select="$fontstyle"/>
          <xsl:with-param name="fontweight" select="$fontweight"/>
          <xsl:with-param name="mathcolor" select="$mathcolor"/>
          <xsl:with-param name="mathsize" select="$mathsize"/>
          <xsl:with-param name="color" select="$color"/>
          <xsl:with-param name="fontsize" select="$fontsize"/>
          <xsl:with-param name="fNor" select="$fNor"/>
          <xsl:with-param name="ndCur" select="."/>
        </xsl:call-template>
        <m:t>
          <xsl:call-template name="OutputText">
            <xsl:with-param name="sInput" select="$chLquote"/>
          </xsl:call-template>
        </m:t>
      </m:r>
    </xsl:if>
    <xsl:for-each select="mml:mglyph | text()">
      <xsl:variable name="fForceNor" as="xs:boolean" select="exists(self::mml:mglyph)"/>
      <xsl:variable name="str" as="xs:string">
        <xsl:choose>
          <xsl:when test="self::mml:mglyph">
            <xsl:call-template name="GetMglyphAltText">
              <xsl:with-param name="ndCur" select="."/>
            </xsl:call-template>
          </xsl:when>
          <xsl:otherwise>
            <xsl:value-of select="normalize-space(.)"/>
          </xsl:otherwise>
        </xsl:choose>
      </xsl:variable>
      <xsl:if test="string-length($str) gt 0">
        <m:r>
          <xsl:call-template name="CreateRunProp">
            <xsl:with-param name="mathvariant" select="$mathvariant"/>
            <xsl:with-param name="fontstyle" select="$fontstyle"/>
            <xsl:with-param name="fontweight" select="$fontweight"/>
            <xsl:with-param name="mathcolor" select="$mathcolor"/>
            <xsl:with-param name="mathsize" select="$mathsize"/>
            <xsl:with-param name="color" select="$color"/>
            <xsl:with-param name="fontsize" select="$fontsize"/>
            <xsl:with-param name="fNor">
              <xsl:choose>
                <xsl:when test="$fForceNor">
                  <xsl:sequence select="true()"/>
                </xsl:when>
                <xsl:otherwise>
                  <xsl:sequence select="$fNor"/>
                </xsl:otherwise>
              </xsl:choose>
            </xsl:with-param>
            <xsl:with-param name="ndCur" select="."/>
          </xsl:call-template>
          <m:t>
            <xsl:call-template name="OutputText">
              <xsl:with-param name="sInput" select="$str"/>
            </xsl:call-template>
          </m:t>
        </m:r>
      </xsl:if>
    </xsl:for-each>

    <!-- Output MS Right Quote (if need be) -->
    <xsl:if test="self::mml:ms">
      <xsl:variable name="chRquote" as="xs:string">
        <xsl:call-template name="RQuoteFromMs">
          <xsl:with-param name="msCur" select="."/>
        </xsl:call-template>
      </xsl:variable>
      <m:r>
        <xsl:call-template name="CreateRunProp">
          <xsl:with-param name="mathvariant" select="$mathvariant"/>
          <xsl:with-param name="fontstyle" select="$fontstyle"/>
          <xsl:with-param name="fontweight" select="$fontweight"/>
          <xsl:with-param name="mathcolor" select="$mathcolor"/>
          <xsl:with-param name="mathsize" select="$mathsize"/>
          <xsl:with-param name="color" select="$color"/>
          <xsl:with-param name="fontsize" select="$fontsize"/>
          <xsl:with-param name="fNor" select="$fNor"/>
          <xsl:with-param name="ndCur" select="."/>
        </xsl:call-template>
        <m:t>
          <xsl:call-template name="OutputText">
            <xsl:with-param name="sInput" select="$chRquote"/>
          </xsl:call-template>
        </m:t>
      </m:r>
    </xsl:if>
  </xsl:template>

  <xsl:function name="x:FStrContainsNonZeroDigit" as="xs:boolean">
    <xsl:param name="s" as="xs:string"/>
    <xsl:sequence select="contains(translate($s, '12345678', '99999999'), '9')"/>
  </xsl:function>

  <xsl:function name="x:FStrContainsDigits" as="xs:boolean">
    <xsl:param name="s" as="xs:string"/>
    <xsl:sequence select="contains(translate($s, '123456789', '000000000'), '0')"/>
  </xsl:function>


  <!-- Used to determine if mpadded attribute {width, height, depth } 
       indicates to show everything. 
       
       Unlike mathml, whose mpadded structure has great flexibility in modifying the 
       bounding box's width, height, and depth, Word can only have zero or full width, height, and depth.
       Thus, if the width, height, or depth attributes indicate any kind of nonzero width, height, 
       or depth, we'll translate that into a show full width, height, or depth for OMML.  Only if the attribute
       indicates a zero width, height, or depth, will we report back FFull as false.
       
       Example:  s=0%    ->  FFull returns 0.
                 s=2%    ->  FFull returns 1.
                 s=0.1em ->  FFull returns 1.     
       
       -->
  <xsl:function name="x:FFull" as="xs:boolean">
    <xsl:param name="s" as="xs:string?"/>

    <xsl:choose>
      <xsl:when test="empty($s)">
        <xsl:sequence select="true()"/>
      </xsl:when>
      <!-- String contained non-zero digit -->
      <xsl:when test="x:FStrContainsNonZeroDigit($s)">
        <xsl:sequence select="true()"/>
      </xsl:when>
      <!-- String didn't contain a non-zero digit, but it did contain digits.
           This must mean that all digits in the string were 0s. -->
      <xsl:when test="x:FStrContainsDigits($s)">
        <xsl:sequence select="false()"/>
      </xsl:when>
      <!-- Else, no digits, therefore, return true.
           We return true in the otherwise condition to take account for the possibility
           in MathML to say something like width="height". -->
      <xsl:otherwise>
        <xsl:sequence select="true()"/>
      </xsl:otherwise>
    </xsl:choose>
  </xsl:function>

  <!-- Just outputs phant properties, doesn't do any fancy 
       thinking of its own, just obeys the defaults of 
       phants. -->
  <xsl:template name="CreatePhantPropertiesCore">
    <xsl:param name="fShow" select="true()" as="xs:boolean"/>
    <xsl:param name="fFullWidth" select="true()" as="xs:boolean"/>
    <xsl:param name="fFullHeight" select="true()" as="xs:boolean"/>
    <xsl:param name="fFullDepth" select="true()" as="xs:boolean"/>

    <xsl:if
      test="
        not($fShow)
        or not($fFullWidth)
        or not($fFullHeight)
        or not($fFullDepth)">
      <m:phantPr>
        <xsl:if test="not($fShow)">
          <m:show m:val="off"/>
        </xsl:if>
        <xsl:if test="not($fFullWidth)">
          <m:zeroWid m:val="on"/>
        </xsl:if>
        <xsl:if test="not($fFullHeight)">
          <m:zeroAsc m:val="on"/>
        </xsl:if>
        <xsl:if test="not($fFullDepth)">
          <m:zeroDesc m:val="on"/>
        </xsl:if>
      </m:phantPr>
    </xsl:if>
  </xsl:template>

  <!-- Figures out if we should factor in width, height, and depth attributes.  
  
       If so, then it 
       gets these attributes, does some processing to figure out what the attributes indicate, 
       then passes these indications to CreatePhantPropertiesCore.  
       
       If we aren't supposed to factor in width, height, or depth, then we'll just output the show
       attribute. -->
  <xsl:template name="CreatePhantProperties">
    <xsl:param name="ndCur" select="." as="element()?"/>
    <xsl:param name="fShow" select="true()" as="xs:boolean"/>

    <xsl:choose>
      <!-- In the special case that we have an mphantom with one child which is an mpadded, then we should 
           subsume the mpadded attributes into the mphantom attributes.  The test statement below imples the 
           'one child which is an mpadded'.  The first part, that the parent of mpadded is an mphantom, is implied
           by being in this template, which is only called when we've encountered an mphantom.
           
           Word outputs its invisible phantoms with smashing as 

              <mml:mphantom>
                <mml:mpadded . . . >
                  
                </mml:mpadded>
              </mml:mphantom>

            This test is used to allow roundtripping smashed invisible phantoms. -->
      <xsl:when test="count($ndCur/*) = 1 and count($ndCur/mml:mpadded) = 1">
        <xsl:call-template name="CreatePhantPropertiesCore">
          <xsl:with-param name="fShow" select="$fShow"/>
          <xsl:with-param name="fFullWidth" select="x:FFull($ndCur/mml:mpadded/@width)"/>
          <xsl:with-param name="fFullHeight" select="x:FFull($ndCur/mml:mpadded/@height)"/>
          <xsl:with-param name="fFullDepth" select="x:FFull($ndCur/mml:mpadded/@depth)"/>
        </xsl:call-template>
      </xsl:when>
      <xsl:otherwise>
        <xsl:call-template name="CreatePhantPropertiesCore">
          <xsl:with-param name="fShow" select="$fShow"/>
        </xsl:call-template>
      </xsl:otherwise>
    </xsl:choose>
  </xsl:template>

  <xsl:template match="mml:mpadded">
    <xsl:choose>
      <xsl:when
        test="count(parent::mml:mphantom) = 1 and count(preceding-sibling::*) = 0 and count(following-sibling::*) = 0">
        <!-- This mpadded is inside an mphantom that has already setup phantom attributes, therefore, just apply templates -->
        <xsl:apply-templates select="*"/>
      </xsl:when>
      <xsl:otherwise>
        <m:phant>
          <xsl:call-template name="CreatePhantPropertiesCore">
            <xsl:with-param name="fShow" select="true()" as="xs:boolean"/>
            <xsl:with-param name="fFullWidth" select="x:FFull(@width)"/>
            <xsl:with-param name="fFullHeight" select="x:FFull(@height)"/>
            <xsl:with-param name="fFullDepth" select="x:FFull(@depth)"/>
          </xsl:call-template>
          <m:e>
            <xsl:apply-templates select="*"/>
          </m:e>
        </m:phant>
      </xsl:otherwise>
    </xsl:choose>
  </xsl:template>

  <xsl:template match="mml:mphantom">
    <m:phant>
      <xsl:call-template name="CreatePhantProperties">
        <xsl:with-param name="ndCur" select="."/>
        <xsl:with-param name="fShow" select="false()"/>
      </xsl:call-template>
      <m:e>
        <xsl:apply-templates select="*"/>
      </m:e>
    </m:phant>
  </xsl:template>

  <xsl:function name="x:isNaryOper" as="xs:boolean">
    <xsl:param name="sNdCur" as="xs:string"/>
    <xsl:sequence
      select="($sNdCur = '&#x222B;' or $sNdCur = '&#x222C;' or $sNdCur = '&#x222D;' or $sNdCur = '&#x222E;' or $sNdCur = '&#x222F;' or $sNdCur = '&#x2230;' or $sNdCur = '&#x2232;' or $sNdCur = '&#x2233;' or $sNdCur = '&#x2231;' or $sNdCur = '&#x2229;' or $sNdCur = '&#x222A;' or $sNdCur = '&#x220F;' or $sNdCur = '&#x2210;' or $sNdCur = '&#x2211;')"
    />
  </xsl:function>


  <xsl:function name="x:isNary" as="xs:boolean">
    <!-- ndCur is the element around the nAry operator -->
    <xsl:param name="ndCur" as="element()?"/>

    <xsl:variable name="sNdCur" as="xs:string" select="normalize-space($ndCur)"/>
    <xsl:variable name="fNaryOper" as="xs:boolean" select="x:isNaryOper($sNdCur)"/>
    <!-- Narys shouldn't be MathML accents.  -->
    <xsl:variable name="fUnder" as="xs:boolean" select="exists($ndCur/parent::*[self::mml:munder])"/>

    <xsl:variable name="sLowerCaseAccent" as="xs:string?">
      <xsl:choose>
        <xsl:when test="$fUnder">
          <xsl:value-of select="lower-case($ndCur/parent::*[self::mml:munder]/@accentunder)"/>
        </xsl:when>
        <xsl:when test="$ndCur/parent::*/@accent">
          <xsl:value-of select="lower-case($ndCur/parent::*/@accent)"/>
        </xsl:when>
      </xsl:choose>
    </xsl:variable>

    <xsl:variable name="fAccent" as="xs:boolean" select="$sLowerCaseAccent = 'true'"/>

    <!-- This ndCur is in fact part of an nAry if
      
           1)  The last descendant of ndCur (which could be ndCur itself) is an operator.
           2)  Along that chain of descendants we only encounter mml:mo, mml:mstyle, and mml:mrow elements.
           3)  the operator in mml:mo is a valid nAry operator
           4)  The nAry is not accented.
           -->
    <xsl:sequence
      select="
        $fNaryOper and
        not($fAccent) and
        $ndCur/descendant-or-self::*[last()]/self::mml:mo and
        empty($ndCur/descendant-or-self::*[empty(self::mml:mo | self::mml:mstyle | self::mml:mrow)])"
    />
  </xsl:function>

  <xsl:template name="CreateNaryProp">
    <xsl:param name="chr" as="xs:string"/>
    <xsl:param name="sMathmlType" as="xs:string"/>
    <m:naryPr>
      <m:chr m:val="{$chr}"/>
      <m:limLoc>
        <xsl:attribute name="m:val">
          <xsl:choose>
            <xsl:when test="$sMathmlType = ('munder', 'mover', 'munderover')">
              <xsl:text>undOvr</xsl:text>
            </xsl:when>
            <xsl:when test="$sMathmlType = ('msub', 'msup', 'msubsup')">
              <xsl:text>subSup</xsl:text>
            </xsl:when>
          </xsl:choose>
        </xsl:attribute>
      </m:limLoc>
      <m:grow m:val="on"/>
      <m:subHide>
        <xsl:attribute name="m:val">
          <xsl:choose>
            <xsl:when test="$sMathmlType = ('mover', 'msup')">
              <xsl:text>on</xsl:text>
            </xsl:when>
            <xsl:otherwise>
              <xsl:text>off</xsl:text>
            </xsl:otherwise>
          </xsl:choose>
        </xsl:attribute>
      </m:subHide>
      <m:supHide>
        <xsl:attribute name="m:val">
          <xsl:choose>
            <xsl:when test="$sMathmlType = ('munder', 'msub')">
              <xsl:text>on</xsl:text>
            </xsl:when>
            <xsl:otherwise>
              <xsl:text>off</xsl:text>
            </xsl:otherwise>
          </xsl:choose>
        </xsl:attribute>
      </m:supHide>
    </m:naryPr>
  </xsl:template>

</xsl:stylesheet>
