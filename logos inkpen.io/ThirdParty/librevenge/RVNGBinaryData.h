#ifndef RVNGBINARYDATA_H
#define RVNGBINARYDATA_H
#include "librevenge-api.h"
#include "librevenge-stream.h"
#include "RVNGString.h"
namespace librevenge
{
struct RVNGBinaryDataImpl;
class REVENGE_API RVNGBinaryData
{
public:
	RVNGBinaryData();
	RVNGBinaryData(const RVNGBinaryData &);
	RVNGBinaryData(const unsigned char *buffer, const unsigned long bufferSize);
	explicit RVNGBinaryData(const RVNGString &base64);
	explicit RVNGBinaryData(const char *base64);
	~RVNGBinaryData();
	void append(const RVNGBinaryData &data);
	void append(const unsigned char *buffer, const unsigned long bufferSize);
	void append(const unsigned char c);
	void appendBase64Data(const RVNGString &base64);
	void appendBase64Data(const char *base64);
	void clear();
	unsigned long size() const;
	bool empty() const;
	const unsigned char *getDataBuffer() const;
	const RVNGString getBase64Data() const;
	RVNGInputStream *getDataStream() const;
	RVNGBinaryData &operator=(const RVNGBinaryData &);
private:
	RVNGBinaryDataImpl *m_binaryDataImpl;
};
}
#endif
