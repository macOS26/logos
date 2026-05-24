#ifndef RVNGDIRECTORYSTREAM_H_INCLUDED
#define RVNGDIRECTORYSTREAM_H_INCLUDED
#include "librevenge-stream-api.h"
#include "RVNGStream.h"
namespace librevenge
{
struct RVNGDirectoryStreamImpl;
class REVENGE_STREAM_API RVNGDirectoryStream : public RVNGInputStream
{
	RVNGDirectoryStream(const RVNGDirectoryStream &);
	RVNGDirectoryStream &operator=(const RVNGDirectoryStream &);
public:
	explicit RVNGDirectoryStream(const char *path);
	virtual ~RVNGDirectoryStream();
	static RVNGDirectoryStream *createForParent(const char *path);
	static bool isDirectory(const char *path);
	virtual bool isStructured();
	virtual unsigned subStreamCount();
	virtual const char *subStreamName(unsigned id);
	virtual bool existsSubStream(const char *name);
	virtual RVNGInputStream *getSubStreamByName(const char *name);
	virtual RVNGInputStream *getSubStreamById(unsigned id);
	virtual const unsigned char *read(unsigned long numBytes, unsigned long &numBytesRead);
	virtual int seek(long offset, RVNG_SEEK_TYPE seekType);
	virtual long tell();
	virtual bool isEnd();
private:
	RVNGDirectoryStreamImpl *m_impl;
};
}
#endif
