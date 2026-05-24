#ifndef RVNGTEXTDRAWINGGENERATOR_H
#define RVNGTEXTDRAWINGGENERATOR_H
#include "librevenge-generators-api.h"
#include "librevenge-stream.h"
#include "librevenge.h"
namespace librevenge
{
struct RVNGTextDrawingGeneratorImpl;
class REVENGE_GENERATORS_API RVNGTextDrawingGenerator : public RVNGDrawingInterface
{
	RVNGTextDrawingGenerator(const RVNGTextDrawingGenerator &other);
	RVNGTextDrawingGenerator &operator=(const RVNGTextDrawingGenerator &other);
public:
	explicit RVNGTextDrawingGenerator(RVNGStringVector &pages);
	~RVNGTextDrawingGenerator();
	void startDocument(const RVNGPropertyList &propList);
	void endDocument();
	void setDocumentMetaData(const RVNGPropertyList &propList);
	void defineEmbeddedFont(const RVNGPropertyList &propList);
	void startPage(const RVNGPropertyList &);
	void endPage();
	void startMasterPage(const RVNGPropertyList &propList);
	void endMasterPage();
	void startLayer(const RVNGPropertyList &);
	void endLayer();
	void startEmbeddedGraphics(const RVNGPropertyList &);
	void endEmbeddedGraphics();
	void openGroup(const RVNGPropertyList &propList);
	void closeGroup();
	void setStyle(const RVNGPropertyList &);
	void drawRectangle(const RVNGPropertyList &);
	void drawEllipse(const RVNGPropertyList &);
	void drawPolyline(const RVNGPropertyList &);
	void drawPolygon(const RVNGPropertyList &);
	void drawPath(const RVNGPropertyList &);
	void drawGraphicObject(const RVNGPropertyList &);
	void drawConnector(const RVNGPropertyList &propList);
	void startTextObject(const RVNGPropertyList &);
	void endTextObject();
	void startTableObject(const RVNGPropertyList &propList);
	void openTableRow(const RVNGPropertyList &propList);
	void closeTableRow();
	void openTableCell(const RVNGPropertyList &propList);
	void closeTableCell();
	void insertCoveredTableCell(const RVNGPropertyList &propList);
	void endTableObject();
	void openOrderedListLevel(const RVNGPropertyList &propList);
	void closeOrderedListLevel();
	void openUnorderedListLevel(const RVNGPropertyList &propList);
	void closeUnorderedListLevel();
	void openListElement(const RVNGPropertyList &propList);
	void closeListElement();
	void defineParagraphStyle(const RVNGPropertyList &propList);
	void openParagraph(const RVNGPropertyList &propList);
	void closeParagraph();
	void defineCharacterStyle(const RVNGPropertyList &propList);
	void openSpan(const RVNGPropertyList &propList);
	void closeSpan();
	void openLink(const RVNGPropertyList &propList);
	void closeLink();
	void insertTab();
	void insertSpace();
	void insertText(const RVNGString &text);
	void insertLineBreak();
	void insertField(const RVNGPropertyList &propList);
private:
	RVNGTextDrawingGeneratorImpl *m_impl;
};
}
#endif
