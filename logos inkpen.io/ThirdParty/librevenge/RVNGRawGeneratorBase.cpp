#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wshorten-64-to-32"
#pragma clang diagnostic ignored "-Wloop-analysis"
#pragma clang diagnostic ignored "-Wsign-conversion"
#pragma clang diagnostic ignored "-Wimplicit-int-conversion"
#pragma clang diagnostic ignored "-Wconversion"
#pragma clang diagnostic ignored "-Wdeprecated-declarations"
#include "RVNGRawGeneratorBase.h"
#include <stdarg.h>
#include <stdio.h>
#include <map>
#include <string>
namespace librevenge
{
RVNGRawGeneratorBase::RVNGRawGeneratorBase(bool printCallgraphScore)
	: m_indent(0)
	, m_callbackMisses(0)
	, m_atLeastOneCallback(false)
	, m_printCallgraphScore(printCallgraphScore)
	, m_callStack()
{
}
RVNGRawGeneratorBase::~RVNGRawGeneratorBase()
{
}
void RVNGRawGeneratorBase::iprintf(const char *format, ...)
{
	m_atLeastOneCallback = true;
	if (m_printCallgraphScore) return;
	va_list args;
	va_start(args, format);
	for (int i=0; i<m_indent; i++)
		printf("  ");
	vprintf(format, args);
	va_end(args);
}
void RVNGRawGeneratorBase::iuprintf(const char *format, ...)
{
	m_atLeastOneCallback = true;
	va_list args;
	va_start(args, format);
	for (int i=0; i<m_indent; i++)
		printf("  ");
	vprintf(format, args);
	indentUp();
	va_end(args);
}
void RVNGRawGeneratorBase::idprintf(const char *format, ...)
{
	m_atLeastOneCallback = true;
	va_list args;
	va_start(args, format);
	indentDown();
	for (int i=0; i<m_indent; i++)
		printf("  ");
	vprintf(format, args);
	va_end(args);
}
}
#pragma clang diagnostic pop
