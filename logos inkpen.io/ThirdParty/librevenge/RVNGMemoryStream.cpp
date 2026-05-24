#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wshorten-64-to-32"
#pragma clang diagnostic ignored "-Wloop-analysis"
#pragma clang diagnostic ignored "-Wsign-conversion"
#pragma clang diagnostic ignored "-Wimplicit-int-conversion"
#pragma clang diagnostic ignored "-Wconversion"
#pragma clang diagnostic ignored "-Wdeprecated-declarations"
#include "RVNGMemoryStream.h"
namespace librevenge
{
RVNGMemoryInputStream::RVNGMemoryInputStream(unsigned char *data, unsigned long size) :
	RVNGInputStream(),
	m_offset(0),
	m_size(size),
	m_data(data)
{
}
RVNGMemoryInputStream::~RVNGMemoryInputStream()
{
}
const unsigned char *RVNGMemoryInputStream::read(unsigned long numBytes, unsigned long &numBytesRead)
{
	numBytesRead = 0;
	if (numBytes == 0)
		return nullptr;
	long numBytesToRead;
	if (m_offset+long(numBytes) < long(m_size))
		numBytesToRead = long(numBytes);
	else
		numBytesToRead = long(m_size) - long(m_offset);
	numBytesRead = (unsigned long) numBytesToRead;
	if (numBytesToRead == 0)
		return nullptr;
	long oldOffset = m_offset;
	m_offset += numBytesToRead;
	return &m_data[oldOffset];
}
int RVNGMemoryInputStream::seek(long offset, RVNG_SEEK_TYPE seekType)
{
	if (seekType == RVNG_SEEK_CUR)
		m_offset += offset;
	else if (seekType == RVNG_SEEK_SET)
		m_offset = offset;
	else if (seekType == RVNG_SEEK_END)
		m_offset = (long)m_size+offset;
	if (m_offset < 0)
	{
		m_offset = 0;
		return -1;
	}
	if ((long)m_offset > (long)m_size)
	{
		m_offset = (long) m_size;
		return -1;
	}
	return 0;
}
long RVNGMemoryInputStream::tell()
{
	return m_offset;
}
bool RVNGMemoryInputStream::isEnd()
{
	if ((long)m_offset == (long)m_size)
		return true;
	return false;
}
}
#pragma clang diagnostic pop
