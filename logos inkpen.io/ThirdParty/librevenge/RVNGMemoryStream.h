#ifndef RVNGMEMORYSTREAM_H
#define RVNGMEMORYSTREAM_H
#include "librevenge-stream.h"
namespace librevenge
{
class RVNGMemoryInputStream : public RVNGInputStream
{
public:
	RVNGMemoryInputStream(unsigned char *data, unsigned long size);
	~RVNGMemoryInputStream();
	bool isStructured()
	{
		return false;
	}
	unsigned subStreamCount()
	{
		return 0;
	}
	const char *subStreamName(unsigned)
	{
		return nullptr;
	}
	bool existsSubStream(const char *)
	{
		return false;
	}
	RVNGInputStream *getSubStreamByName(const char *)
	{
		return nullptr;
	}
	RVNGInputStream *getSubStreamById(unsigned)
	{
		return nullptr;
	}
	const unsigned char *read(unsigned long numBytes, unsigned long &numBytesRead);
	int seek(long offset, RVNG_SEEK_TYPE seekType);
	long tell();
	bool isEnd();
	unsigned long getSize() const
	{
		return m_size;
	}
private:
	long m_offset;
	unsigned long m_size;
	unsigned char *m_data;
	RVNGMemoryInputStream(const RVNGMemoryInputStream &);
	RVNGMemoryInputStream &operator=(const RVNGMemoryInputStream &);
};
}
#endif
