#include <assert.h>
#include <math.h>
#include <stdio.h>
#include <mkl.h>
#include "simpson.h"
#include "scalar_tail.h"

int main(void)
{
    double values[32];
    /* Both Simpson branches must integrate cubics exactly, including the
       short prefixes used to build cumulative mass profiles. */
    for (int n = 3; n <= 32; ++n) {
        for (int power = 0; power <= 3; ++power) {
            double h = 1.0 / (n - 1);
            for (int i = 0; i < n; ++i) values[i] = pow(i * h, power);
            assert(fabs(simps(values, h, n) - 1.0 / (power + 1)) < 1e-12);
        }
    }
    for (int ell = 0; ell <= 3; ++ell) {
        double at_boundary = scalar_tail(0.01, 16, 16, 1, 0.95, ell);
        double outside = scalar_tail(0.01, 16, 32, 1, 0.95, ell);
        assert(fabs(at_boundary - 0.01) < 1e-15);
        assert(outside > 0 && outside < 0.01);
        /* Physical phi also decays along each ray. */
        assert(pow(32, ell) * outside < pow(16, ell) * 0.01);
        double staged = scalar_tail(outside, 32, 64, 1, 0.95, ell);
        assert(fabs(staged - scalar_tail(0.01, 16, 64, 1, 0.95, ell)) < 1e-15);
    }
    assert(isnan(scalar_tail(0.01, 16, 32, 1, 1.1, 1)));
    puts("Numerical quadrature and scalar-tail tests passed.");
    return 0;
}
