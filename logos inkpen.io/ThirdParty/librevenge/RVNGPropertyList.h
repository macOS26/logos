#ifndef RVNGPROPERTYLIST_H
#define RVNGPROPERTYLIST_H
#include "librevenge-api.h"
#include "RVNGProperty.h"
namespace librevenge
{
class RVNGPropertyListImpl;
class RVNGPropertyListIterImpl;
class RVNGPropertyListVector;
class REVENGE_API RVNGPropertyList
{
public:
	RVNGPropertyList();
	RVNGPropertyList(const RVNGPropertyList &);
	virtual ~RVNGPropertyList();
	void insert(const char *name, RVNGProperty *prop);
	void insert(const char *name, const char *val);
	void insert(const char *name, const int val);
	void insert(const char *name, const bool val);
	void insert(const char *name, const RVNGString &val);
	void insert(const char *name, const double val, const RVNGUnit units = RVNG_INCH);
	void insert(const char *name, const unsigned char *buffer, const unsigned long bufferSize);
	void insert(const char *name, const RVNGBinaryData &data);
	void insert(const char *name, const RVNGPropertyListVector &vec);
	void remove(const char *name);
	void clear();
	bool empty() const;
	const RVNGProperty *operator[](const char *name) const;
	const RVNGPropertyListVector *child(const char *name) const;
	const RVNGPropertyList &operator=(const RVNGPropertyList &propList);
	RVNGString getPropString() const;
	class REVENGE_API Iter
	{
	public:
		Iter(const RVNGPropertyList &propList);
		virtual ~Iter();
		void rewind();
		bool next();
		bool last();
		const RVNGProperty *operator()() const;
		const char *key() const;
		const RVNGPropertyListVector *child() const;
	private:
		RVNGPropertyListIterImpl *m_iterImpl;
		Iter(const Iter &);
		Iter &operator=(const Iter &);
	};
	friend class RVNGPropertyList::Iter;
private:
	mutable RVNGPropertyListImpl *m_impl;
};
}
#endif
