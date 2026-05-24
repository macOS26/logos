#ifndef RVNGSTRINGVECTOR_H
#define RVNGSTRINGVECTOR_H
#include "librevenge-api.h"
#include "RVNGString.h"
namespace librevenge
{
class RVNGStringVectorImpl;
class REVENGE_API RVNGStringVector
{
public:
	RVNGStringVector();
	RVNGStringVector(const RVNGStringVector &vec);
	~RVNGStringVector();
	RVNGStringVector &operator=(const RVNGStringVector &vec);
	unsigned size() const;
	bool empty() const;
	const RVNGString &operator[](unsigned idx) const;
	void append(const RVNGString &str);
	void clear();
private:
	RVNGStringVectorImpl *m_pImpl;
};
}
#endif
