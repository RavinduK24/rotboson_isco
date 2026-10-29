#include <stdio.h>
#include <omp.h>
#include <mkl.h>

#undef PARALLEL

double simps(double *y, const double dx, const MKL_INT dim)
{
	// Step size over 3.0
	double dx_o_3 = dx / 3.0;
	// Result initializes to zero.
	double i = 0.0;
	// Loop counter.
	MKL_INT k = 0;
	// Number of intervals.
	MKL_INT n = dim - 1;

	// Short prefixes occur in cumulative integrals; handle them explicitly.
	if (dim < 2)
	{
		printf("CRITICAL WARNING ON SIMPSON INTEGRATION!\n");
		printf("Need at least dim = 2 but dim = %lld.\n", (long long)dim);
		return 0.0;
	}
	if (dim == 2)
		return 0.5 * dx * (y[0] + y[1]);
	if (dim == 4)
		return 0.375 * dx * (y[0] + 3.0 * (y[1] + y[2]) + y[3]);

	// Classical rule uses an even ammount of intervals.
	if (n % 2 == 0)
	{
		// Main loop.
#ifdef PARALLEL
		#pragma omp parallel for schedule(dynamic, 1) private(k, dx_o_3) reduction(+:i)
#endif
		for (k = 1; k < n / 2; ++k)
			i += dx_o_3 * 2.0 * (2.0 * y[2 * k - 1] + y[2 * k]);

		// Add values at beginning.
		i += dx_o_3 * y[0];
		// Add last two values.
		i += dx_o_3 * (4.0 * y[dim - 2] + y[dim - 1]);
	}
	// Otherwise apply Simpson's 3/8 rule on last four points (last three intervals).
	else
	{
		// Recursion on Simpson with proper even number of intervals.
		i = simps(y, dx, dim - 3);
		// Add 3/8 rule on last four points.
		i += 0.375 * dx * (y[dim - 4] + 3.0 * (y[dim - 3] + y[dim - 2]) + y[dim - 1]);
	}

	return i;
}
