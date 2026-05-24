#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wshorten-64-to-32"
#pragma clang diagnostic ignored "-Wloop-analysis"
#pragma clang diagnostic ignored "-Wsign-conversion"
#pragma clang diagnostic ignored "-Wimplicit-int-conversion"
#pragma clang diagnostic ignored "-Wconversion"
#pragma clang diagnostic ignored "-Wdeprecated-declarations"
#include "librevenge.h"
#include <vector>
namespace librevenge
{
class RVNGStringVectorImpl
{
public:
	RVNGStringVectorImpl() : m_strings() {}
	~RVNGStringVectorImpl() {}
	std::vector<RVNGString> m_strings;
};
RVNGStringVector::RVNGStringVector()
	: m_pImpl(new RVNGStringVectorImpl())
{
}
RVNGStringVector::RVNGStringVector(const RVNGStringVector &vec)
	: m_pImpl(new RVNGStringVectorImpl(*(vec.m_pImpl)))
{
}
RVNGStringVector::~RVNGStringVector()
{
	delete m_pImpl;
}
RVNGStringVector &RVNGStringVector::operator=(const RVNGStringVector &vec)
{
	if (this == &vec)
		return *this;
	if (m_pImpl)
		delete m_pImpl;
	m_pImpl = new RVNGStringVectorImpl(*(vec.m_pImpl));
	return *this;
}
unsigned RVNGStringVector::size() const
{
	return (unsigned)(m_pImpl->m_strings.size());
}
bool RVNGStringVector::empty() const
{
	return m_pImpl->m_strings.empty();
}
const RVNGString &RVNGStringVector::operator[](unsigned idx) const
{
	return m_pImpl->m_strings[idx];
}
void RVNGStringVector::append(const RVNGString &str)
{
	m_pImpl->m_strings.push_back(str);
}
void RVNGStringVector::clear()
{
	m_pImpl->m_strings.clear();
}
}
#pragma clang diagnostic pop
