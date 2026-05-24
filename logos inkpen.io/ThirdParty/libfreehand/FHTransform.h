#ifndef __FHTRANSFORM_H__
#define __FHTRANSFORM_H__
namespace libfreehand
{
struct FHTransform
{
  FHTransform();
  FHTransform(double m11, double m21, double m12, double m22, double m13, double m23);
  FHTransform(const FHTransform &trafo);
  FHTransform &operator=(const FHTransform &trafo);
  void applyToPoint(double &x, double &y) const;
  void applyToArc(double &rx, double &ry, double &rotation, bool &sweep, double &endx, double &endy) const;
  double m_m11;
  double m_m21;
  double m_m12;
  double m_m22;
  double m_m13;
  double m_m23;
};
}
#endif
