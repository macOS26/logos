#ifndef RVNGSTREAMIMPLEMENTATION_H
#define RVNGSTREAMIMPLEMENTATION_H
#include "librevenge-stream-api.h"
#include "RVNGStream.h"
namespace librevenge
{
class RVNGFileStreamPrivate;
class REVENGE_STREAM_API RVNGFileStream: public RVNGInputStream
{
public:
	explicit RVNGFileStream(const char *filename);
	~RVNGFileStream();
	const unsigned char *read(unsigned long numBytes, unsigned long &numBytesRead);
	long tell();
	int seek(long offset, RVNG_SEEK_TYPE seekType);
	bool isEnd();
	bool isStructured();
	unsigned subStreamCount();
	const char *subStreamName(unsigned id);
	bool existsSubStream(const char *name);
	RVNGInputStream *getSubStreamById(unsigned id);
	RVNGInputStream *getSubStreamByName(const char *name);
private:
	RVNGFileStreamPrivate *d;
	RVNGFileStream(const RVNGFileStream &);
	RVNGFileStream &operator=(const RVNGFileStream &);
};
class RVNGStringStreamPrivate;
class REVENGE_STREAM_API RVNGStringStream: public RVNGInputStream
{
public:
	RVNGStringStream(const unsigned char *data, const unsigned int dataSize);
	~RVNGStringStream();
	const unsigned char *read(unsigned long numBytes, unsigned long &numBytesRead);
	long tell();
	int seek(long offset, RVNG_SEEK_TYPE seekType);
	bool isEnd();
	bool isStructured();
	unsigned subStreamCount();
	const char *subStreamName(unsigned);
	bool existsSubStream(const char *name);
	RVNGInputStream *getSubStreamByName(const char *name);
	RVNGInputStream *getSubStreamById(unsigned);
private:
	RVNGStringStreamPrivate *d;
	RVNGStringStream(const RVNGStringStream &);
	RVNGStringStream &operator=(const RVNGStringStream &);
};
}
#endif
