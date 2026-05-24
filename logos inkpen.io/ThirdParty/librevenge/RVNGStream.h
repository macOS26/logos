#ifndef RVNGSTREAM_H
#define RVNGSTREAM_H
namespace librevenge
{
enum RVNG_SEEK_TYPE
{
	RVNG_SEEK_CUR,
	RVNG_SEEK_SET,
	RVNG_SEEK_END
};
class RVNGInputStream
{
public:
	RVNGInputStream() {}
	virtual ~RVNGInputStream() {}
	virtual bool isStructured() = 0;
	virtual unsigned subStreamCount() = 0;
	virtual const char *subStreamName(unsigned id) = 0;
	virtual bool existsSubStream(const char *name) = 0;
	virtual RVNGInputStream *getSubStreamByName(const char *name) = 0;
	virtual RVNGInputStream *getSubStreamById(unsigned id) = 0;
	virtual const unsigned char *read(unsigned long numBytes, unsigned long &numBytesRead) = 0;
	virtual int seek(long offset, RVNG_SEEK_TYPE seekType) = 0;
	virtual long tell() = 0;
	virtual bool isEnd() = 0;
};
}
#endif
