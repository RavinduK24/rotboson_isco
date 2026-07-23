#include <assert.h>
#include <math.h>
#include <stdio.h>

#include "../src/potential.h"

static void check_type(int type, double lambda4, double lambda6, double fa, double sigma, double kappa)
{
	const double m2 = 1.7;
	const double samples[] = {0.0, 1.0E-10, 1.0E-6, 0.01, 0.1};
	int i;
	for (i = 0; i < 5; ++i)
	{
		double x = samples[i], V, Vx, Vxx;
		compute_potential(x, m2, type, lambda4, lambda6, fa, sigma, kappa, &V, &Vx, &Vxx);
		assert(isfinite(V) && isfinite(Vx) && isfinite(Vxx));
		assert(x != 0.0 || fabs(V) < 1.0E-14);
		if (x > 1.0E-7)
		{
			double h = 1.0E-5 * x;
			double Vm, Vxm, Vxxm, Vp, Vxp, Vxxp;
			compute_potential(x - h, m2, type, lambda4, lambda6, fa, sigma, kappa, &Vm, &Vxm, &Vxxm);
			compute_potential(x + h, m2, type, lambda4, lambda6, fa, sigma, kappa, &Vp, &Vxp, &Vxxp);
			assert(fabs((Vp - Vm) / (2.0 * h) - Vx) < 2.0E-6 * (1.0 + fabs(Vx)));
			assert(fabs((Vxp - Vxm) / (2.0 * h) - Vxx) < 2.0E-5 * (1.0 + fabs(Vxx)));
		}
	}
}

int main(void)
{
	double V, Vx, Vxx;
	int type;
	for (type = POTENTIAL_FREE; type <= POTENTIAL_KKLS; ++type)
		check_type(type, 0.4, 0.2, 0.7, 1.1, 8.0);
	compute_potential(0.0, 2.3, POTENTIAL_AXION, 0.0, 0.0, 0.7, 1.0, 1.0, &V, &Vx, &Vxx);
	assert(fabs(Vx - 2.3) < 1.0E-14);
	for (type = POTENTIAL_FREE; type <= POTENTIAL_KKLS; ++type)
	{
		compute_potential(1.0E-12, 2.3, type, 0.0, 0.0, 1.0E6, 1.0E6, 1.0E12, &V, &Vx, &Vxx);
		assert(fabs(V / 1.0E-12 - 2.3) < 1.0E-6);
	}
	puts("potential tests passed");
	return 0;
}
