#include <math.h>
#include <stdio.h>
#include <stdlib.h>

#include "potential.h"

static void require_close(const char *label, double actual, double expected, double tolerance)
{
	double scale = fmax(1.0, fmax(fabs(actual), fabs(expected)));
	if (fabs(actual - expected) > tolerance * scale)
	{
		fprintf(stderr, "%s: actual=%.17E expected=%.17E\n", label, actual, expected);
		exit(EXIT_FAILURE);
	}
}

static void check_type(int type, double lambda4, double lambda6,
	double fa, double sigma, double kappa)
{
	const double m2 = 1.7;
	const double points[] = {0.0, 1.0E-10, 1.0E-6, 1.0E-2, 0.1};
	size_t i;
	for (i = 0; i < sizeof(points) / sizeof(points[0]); ++i)
	{
		double x = points[i];
		double h = 1.0E-5 * x;
		double V, Vx, Vxx, Vm, Vxm, Vxxm, Vp, Vxp, Vxxp;
		compute_potential(x, m2, type, lambda4, lambda6, fa, sigma, kappa, &V, &Vx, &Vxx);
		if (!isfinite(V) || !isfinite(Vx) || !isfinite(Vxx))
			exit(EXIT_FAILURE);
		if (x <= 1.0E-7)
			continue;
		compute_potential(x - h, m2, type, lambda4, lambda6, fa, sigma, kappa, &Vm, &Vxm, &Vxxm);
		compute_potential(x + h, m2, type, lambda4, lambda6, fa, sigma, kappa, &Vp, &Vxp, &Vxxp);
		require_close("dV/dx", (Vp - Vm) / (2.0 * h), Vx, 2.0E-6);
		require_close("d2V/dx2", (Vxp - Vxm) / (2.0 * h), Vxx, 2.0E-5);
	}
}

int main(void)
{
	double V, Vx, Vxx;
	int type;
	compute_potential(0.4, 2.3, POTENTIAL_FREE, 0.0, 0.0, 1.0, 1.0, 1.0, &V, &Vx, &Vxx);
	require_close("free V", V, 0.92, 1.0E-14);
	require_close("free Vx", Vx, 2.3, 1.0E-14);
	require_close("free Vxx", Vxx, 0.0, 1.0E-14);

	for (type = POTENTIAL_FREE; type <= POTENTIAL_KKLS; ++type)
		check_type(type, 3.0, 2.0, 0.7, 0.8, 5.0);

	puts("potential tests passed");
	return EXIT_SUCCESS;
}
