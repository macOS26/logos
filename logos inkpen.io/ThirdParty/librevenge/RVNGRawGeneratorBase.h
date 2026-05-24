#ifndef RVNGRAWGENERATORBASE_H
#define RVNGRAWGENERATORBASE_H
#include <stack>
#include "librevenge.h"
#ifdef RVNG_CALLGRAPH_ENTER
#warning who defined RVNG_CALLGRAPH_ENTER?
#undef RVNG_CALLGRAPH_ENTER
#endif
#define RVNG_CALLGRAPH_ENTER(M, L) \
	m_impl->m_atLeastOneCallback = true; \
	if (!m_impl->m_printCallgraphScore) \
			m_impl->iuprintf M; \
	else \
		m_impl->m_callStack.push(L);
#ifdef RVNG_CALLGRAPH_LEAVE
#warning who defined RVNG_CALLGRAPH_LEAVE?
#undef RVNG_CALLGRAPH_LEAVE
#endif
#define RVNG_CALLGRAPH_LEAVE(M, L) \
	m_impl->m_atLeastOneCallback = true; \
	if (!m_impl->m_printCallgraphScore) \
			m_impl->idprintf M; \
	else \
	{ \
		if (m_impl->m_callStack.empty()) \
		{ \
			m_impl->m_callbackMisses++; \
		} \
		else \
		{ \
			const int lc = m_impl->m_callStack.top(); \
			if (lc != L) \
				m_impl->m_callbackMisses++; \
			m_impl->m_callStack.pop(); \
		} \
	}
namespace librevenge
{
namespace
{
enum RVNGCallback
{
	CALLBACK_OPEN_ANIMATION_GROUP,
	CALLBACK_OPEN_ANIMATION_ITERATION,
	CALLBACK_OPEN_ANIMATION_SEQUENCE,
	CALLBACK_OPEN_CHART,
	CALLBACK_OPEN_CHART_TEXTOBJECT,
	CALLBACK_OPEN_CHART_PLOTAREA,
	CALLBACK_OPEN_CHART_SERIE,
	CALLBACK_OPEN_COMMENT,
	CALLBACK_OPEN_ENDNOTE,
	CALLBACK_OPEN_FOOTNOTE,
	CALLBACK_OPEN_FRAME,
	CALLBACK_OPEN_GRAPHIC,
	CALLBACK_OPEN_GRAPHIC_LAYER,
	CALLBACK_OPEN_GRAPHIC_PAGE,
	CALLBACK_OPEN_GROUP,
	CALLBACK_OPEN_HEADER_FOOTER,
	CALLBACK_OPEN_LINK,
	CALLBACK_OPEN_LIST_ELEMENT,
	CALLBACK_OPEN_ORDERED_LIST_LEVEL,
	CALLBACK_OPEN_PAGE_SPAN,
	CALLBACK_OPEN_PARAGRAPH,
	CALLBACK_OPEN_SECTION,
	CALLBACK_OPEN_SHEET,
	CALLBACK_OPEN_SHEET_CELL,
	CALLBACK_OPEN_SHEET_ROW,
	CALLBACK_OPEN_SPAN,
	CALLBACK_OPEN_TABLE,
	CALLBACK_OPEN_TABLE_CELL,
	CALLBACK_OPEN_TABLE_ROW,
	CALLBACK_OPEN_TEXT_BOX,
	CALLBACK_OPEN_UNORDERED_LIST_LEVEL,
	CALLBACK_START_COMMENT,
	CALLBACK_START_DOCUMENT,
	CALLBACK_START_EMBEDDED_GRAPHICS,
	CALLBACK_START_LAYER,
	CALLBACK_START_NOTES,
	CALLBACK_START_PAGE,
	CALLBACK_START_MASTER_PAGE,
	CALLBACK_START_SLIDE,
	CALLBACK_START_MASTER_SLIDE,
	CALLBACK_START_TEXT_OBJECT
};
}
struct RVNGRawGeneratorBase
{
	explicit RVNGRawGeneratorBase(bool printCallgraphScore);
	virtual ~RVNGRawGeneratorBase();
	int m_indent;
	int m_callbackMisses;
	bool m_atLeastOneCallback;
	bool m_printCallgraphScore;
	std::stack<int> m_callStack;
	void indentUp()
	{
		m_indent++;
	}
	void indentDown()
	{
		if (m_indent > 0) m_indent--;
	}
	void iprintf(const char *format, ...) REVENGE_ATTRIBUTE_PRINTF(2, 3);
	void iuprintf(const char *format, ...) REVENGE_ATTRIBUTE_PRINTF(2, 3);
	void idprintf(const char *format, ...) REVENGE_ATTRIBUTE_PRINTF(2, 3);
};
}
#endif
