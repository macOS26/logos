#ifndef RVNGDRAWINGINTERFACE_H
#define RVNGDRAWINGINTERFACE_H
#include "RVNGPropertyList.h"
#include "RVNGPropertyListVector.h"
#include "RVNGBinaryData.h"
namespace librevenge
{
class RVNGDrawingInterface
{
public:
	virtual ~RVNGDrawingInterface() {}
	virtual void startDocument(const RVNGPropertyList &propList) = 0;
	virtual void endDocument() = 0;
	virtual void setDocumentMetaData(const RVNGPropertyList &propList) = 0;
	virtual void defineEmbeddedFont(const RVNGPropertyList &propList) = 0;
	virtual void startPage(const RVNGPropertyList &propList) = 0;
	virtual void endPage() = 0;
	virtual void startMasterPage(const RVNGPropertyList &propList) = 0;
	virtual void endMasterPage() = 0;
	virtual void setStyle(const RVNGPropertyList &propList) = 0;
	virtual void startLayer(const RVNGPropertyList &propList) = 0;
	virtual void endLayer() = 0;
	virtual void startEmbeddedGraphics(const RVNGPropertyList &propList) = 0;
	virtual void endEmbeddedGraphics() = 0;
	virtual void openGroup(const RVNGPropertyList &propList) = 0;
	virtual void closeGroup() = 0;
	virtual void drawRectangle(const RVNGPropertyList &propList) = 0;
	virtual void drawEllipse(const RVNGPropertyList &propList) = 0;
	virtual void drawPolygon(const RVNGPropertyList &propList) = 0;
	virtual void drawPolyline(const RVNGPropertyList &propList) = 0;
	virtual void drawPath(const RVNGPropertyList &propList) = 0;
	virtual void drawGraphicObject(const RVNGPropertyList &propList) = 0;
	virtual void drawConnector(const RVNGPropertyList &propList) = 0;
	virtual void startTextObject(const RVNGPropertyList &propList) = 0;
	virtual void endTextObject() = 0;
	virtual void startTableObject(const RVNGPropertyList &propList) = 0;
	virtual void openTableRow(const RVNGPropertyList &propList) = 0;
	virtual void closeTableRow() = 0;
	virtual void openTableCell(const RVNGPropertyList &propList) = 0;
	virtual void closeTableCell() = 0;
	virtual void insertCoveredTableCell(const RVNGPropertyList &propList) = 0;
	virtual void endTableObject() = 0;
	virtual void insertTab() = 0;
	virtual void insertSpace() = 0;
	virtual void insertText(const RVNGString &text) = 0;
	virtual void insertLineBreak() = 0;
	virtual void insertField(const RVNGPropertyList &propList) = 0;
	virtual void openOrderedListLevel(const RVNGPropertyList &propList) = 0;
	virtual void openUnorderedListLevel(const RVNGPropertyList &propList) = 0;
	virtual void closeOrderedListLevel() = 0;
	virtual void closeUnorderedListLevel() = 0;
	virtual void openListElement(const RVNGPropertyList &propList) = 0;
	virtual void closeListElement() = 0;
	virtual void defineParagraphStyle(const RVNGPropertyList &propList) = 0;
	virtual void openParagraph(const RVNGPropertyList &propList) = 0;
	virtual void closeParagraph() = 0;
	virtual void defineCharacterStyle(const RVNGPropertyList &propList) = 0;
	virtual void openSpan(const RVNGPropertyList &propList) = 0;
	virtual void closeSpan() = 0;
	virtual void openLink(const RVNGPropertyList &propList) = 0;
	virtual void closeLink() = 0;
};
}
#endif
