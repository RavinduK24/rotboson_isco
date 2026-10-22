#ifndef ROTBOSON_SCALAR_TAIL_H
#define ROTBOSON_SCALAR_TAIL_H
#include <math.h>

/* Leading bound-state tail for psi = phi / rho^ell. Initial guess only;
 * Newton re-solves the enlarged domain, including its boundary equations. */
static inline double scalar_tail(double value, double radius0, double radius,
                                 double mass, double omega, int ell)
{
    if (!(radius0 > 0.0) || radius < radius0 || !(mass > fabs(omega)))
        return NAN;
    return value * pow(radius0 / radius, ell + 1)
        * exp(-sqrt(mass * mass - omega * omega) * (radius - radius0));
}
#endif
