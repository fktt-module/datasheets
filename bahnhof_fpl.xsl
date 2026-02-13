<?xml version="1.0" encoding="utf-8"?>
<xsl:stylesheet version="1.0" xmlns:xsl="http://www.w3.org/1999/XSL/Transform">
<xsl:output method="html" encoding="utf-8"/>
   <xsl:variable name="maxcols">10</xsl:variable>
   <xsl:variable name="fontsize">+1</xsl:variable>
	<xsl:variable name="week">7</xsl:variable>
	<xsl:variable name="scale"><xsl:value-of select="//bahnhof/maszstab"/></xsl:variable>
	<xsl:variable name="locolength">20</xsl:variable>
	<xsl:variable name="meanaxlelength">5</xsl:variable>
	<xsl:variable name="filterStueckgut" select="'stueckgut'" />
	<xsl:variable name="filterExpressgut" select="'expressgut'"/>
   <xsl:template match="/">
	   <xsl:text disable-output-escaping="yes">&lt;!DOCTYPE html&gt;</xsl:text>
      <html lang="de">
			<head>
				<title><xsl:value-of select="bahnhof/name"/> - Fahrplaner Ansicht</title>
				<link rel="stylesheet" type="text/css" href="bahnhof.css" />
				<link rel="icon" href="data:," />
			</head>
         <body>
            <xsl:for-each select="bahnhof">
               <table border="1">
                  <tr>
                     <td class="links" colspan="8">Betriebsstelle: <span><xsl:value-of select="name"/></span></td>
                     <td class="links" colspan="1"><xsl:text disable-output-escaping="yes">Kürzel: </xsl:text><span><xsl:value-of select="kuerzel"/></span></td>
                     <td class="links" colspan="1">Typ: <span><xsl:value-of select="typ"/></span></td>
                  </tr>
                  <xsl:apply-templates select="plan"/>
                  <xsl:call-template name="leerzeile"/>
                  <xsl:apply-templates select="gleise"/>
                  <xsl:call-template name="leerzeile"/>
                  <xsl:apply-templates select="pv"/>
                  <xsl:call-template name="leerzeile"/>
                  <xsl:apply-templates select="gv"/>
                  <xsl:call-template name="leerzeile"/>
                  <xsl:call-template name="caroutput"/>
                  <xsl:call-template name="leerzeile"/>
                  <xsl:apply-templates select="bemerkung"/>
               </table>
            </xsl:for-each>
         </body>
      </html>
   </xsl:template>
   <xsl:template name="leerzeile">
      <tr><td colspan="{$maxcols}"><xsl:text disable-output-escaping="yes">&#160;</xsl:text></td></tr>
   </xsl:template>
	<!-- Achslaenge fuer die Haupt- und Nebengleise -->
	<xsl:template name="achslaenge">
		<xsl:param name="nlaenge"/>
		<xsl:param name="lattri" select="$nlaenge/attribute::einheit" />
		<xsl:param name="cmscale" select="$scale div 100" />
		<xsl:param name="mmscale" select="$scale div 1000" />
		<xsl:param name="whichtracktype" select="name(..)" /><!-- hgleise oder ngleise -->
		<!-- hinweis: es wurde gerechnet floor(x/2)*2 damit eine gerade Zahl herauskommt -->
		<xsl:if test="not($lattri) or $lattri='mm'">
		   <xsl:choose>
				<xsl:when test="$whichtracktype='ngleise'">
					<!--<xsl:value-of select="floor( ( (($nlaenge*$mmscale)) div ($meanaxlelength) ) div 2)*2"/>-->
					<xsl:value-of select="floor( ( ( ($nlaenge div 10) * 2) div 10 ) div 2)*2"/>
				</xsl:when>
				<xsl:otherwise>
					<!--<xsl:value-of select="floor( ( (($nlaenge*$mmscale)-$locolength) div ($meanaxlelength) ) div 2)*2"/>-->
					<xsl:value-of select="floor( ( (($nlaenge*$mmscale)-$locolength) div ($meanaxlelength) ) div 2)*2"/>
				</xsl:otherwise>
			</xsl:choose>
		</xsl:if>
		<xsl:if test="$lattri='cm'">
		   <xsl:choose>
				<xsl:when test="$whichtracktype='ngleise'">
					<!--<xsl:value-of select="floor( ( (($nlaenge*$cmscale)) div (5) ) div 2)*2"/>-->
					<xsl:value-of select="floor( ( ( ($nlaenge*2)) div 10 ) div 2)*2"/>
				</xsl:when>
				<xsl:otherwise>
					<!--<xsl:value-of select="floor( ( (($nlaenge*$cmscale)-$locolength) div ($meanaxlelength) ) div 2)*2"/>-->
					<xsl:value-of select="floor( ( (($nlaenge*$cmscale)-$locolength) div ($meanaxlelength) ) div 2)*2"/>
				</xsl:otherwise>
			</xsl:choose>
		</xsl:if>
		<xsl:if test="$lattri='achsen'">
		   <xsl:value-of select="floor($nlaenge)"/>
		</xsl:if>
	</xsl:template>
	<!-- Achslaenge fuer die Ladestellen -->
	<xsl:template name="achslaenge1">
		<xsl:param name="nlaenge"/>
		<!-- anders kommt man an den Attributwert nicht heran! -->
		<xsl:param name="lattri" select="$nlaenge/attribute::einheit" />
		<xsl:param name="cmscale" select="$scale div 100" />
		<xsl:param name="mscale" select="$scale div 1000" />
		<!-- hinweis: es wurde gerechnet floor(x/2)*2 damit eine gerade Zahl herauskommt -->
		<xsl:if test="not($lattri) or $lattri='mm'">
					<!--<xsl:value-of select="floor( ( (($nlaenge*$mscale)) div ($meanaxlelength) ) div 2)*2"/>-->
					<xsl:value-of select="floor( ( ( ($nlaenge div 10) *2 ) div 10 ) div 2)*2"/>
		</xsl:if>
		<xsl:if test="$lattri='cm'">
					<!--<xsl:value-of select="floor( ( (($nlaenge*$cmscale)) div (5) ) div 2)*2"/>-->
					<xsl:value-of select="floor( ( ( ($nlaenge div 1) *2 ) div 10 ) div 2)*2"/>
		</xsl:if>
		<xsl:if test="$lattri='achsen'">
		   <!--<xsl:value-of select="floor($nlaenge)"/>-->
		   <xsl:value-of select="floor($nlaenge)"/>
		</xsl:if>
	</xsl:template>
   <!-- So hier schauen wir mal ob wir etwas formatieren müssen  -->
   <xsl:template name="recurse_break">
      <xsl:param name="idlist"/>
      <xsl:variable name="normidlist" select="concat(normalize-space($idlist),' ')"/>
      <xsl:variable name="firstid" select="substring-before($normidlist,'[br]')"/>
      <xsl:variable name="restidlist" select="substring-after($normidlist,'[br]')"/>
      <xsl:choose>
         <xsl:when test="$firstid != ''">
				<xsl:value-of select="$firstid"/><br/>
				<xsl:if test="$restidlist != ''">
					<xsl:call-template name="recurse_break">
						<xsl:with-param name="idlist" select="$restidlist"/>
					</xsl:call-template>
				</xsl:if>
         </xsl:when>
         <xsl:otherwise>
            <xsl:value-of select="$normidlist"/>
         </xsl:otherwise>
      </xsl:choose>
   </xsl:template>
   <xsl:template match="plan">
      <tr><td class="mitte" colspan="{$maxcols}"><img src="{@src}" alt="Gleisplan"></img></td></tr>
   </xsl:template>
   <xsl:template match="gleise">
      <tr>
         <td colspan="{$maxcols -8}"><xsl:text disable-output-escaping="yes">&#160;</xsl:text></td>
         <td class="rechts"><xsl:text disable-output-escaping="yes">Nutzlänge</xsl:text></td>
         <td class="rechts"><xsl:text disable-output-escaping="yes">Nutzlänge (Achsen)</xsl:text></td>
         <td colspan="{$maxcols -4}"><xsl:text disable-output-escaping="yes">&#160;Bemerkung</xsl:text></td>
      </tr>
		<tr><td colspan="{$maxcols}"><span class="m">Hauptgleise</span></td></tr>
		<xsl:for-each select="hgleise/gleis">
			<xsl:call-template name="ugleis"/>
		</xsl:for-each>
		<!-- zaehle die vorhandenen Nebengleise -->
		<xsl:variable name="content"><xsl:value-of select="count(ngleise/*)"/></xsl:variable>
		<!-- Wenn es welche gibt dann gebe sie aus -->
		<xsl:if test="$content &gt; 0">
			<tr><td colspan="{$maxcols}"><span class="m">Nebengleise</span></td></tr>
			<xsl:for-each select="ngleise/gleis">
				<xsl:call-template name="ugleis"/>
			</xsl:for-each>
		</xsl:if>
		<tr>
		   <td colspan="{$maxcols}">
			<xsl:text disable-output-escaping="yes">Anmerkung: Die Berechnung der Nutzlänge in Achsen beruht auf den Annahmen: 10 cm Nutzlänge entsprechen 2 Achsen</xsl:text>
			<!-- Auskommentiert balsines Original -->
			<!--Loklänge 20 m (wird bei Hauptgleisen abgezogen) und durchschnittlich 5 m pro Achse-->
			<!--</xsl:text>-->
		   </td>
		</tr>
   </xsl:template>
   <xsl:template match="laenge">
      <xsl:value-of select="."/>
      <xsl:text disable-output-escaping="yes">&#160;</xsl:text>
      <xsl:choose>
         <xsl:when test="@einheit">
            <xsl:choose>
               <xsl:when test="@einheit='achsen'">Achsen</xsl:when>
               <xsl:otherwise>
                  <xsl:value-of select="@einheit"/>
               </xsl:otherwise>
            </xsl:choose>
         </xsl:when>
         <xsl:otherwise>mm</xsl:otherwise>
      </xsl:choose>
   </xsl:template>
   <xsl:template name="ugleis">
      <tr>
         <td colspan="{$maxcols -8}">Gleis <span class="m"><xsl:value-of select="name"/></span></td>
			<td class="rechts"><span class="m"><xsl:apply-templates select="laenge"/></span></td>
			<td class="rechts"><span class="m">
				<xsl:call-template name="achslaenge1">
					<xsl:with-param name="nlaenge" select="laenge" />
				</xsl:call-template>
			</span></td>
			<td colspan="{$maxcols -4}">
				<xsl:text disable-output-escaping="yes">&#160;</xsl:text>
				<xsl:value-of select="bemerkung"/>
			</td>
      </tr>
   </xsl:template>
   <xsl:template match="pv">
      <tr>
         <td><xsl:text disable-output-escaping="yes">&#160;</xsl:text></td>
         <td class="mitte">Gleis</td>
			<td class="rechts"><xsl:text disable-output-escaping="yes">Länge</xsl:text></td>
			<td colspan="{$maxcols -3}" rowspan="{count(bahnsteig)+1}" class="mitte oben">Bemerkungen zum Personenverkehr:<br/>
				<span class="m">
						<xsl:call-template name="recurse_break">
							<xsl:with-param name="idlist" select="bemerkung"/>
						</xsl:call-template>
				</span>
			</td>
      </tr>
      <xsl:apply-templates select="bahnsteig"/>
   </xsl:template>
   <xsl:template match="bahnsteig">
      <tr>
         <td>Bahnsteig <span class="m"><xsl:value-of select="name"/></span></td>
			<td class="mitte">
            <span class="m">
				<xsl:call-template name="recurse_id">
					<xsl:with-param name="key" select="'gleise'"/>
					<xsl:with-param name="idlist" select="@gleis"/>
				</xsl:call-template>
				</span>
			</td>
			<td class="rechts"><span class="m"><xsl:apply-templates select="laenge"/></span></td>
      </tr>
   </xsl:template>
   <xsl:key name="gleise" match="gleis" use="@id"/>
   <xsl:template name="recurse_id">
      <xsl:param name="key"/>
      <xsl:param name="idlist"/>
      <xsl:variable name="normidlist" select="concat(normalize-space($idlist),' ')"/>
      <xsl:variable name="firstid" select="substring-before($normidlist,' ')"/>
      <xsl:variable name="restidlist" select="substring-after($normidlist,' ')"/>
      <xsl:if test="$firstid != ''">
			<xsl:value-of select="key($key,$firstid)/name"/>
			<xsl:if test="$restidlist != ''">
				<xsl:text disable-output-escaping="yes">, </xsl:text>
				<xsl:call-template name="recurse_id">
					<xsl:with-param name="key" select="$key"/>
					<xsl:with-param name="idlist" select="$restidlist"/>
				</xsl:call-template>
         </xsl:if>
      </xsl:if>
   </xsl:template>
   <xsl:template match="gv">
      <tr>
			<td colspan="{$maxcols}" class="mitte oben">
			<xsl:text disable-output-escaping="yes">Bemerkungen zum Güterverkehr:</xsl:text>
			<br/><span class="m">
	      <xsl:call-template name="recurse_break">
				<xsl:with-param name="idlist" select="bemerkung"/>
	      </xsl:call-template>
			</span>
			</td>
      </tr>
   </xsl:template>
   <xsl:template match="bemerkung">
      <tr>
         <td colspan="{$maxcols}">Allgemeine Bemerkungen zur Betriebsstelle:<br/><br/>
				<span class="m">
						<xsl:call-template name="recurse_break">
							<xsl:with-param name="idlist" select="."/>
						</xsl:call-template>
				</span>
         </td>
      </tr>
   </xsl:template>
	<xsl:template name="max">
		<xsl:param name="v1" />
		<xsl:param name="v2" />
		<xsl:choose>
			<xsl:when test="$v1 &lt; $v2">
				<xsl:value-of select="$v2"/>
			</xsl:when>
			<xsl:otherwise>
				<xsl:value-of select="$v1"/>
			</xsl:otherwise>
		</xsl:choose>
	</xsl:template>
	<xsl:template name="min">
		<xsl:param name="v1" />
		<xsl:param name="v2" />
		<xsl:choose>
			<xsl:when test="$v2 &lt; $v1">
				<xsl:value-of select="$v2"/>
			</xsl:when>
			<xsl:otherwise>
				<xsl:value-of select="$v1"/>
			</xsl:otherwise>
		</xsl:choose>
	</xsl:template>
	<xsl:template name="caroutput">
		<!-- diesen wert nehmen und dann je nachdem ob Tag oder Woche ist mit 1 oder 5,5 multiplizieren und addieren -->
		<!-- Wichtig zu wissen!!!
			  laut Definition ist als Zeitraum "Woche" angenommen, wenn kein Zeitraum explizit angegeben wird!
			  das bedeutet fuer die Rechnerei, dass man die Gesamtwagenmenge nimmt:
			  sum(gv/verlader/versand/ladegut/wagen)
			  und von dieser Gesamtmenge die Tagesmenge abzieht:
			  sum(gv/verlader/versand/ladegut/wagen[@zeitraum='tag'])
			  somit erhaelt man die Wochenmenge, wobei egal ist ob beim Zeitraum Woche angegeben ist oder nicht!
			  Man erhaelt auf diese Weise IMMER die richtige Menge am Ende!
		-->
		<xsl:variable name="FrachtgutEmpfang"    select="gv/verlader/empfang/ladegut[not(@typ=$filterStueckgut) and not(@typ=$filterExpressgut)]/wagen"/>
		<xsl:variable name="FrachtgutEmpfangTag" select="gv/verlader/empfang/ladegut[not(@typ=$filterStueckgut) and not(@typ=$filterExpressgut)]/wagen[@zeitraum='tag']"/>
		<xsl:variable name="FrachtgutVersand"    select="gv/verlader/versand/ladegut[not(@typ=$filterStueckgut) and not(@typ=$filterExpressgut)]/wagen"/>
		<xsl:variable name="FrachtgutVersandTag" select="gv/verlader/versand/ladegut[not(@typ=$filterStueckgut) and not(@typ=$filterExpressgut)]/wagen[@zeitraum='tag']"/>
		<xsl:variable name="StueckgutEmpfang"    select="gv/verlader/empfang/ladegut[@typ=$filterStueckgut]/wagen"/>
		<xsl:variable name="StueckgutEmpfangTag" select="gv/verlader/empfang/ladegut[@typ=$filterStueckgut]/wagen[@zeitraum='tag']"/>
		<xsl:variable name="StueckgutVersand"    select="gv/verlader/versand/ladegut[@typ=$filterStueckgut]/wagen"/>
		<xsl:variable name="StueckgutVersandTag" select="gv/verlader/versand/ladegut[@typ=$filterStueckgut]/wagen[@zeitraum='tag']"/>
		<xsl:variable name="ExpressgutEmpfang"    select="gv/verlader/empfang/ladegut[@typ=$filterExpressgut]/wagen"/>
		<xsl:variable name="ExpressgutEmpfangTag" select="gv/verlader/empfang/ladegut[@typ=$filterExpressgut]/wagen[@zeitraum='tag']"/>
		<xsl:variable name="ExpressgutVersand"    select="gv/verlader/versand/ladegut[@typ=$filterExpressgut]/wagen"/>
		<xsl:variable name="ExpressgutVersandTag" select="gv/verlader/versand/ladegut[@typ=$filterExpressgut]/wagen[@zeitraum='tag']"/>
        <tr>
			<td colspan="{$maxcols}" class="mitte">
				<table border="1" style="margin: 0 auto;">
					<tr>
						<td rowspan="2"><xsl:text disable-output-escaping="yes">&#160;&#160;&#160;</xsl:text></td>
						<td colspan="2"><xsl:text disable-output-escaping="yes">Wagenmenge</xsl:text></td>
						<td rowspan="5"><xsl:text disable-output-escaping="yes">&#160;&#160;&#160;</xsl:text></td>
						<td colspan="2"><xsl:text disable-output-escaping="yes">Stückgutwagenmenge</xsl:text></td>
						<td rowspan="5"><xsl:text disable-output-escaping="yes">&#160;&#160;&#160;</xsl:text></td>
						<td colspan="2"><xsl:text disable-output-escaping="yes">Expressgutwagenmenge</xsl:text></td>
					</tr>
					<tr>
						<td><xsl:text disable-output-escaping="yes">pro Tag</xsl:text></td>
						<td><xsl:text disable-output-escaping="yes">pro Woche</xsl:text></td>
						<td><xsl:text disable-output-escaping="yes">pro Tag</xsl:text></td>
						<td><xsl:text disable-output-escaping="yes">pro Woche</xsl:text></td>
						<td><xsl:text disable-output-escaping="yes">pro Tag</xsl:text></td>
						<td><xsl:text disable-output-escaping="yes">pro Woche</xsl:text></td>
					</tr>
					<tr>
						<td style="text-align:right;"><xsl:text disable-output-escaping="yes">Empfang</xsl:text></td>
						<td><xsl:value-of select="format-number(sum($FrachtgutEmpfangTag)+((sum($FrachtgutEmpfang)-sum($FrachtgutEmpfangTag)) div $week),'###.#')"/></td>
						<td><xsl:value-of select="($week* sum($FrachtgutEmpfangTag))+(sum($FrachtgutEmpfang)-sum($FrachtgutEmpfangTag))"/></td>
						<td><xsl:value-of select="format-number(sum($StueckgutEmpfangTag)+((sum($StueckgutEmpfang)-sum($StueckgutEmpfangTag)) div $week),'###.#')"/></td>
						<td><xsl:value-of select="($week* sum($StueckgutEmpfangTag))+(sum($StueckgutEmpfang)-sum($StueckgutEmpfangTag))"/></td>
						<td><xsl:value-of select="format-number(sum($ExpressgutEmpfangTag)+((sum($ExpressgutEmpfang)-sum($ExpressgutEmpfangTag)) div $week),'###.#')"/></td>
						<td><xsl:value-of select="($week* sum($ExpressgutEmpfangTag))+(sum($ExpressgutEmpfang)-sum($ExpressgutEmpfangTag))"/></td>
					</tr>
					<tr>
						<td style="text-align:right;"><xsl:text disable-output-escaping="yes">Versand</xsl:text></td>
						<td><xsl:value-of select="format-number(sum($FrachtgutVersandTag)+((sum($FrachtgutVersand)-sum($FrachtgutVersandTag)) div $week),'###.#')"/></td>
						<td><xsl:value-of select="($week* sum($FrachtgutVersandTag))+(sum($FrachtgutVersand)-sum($FrachtgutVersandTag))"/></td>
						<td><xsl:value-of select="format-number(sum($StueckgutVersandTag)+((sum($StueckgutVersand)-sum($StueckgutVersandTag)) div $week),'###.#')"/></td>
						<td><xsl:value-of select="($week* sum($StueckgutVersandTag))+(sum($StueckgutVersand)-sum($StueckgutVersandTag))"/></td>
						<td><xsl:value-of select="format-number(sum($ExpressgutVersandTag)+((sum($ExpressgutVersand)-sum($ExpressgutVersandTag)) div $week),'###.#')"/></td>
						<td><xsl:value-of select="($week* sum($ExpressgutVersandTag))+(sum($ExpressgutVersand)-sum($ExpressgutVersandTag))"/></td>
					</tr>
					<tr style="font-weight:bold;">
						<td style="text-align:right;"><xsl:text disable-output-escaping="yes">Gesamt</xsl:text></td>
						<td><xsl:value-of select="format-number(sum($FrachtgutEmpfangTag)+sum($FrachtgutVersandTag)+((sum($FrachtgutEmpfang)+sum($FrachtgutVersand)-sum($FrachtgutEmpfangTag)-sum($FrachtgutVersandTag)) div $week),'###.#')"/></td>
						<td><xsl:value-of select="($week* ( sum($FrachtgutEmpfangTag)+sum($FrachtgutVersandTag) ))+(sum($FrachtgutEmpfang)+sum($FrachtgutVersand)-sum($FrachtgutEmpfangTag)-sum($FrachtgutVersandTag))"/></td>
						<td><xsl:call-template name="max">
							<xsl:with-param name="v1" select="format-number(sum($StueckgutEmpfangTag) + ((sum($StueckgutEmpfang)-sum($StueckgutEmpfangTag)) div $week), '###.#')"/>
							<xsl:with-param name="v2" select="format-number(sum($StueckgutVersandTag) + ((sum($StueckgutVersand)-sum($StueckgutVersandTag)) div $week), '###.#')"/>
						</xsl:call-template></td>
						<td><xsl:call-template name="max">
							<xsl:with-param name="v1" select="($week * sum($StueckgutEmpfangTag)) + (sum($StueckgutEmpfang)-sum($StueckgutEmpfangTag))"/>
							<xsl:with-param name="v2" select="($week * sum($StueckgutVersandTag)) + (sum($StueckgutVersand)-sum($StueckgutVersandTag))"/>
						</xsl:call-template></td>
						<td><xsl:call-template name="max">
							<xsl:with-param name="v1" select="format-number(sum($ExpressgutEmpfangTag) + ((sum($ExpressgutEmpfang)-sum($ExpressgutEmpfangTag)) div $week), '###.#')"/>
							<xsl:with-param name="v2" select="format-number(sum($ExpressgutVersandTag) + ((sum($ExpressgutVersand)-sum($ExpressgutVersandTag)) div $week), '###.#')"/>
						</xsl:call-template></td>
						<td><xsl:call-template name="max">
							<xsl:with-param name="v1" select="($week * sum($ExpressgutEmpfangTag)) + (sum($ExpressgutEmpfang)-sum($ExpressgutEmpfangTag))"/>
							<xsl:with-param name="v2" select="($week * sum($ExpressgutVersandTag)) + (sum($ExpressgutVersand)-sum($ExpressgutVersandTag))"/>
						</xsl:call-template></td>
					</tr>
				</table>
			</td>
		</tr>
		<tr>
		   <td colspan="{$maxcols}"><xsl:text disable-output-escaping="yes">Anmerkung: Die Ergebnisse für die </xsl:text><span style="font-size:medium"><xsl:text disable-output-escaping="yes">Wagenmenge</xsl:text></span><xsl:text disable-output-escaping="yes"> sind unter Annahme einer 7-Tage Woche und keiner Wiederbeladung leerer Wagen berechnet worden!</xsl:text></td>
		</tr>
	</xsl:template>
</xsl:stylesheet>
