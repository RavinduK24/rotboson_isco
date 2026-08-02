#include <stdlib.h>

#include "isco_export.h"
#include "potential.h"

int main(void)
{
	double r[] = {-0.15, -0.05, 0.05, 0.15, 0.25, 0.35, 0.45};
	double log_alpha[] = {0.0, 0.0, -0.10, -0.08, -0.05, -0.02, -0.01};
	double log_psi[] = {0.0, 0.0, 0.12, 0.10, 0.07, 0.04, 0.02};
	return write_isco_export(r, log_alpha, log_psi, 7, 2,
		1.0, 0.9, POTENTIAL_QUARTIC, 10.0, 0.0, 1.0, 1.0, 1.0,
		0.61, 0.60, 0.25, 0, 0.1, 4, 4) == 0 ? EXIT_SUCCESS : EXIT_FAILURE;
}
