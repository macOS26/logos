#ifndef RVNGTEXTINTERFACE_H
#define RVNGTEXTINTERFACE_H
#include "RVNGPropertyList.h"
#include "RVNGPropertyListVector.h"
namespace librevenge
{
class RVNGInputStream;
class RVNGTextInterface
{
public:
	virtual ~RVNGTextInterface() {}
	virtual void setDocumentMetaData(const RVNGPropertyList &propList) = 0;
	virtual void startDocument(const RVNGPropertyList &propList) = 0;
	virtual void endDocument() = 0;
	virtual void definePageStyle(const RVNGPropertyList &propList) = 0;
	virtual void defineEmbeddedFont(const RVNGPropertyList &propList) = 0;
	virtual void openPageSpan(const RVNGPropertyList &propList) = 0;
	virtual void closePageSpan() = 0;
	virtual void openHeader(const RVNGPropertyList &propList) = 0;
	virtual void closeHeader() = 0;
	virtual void openFooter(const RVNGPropertyList &propList) = 0;
	virtual void closeFooter() = 0;
	virtual void defineParagraphStyle(const RVNGPropertyList &propList) = 0;
	virtual void openParagraph(const RVNGPropertyList &propList) = 0;
	virtual void closeParagraph() = 0;
	virtual void defineCharacterStyle(const RVNGPropertyList &propList) = 0;
	virtual void openSpan(const RVNGPropertyList &propList) = 0;
	virtual void closeSpan() = 0;
	virtual void openLink(const RVNGPropertyList &propList) = 0;
	virtual void closeLink() = 0;
	virtual void defineSectionStyle(const RVNGPropertyList &propList) = 0;
	virtual void openSection(const RVNGPropertyList &propList) = 0;
	virtual void closeSection() = 0;
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
	virtual void openFootnote(const RVNGPropertyList &propList) = 0;
	virtual void closeFootnote() = 0;
	virtual void openEndnote(const RVNGPropertyList &propList) = 0;
	virtual void closeEndnote() = 0;
	virtual void openComment(const RVNGPropertyList &propList) = 0;
	virtual void closeComment() = 0;
	virtual void openTextBox(const RVNGPropertyList &propList) = 0;
	virtual void closeTextBox() = 0;
	virtual void openTable(const RVNGPropertyList &propList) = 0;
	virtual void openTableRow(const RVNGPropertyList &propList) = 0;
	virtual void closeTableRow() = 0;
	virtual void openTableCell(const RVNGPropertyList &propList) = 0;
	virtual void closeTableCell() = 0;
	virtual void insertCoveredTableCell(const RVNGPropertyList &propList) = 0;
	virtual void closeTable() = 0;
	virtual void openFrame(const RVNGPropertyList &propList) = 0;
	virtual void closeFrame() = 0;
	virtual void insertBinaryObject(const RVNGPropertyList &propList) = 0;
	virtual void insertEquation(const RVNGPropertyList &propList) = 0;
	virtual void openGroup(const librevenge::RVNGPropertyList &propList) = 0;
	virtual void closeGroup() = 0;
	virtual void defineGraphicStyle(const librevenge::RVNGPropertyList &propList) = 0;
	virtual void drawRectangle(const RVNGPropertyList &propList) = 0;
	virtual void drawEllipse(const RVNGPropertyList &propList) = 0;
	virtual void drawPolygon(const RVNGPropertyList &propList) = 0;
	virtual void drawPolyline(const RVNGPropertyList &propList) = 0;
	virtual void drawPath(const RVNGPropertyList &propList) = 0;
	virtual void drawConnector(const RVNGPropertyList &propList) = 0;
};
}
#endif
