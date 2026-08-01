#ifndef SPHBOSON_POTENTIAL_H
#define SPHBOSON_POTENTIAL_H

#include <stddef.h>

enum sphboson_potential_type
{
	POTENTIAL_FREE = 0,
	POTENTIAL_QUARTIC = 1,
	POTENTIAL_SEXTIC = 2,
	POTENTIAL_AXION = 3,
	POTENTIAL_SOLITONIC = 4,
	POTENTIAL_KKLS = 5
};

void compute_potential(double x, double m2, int type,
	double lambda_4, double lambda_6, double f_axion,
	double sigma_soliton, double kappa_kkls,
	double *V, double *Vx, double *Vxx);

const char *potential_name(int type);
const char *potential_coupling_name(int type);
double potential_coupling_value(int type, double lambda_4, double lambda_6,
	double f_axion, double sigma_soliton, double kappa_kkls);
int potential_type_from_name(const char *name);
void potential_output_tag(char *buffer, size_t size, int type,
	double lambda_4, double lambda_6, double f_axion,
	double sigma_soliton, double kappa_kkls);

#endif
