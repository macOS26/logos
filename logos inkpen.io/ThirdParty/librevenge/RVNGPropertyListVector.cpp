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
class RVNGPropertyListVectorImpl
{
public:
	RVNGPropertyListVectorImpl(const std::vector<RVNGPropertyList> &_vector) : m_vector(_vector) {}
	RVNGPropertyListVectorImpl() : m_vector() {}
	void append(const RVNGPropertyList &elem)
	{
		m_vector.push_back(elem);
	}
	unsigned long count() const
	{
		return m_vector.size();
	}
	bool empty() const
	{
		return m_vector.empty();
	}
	void clear()
	{
		m_vector.clear();
	}
	const RVNGPropertyList &operator[](unsigned long index) const
	{
		return m_vector[index];
	}
	std::vector<RVNGPropertyList> m_vector;
};
class RVNGPropertyListVectorIterImpl
{
public:
	RVNGPropertyListVectorIterImpl(std::vector<RVNGPropertyList> *vect) :
		m_vector(vect),
		m_iter(m_vector->begin()),
		m_imaginaryFirst(false) {}
	~RVNGPropertyListVectorIterImpl() {}
	void rewind()
	{
		m_iter = m_vector->begin();
		m_imaginaryFirst = true;
	}
	bool next()
	{
		if (!m_imaginaryFirst && m_iter != m_vector->end())
			++m_iter;
		m_imaginaryFirst = false;
		return (m_iter != m_vector->end());
	}
	bool last()
	{
		return (m_iter == m_vector->end());
	}
	const RVNGPropertyList &operator()() const
	{
		return (*m_iter);
	}
private:
	RVNGPropertyListVectorIterImpl(const RVNGPropertyListVectorIterImpl &);
	RVNGPropertyListVectorIterImpl &operator=(const RVNGPropertyListVectorIterImpl &);
	std::vector<RVNGPropertyList> *m_vector;
	std::vector<RVNGPropertyList>::iterator m_iter;
	bool m_imaginaryFirst;
};
RVNGPropertyListVector::RVNGPropertyListVector(const RVNGPropertyListVector &vect) :
	m_impl(new RVNGPropertyListVectorImpl(vect.m_impl->m_vector))
{
}
RVNGPropertyListVector::RVNGPropertyListVector() :
	m_impl(new RVNGPropertyListVectorImpl)
{
}
RVNGPropertyListVector::~RVNGPropertyListVector()
{
	delete m_impl;
}
int RVNGPropertyListVector::getInt() const
{
	return 0;
}
double RVNGPropertyListVector::getDouble() const
{
	return 0.0;
}
RVNGUnit RVNGPropertyListVector::getUnit() const
{
	return RVNG_UNIT_ERROR;
}
RVNGString RVNGPropertyListVector::getStr() const
{
	return RVNGString();
}
RVNGProperty *RVNGPropertyListVector::clone() const
{
	return new RVNGPropertyListVector(*this);
}
void RVNGPropertyListVector::append(const RVNGPropertyList &elem)
{
	m_impl->append(elem);
}
void RVNGPropertyListVector::append(const RVNGPropertyListVector &vec)
{
	std::vector<RVNGPropertyList> &other = vec.m_impl->m_vector;
	m_impl->m_vector.reserve(m_impl->m_vector.size() + other.size());
	m_impl->m_vector.insert(m_impl->m_vector.end(), other.begin(), other.end());
}
unsigned long RVNGPropertyListVector::count() const
{
	return m_impl->count();
}
bool RVNGPropertyListVector::empty() const
{
	return m_impl->empty();
}
void RVNGPropertyListVector::clear()
{
	m_impl->clear();
}
const RVNGPropertyList &RVNGPropertyListVector::operator[](unsigned long index) const
{
	return m_impl->operator[](index);
}
RVNGPropertyListVector &RVNGPropertyListVector::operator=(const RVNGPropertyListVector &vect)
{
	m_impl->m_vector = vect.m_impl->m_vector;
	return *this;
}
RVNGPropertyListVector::Iter::Iter(const RVNGPropertyListVector &vect) :
	m_iterImpl(new RVNGPropertyListVectorIterImpl(&(vect.m_impl->m_vector)))
{
}
RVNGString RVNGPropertyListVector::getPropString() const
{
	RVNGString propString;
	propString.append("(");
	RVNGPropertyListVector::Iter i(*this);
	if (!i.last())
	{
		propString.append("(");
		propString.append(i().getPropString());
		propString.append(")");
		for (; i.next();)
		{
			propString.append(", (");
			propString.append(i().getPropString());
			propString.append(")");
		}
	}
	propString.append(")");
	return propString;
}
RVNGPropertyListVector::Iter::~Iter()
{
	delete m_iterImpl;
}
void RVNGPropertyListVector::Iter::rewind()
{
	m_iterImpl->rewind();
}
bool RVNGPropertyListVector::Iter::next()
{
	return m_iterImpl->next();
}
bool RVNGPropertyListVector::Iter::last()
{
	return m_iterImpl->last();
}
const RVNGPropertyList &RVNGPropertyListVector::Iter::operator()() const
{
	return (*m_iterImpl)();
}
}
#pragma clang diagnostic pop
