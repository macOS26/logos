#ifndef RVNGSTRING_H
#define RVNGSTRING_H
#include "librevenge-api.h"
namespace librevenge
{
class RVNGStringImpl;
class REVENGE_API RVNGString
{
public:
	RVNGString();
	RVNGString(const RVNGString &other);
	RVNGString(const char *str);
	~RVNGString();
	static RVNGString escapeXML(const RVNGString &s);
	static RVNGString escapeXML(const char *s);
	const char *cstr() const;
	int len() const;
	unsigned long size() const;
	bool empty() const;
	void sprintf(const char *format, ...) REVENGE_ATTRIBUTE_PRINTF(2, 3);
	void append(const RVNGString &s);
	void append(const char *s);
	void append(const char c);
	void appendEscapedXML(const RVNGString &s);
	void appendEscapedXML(const char *s);
	void clear();
	RVNGString &operator=(const RVNGString &str);
	RVNGString &operator=(const char *s);
	bool operator==(const char *s) const;
	bool operator==(const RVNGString &str) const;
	inline bool operator!=(const char *s) const
	{
		return !operator==(s);
	}
	inline bool operator!=(const RVNGString &str) const
	{
		return !operator==(str);
	}
	bool operator<(const char *s) const;
	bool operator<(const RVNGString &str) const;
	inline bool operator<=(const char *s) const
	{
		return operator==(s) || operator<(s);
	}
	inline bool operator<=(const RVNGString &str) const
	{
		return operator==(str) || operator<(str);
	}
	inline bool operator>=(const char *s) const
	{
		return !operator<(s);
	}
	inline bool operator>=(const RVNGString &str) const
	{
		return !operator<(str);
	}
	inline bool operator>(const char *s) const
	{
		return !operator<=(s);
	}
	inline bool operator>(const RVNGString &str) const
	{
		return !operator<=(str);
	}
	class REVENGE_API Iter
	{
	public:
		Iter(const RVNGString &str);
		virtual ~Iter();
		void rewind();
		bool next();
		bool last();
		const char *operator()() const;
	private:
		Iter(const Iter &);
		Iter &operator=(const Iter &);
		RVNGStringImpl *m_stringImpl;
		int m_pos;
		mutable char *m_curChar;
	};
private:
	RVNGStringImpl *m_stringImpl;
};
}
#endif
