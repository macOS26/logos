#ifndef RVNGPROPERTYLISTVECTOR_H
#define RVNGPROPERTYLISTVECTOR_H
#include "librevenge-api.h"
#include "RVNGPropertyList.h"
namespace librevenge
{
class RVNGPropertyListVectorImpl;
class RVNGPropertyListVectorIterImpl;
class REVENGE_API RVNGPropertyListVector : public RVNGProperty
{
public:
	RVNGPropertyListVector(const RVNGPropertyListVector &);
	RVNGPropertyListVector();
	virtual ~RVNGPropertyListVector();
	int getInt() const;
	double getDouble() const;
	RVNGUnit getUnit() const;
	RVNGString getStr() const;
	RVNGProperty *clone() const;
	void append(const RVNGPropertyList &elem);
	void append(const RVNGPropertyListVector &vec);
	unsigned long count() const;
	bool empty() const;
	void clear();
	const RVNGPropertyList &operator[](unsigned long index) const;
	RVNGPropertyListVector &operator=(const RVNGPropertyListVector &vect);
	RVNGString getPropString() const;
	class REVENGE_API Iter
	{
	public:
		Iter(const RVNGPropertyListVector &vect);
		virtual ~Iter();
		void rewind();
		bool next();
		bool last();
		const RVNGPropertyList &operator()() const;
	private:
		RVNGPropertyListVectorIterImpl *m_iterImpl;
		Iter(const Iter &);
		Iter &operator=(const Iter &);
	};
	friend class RVNGPropertyListVector::Iter;
private:
	RVNGPropertyListVectorImpl *m_impl;
};
}
#endif
