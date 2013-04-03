<xsl:stylesheet version="1.0"
            xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
            xmlns:msxsl="urn:schemas-microsoft-com:xslt"
            exclude-result-prefixes="msxsl"
            xmlns:wix="http://schemas.microsoft.com/wix/2006/wi">

  <xsl:output method="xml" indent="yes" />

  <xsl:strip-space elements="*"/>

  <xsl:template match="@*|node()">
    <xsl:copy>
      <xsl:apply-templates select="@*|node()"/>
    </xsl:copy>
  </xsl:template>

  <xsl:template match='wix:Wix/wix:Fragment/wix:DirectoryRef[@Id and (@Id = "INSTALLDIR")]/wix:Directory'>
    <xsl:copy>
      <xsl:apply-templates select="@*"/>
      <xsl:attribute name="FileSource">
        <xsl:text>$(var.Python27SourcePath)</xsl:text>
      </xsl:attribute>
      <xsl:attribute name="Name">
        <xsl:text>Python27</xsl:text>
      </xsl:attribute>
    </xsl:copy>
  </xsl:template>
</xsl:stylesheet>