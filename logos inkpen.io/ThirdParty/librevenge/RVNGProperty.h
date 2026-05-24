#ifndef RVNGPROPERTY_H
#define RVNGPROPERTY_H
#include "librevenge-api.h"
#include "RVNGString.h"
namespace librevenge
{
enum RVNGUnit { RVNG_INCH, RVNG_PERCENT, RVNG_POINT, RVNG_TWIP, RVNG_GENERIC, RVNG_UNIT_ERROR };
class REVENGE_API RVNGProperty
{
public:
	virtual ~RVNGProperty();
	virtual int getInt() const = 0;
	virtual double getDouble() const = 0;
	virtual RVNGUnit getUnit() const = 0;
	virtual RVNGString getStr() const = 0;
	virtual RVNGProperty *clone() const = 0;
};
class REVENGE_API RVNGPropertyFactory
{
public:
	static RVNGProperty *newStringProp(const RVNGString &str);
	static RVNGProperty *newStringProp(const char *str);
	static RVNGProperty *newBinaryDataProp(const RVNGBinaryData &data);
	static RVNGProperty *newBinaryDataProp(const unsigned char *buffer,
	                                       const unsigned long bufferSize);
	static RVNGProperty *newIntProp(const int val);
	static RVNGProperty *newBoolProp(const bool val);
	static RVNGProperty *newDoubleProp(const double val);
	static RVNGProperty *newInchProp(const double val);
	static RVNGProperty *newPercentProp(const double val);
	static RVNGProperty *newPointProp(const double val);
	static RVNGProperty *newTwipProp(const double val);
};
}
#endif
