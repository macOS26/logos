#ifndef RVNGCSVSPREADSHEETGENERATOR_H
#define RVNGCSVSPREADSHEETGENERATOR_H
#include "librevenge-generators-api.h"
#include "librevenge.h"
#include "librevenge-stream.h"
namespace librevenge
{
struct RVNGCSVSpreadsheetGeneratorImpl;
class REVENGE_GENERATORS_API RVNGCSVSpreadsheetGenerator : public RVNGSpreadsheetInterface
{
	RVNGCSVSpreadsheetGenerator(const RVNGCSVSpreadsheetGenerator &other);
	RVNGCSVSpreadsheetGenerator &operator=(const RVNGCSVSpreadsheetGenerator &other);
public:
	explicit RVNGCSVSpreadsheetGenerator(RVNGStringVector &sheets, bool generateFormula=false);
	~RVNGCSVSpreadsheetGenerator();
	void setSeparators(char fieldSep=',', char textSep='"', char decimalSep='.');
	void setDTFormats(RVNGString const &date="%m/%d/%y", RVNGString const &time="%H:%M:%S");
	void setDocumentMetaData(const RVNGPropertyList &propList);
	void defineEmbeddedFont(const RVNGPropertyList &propList);
	void startDocument(const RVNGPropertyList &propList);
	void endDocument();
	void defineSheetNumberingStyle(const RVNGPropertyList &propList);
	void openSheet(const RVNGPropertyList &propList);
	void closeSheet();
	void openSheetRow(const RVNGPropertyList &propList);
	void closeSheetRow();
	void openSheetCell(const RVNGPropertyList &propList);
	void closeSheetCell();
	void defineChartStyle(const RVNGPropertyList &propList);
	void openChart(const RVNGPropertyList &propList);
	void closeChart();
	void openChartTextObject(const RVNGPropertyList &propList);
	void closeChartTextObject();
	void openChartPlotArea(const RVNGPropertyList &propList);
	void closeChartPlotArea();
	void insertChartAxis(const RVNGPropertyList &axis);
	void openChartSerie(const librevenge::RVNGPropertyList &series);
	void closeChartSerie();
	void definePageStyle(const RVNGPropertyList &propList);
	void openPageSpan(const RVNGPropertyList &propList);
	void closePageSpan();
	void openHeader(const RVNGPropertyList &propList);
	void closeHeader();
	void openFooter(const RVNGPropertyList &propList);
	void closeFooter();
	void defineParagraphStyle(const RVNGPropertyList &propList);
	void openParagraph(const RVNGPropertyList &propList);
	void closeParagraph();
	void defineCharacterStyle(const RVNGPropertyList &propList);
	void openSpan(const RVNGPropertyList &propList);
	void closeSpan();
	void openLink(const RVNGPropertyList &propList);
	void closeLink();
	void defineSectionStyle(const RVNGPropertyList &propList);
	void openSection(const RVNGPropertyList &propList);
	void closeSection();
	void insertTab();
	void insertSpace();
	void insertText(const RVNGString &text);
	void insertLineBreak();
	void insertField(const RVNGPropertyList &propList);
	void openOrderedListLevel(const RVNGPropertyList &propList);
	void openUnorderedListLevel(const RVNGPropertyList &propList);
	void closeOrderedListLevel();
	void closeUnorderedListLevel();
	void openListElement(const RVNGPropertyList &propList);
	void closeListElement();
	void openFootnote(const RVNGPropertyList &propList);
	void closeFootnote();
	void openEndnote(const RVNGPropertyList &propList);
	void closeEndnote();
	void openComment(const RVNGPropertyList &propList);
	void closeComment();
	void openTextBox(const RVNGPropertyList &propList);
	void closeTextBox();
	void openTable(const RVNGPropertyList &propList);
	void openTableRow(const RVNGPropertyList &propList);
	void closeTableRow();
	void openTableCell(const RVNGPropertyList &propList);
	void closeTableCell();
	void insertCoveredTableCell(const RVNGPropertyList &propList);
	void closeTable();
	void openFrame(const RVNGPropertyList &propList);
	void closeFrame();
	void insertBinaryObject(const RVNGPropertyList &propList);
	void openGroup(const RVNGPropertyList &propList);
	void closeGroup();
	void defineGraphicStyle(const RVNGPropertyList &propList);
	void drawRectangle(const RVNGPropertyList &propList);
	void drawEllipse(const RVNGPropertyList &propList);
	void drawPolygon(const RVNGPropertyList &propList);
	void drawPolyline(const RVNGPropertyList &propList);
	void drawPath(const RVNGPropertyList &propList);
	void drawConnector(const RVNGPropertyList &propList);
	void insertEquation(const RVNGPropertyList &propList);
private:
	RVNGCSVSpreadsheetGeneratorImpl *m_impl;
};
}
#endif
