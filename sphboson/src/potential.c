#include <math.h>
#include <stdio.h>
#include <string.h>

#include "potential.h"

#ifndef M_PI
#define M_PI 3.14159265358979323846
#endif

static double sinc_series(double q)
{
	double q2 = q * q;
	return 1.0 - q2 / 6.0 + q2 * q2 / 120.0 - q2 * q2 * q2 / 5040.0;
}

void compute_potential(double x, double m2, int type,
	double lambda_4, double lambda_6, double f_axion,
	double sigma_soliton, double kappa_kkls,
	double *V, double *Vx, double *Vxx)
{
	if (x < 0.0)
		x = 0.0;

	switch (type)
	{
	case POTENTIAL_QUARTIC:
		*V = m2 * x + 0.5 * lambda_4 * x * x;
		*Vx = m2 + lambda_4 * x;
		*Vxx = lambda_4;
		break;
	case POTENTIAL_SEXTIC:
		*V = m2 * x + (lambda_6 / 3.0) * x * x * x;
		*Vx = m2 + lambda_6 * x * x;
		*Vxx = 2.0 * lambda_6 * x;
		break;
	case POTENTIAL_AXION:
	{
		double fa2 = f_axion * f_axion;
		double q = sqrt(2.0 * x) / f_axion;
		if (fabs(q) < 1.0E-3)
		{
			double x2 = x * x;
			*V = m2 * (x - x2 / (6.0 * fa2) + x2 * x / (90.0 * fa2 * fa2));
			*Vx = m2 * sinc_series(q);
			*Vxx = m2 * (-1.0 / (3.0 * fa2) + x / (15.0 * fa2 * fa2)
				- x2 / (210.0 * fa2 * fa2 * fa2));
		}
		else
		{
			double sinc = sin(q) / q;
			*V = 2.0 * m2 * fa2 * sin(0.5 * q) * sin(0.5 * q);
			*Vx = m2 * sinc;
			*Vxx = m2 * (cos(q) - sinc) / (2.0 * x);
		}
		break;
	}
	case POTENTIAL_SOLITONIC:
	{
		double sigma2 = sigma_soliton * sigma_soliton;
		double y = x / sigma2;
		*V = m2 * x * (1.0 - 2.0 * y) * (1.0 - 2.0 * y);
		*Vx = m2 * (1.0 - 8.0 * y + 12.0 * y * y);
		*Vxx = m2 * (-8.0 + 24.0 * y) / sigma2;
		break;
	}
	case POTENTIAL_KKLS:
	{
		double a = 16.0 * M_PI / (1.1 * kappa_kkls);
		double b = 64.0 * M_PI * M_PI / (1.1 * kappa_kkls * kappa_kkls);
		*V = m2 * x * (1.0 - a * x + b * x * x);
		*Vx = m2 * (1.0 - 2.0 * a * x + 3.0 * b * x * x);
		*Vxx = m2 * (-2.0 * a + 6.0 * b * x);
		break;
	}
	case POTENTIAL_FREE:
	default:
		*V = m2 * x;
		*Vx = m2;
		*Vxx = 0.0;
		break;
	}
}

const char *potential_name(int type)
{
	static const char *names[] = {"free", "quartic", "sextic", "axion", "solitonic", "kkls"};
	return (type >= POTENTIAL_FREE && type <= POTENTIAL_KKLS) ? names[type] : "invalid";
}

const char *potential_coupling_name(int type)
{
	static const char *names[] = {"none", "lambda_4", "lambda_6", "f_axion", "sigma_soliton", "kappa_kkls"};
	return (type >= POTENTIAL_FREE && type <= POTENTIAL_KKLS) ? names[type] : "invalid";
}

double potential_coupling_value(int type, double lambda_4, double lambda_6,
	double f_axion, double sigma_soliton, double kappa_kkls)
{
	switch (type)
	{
	case POTENTIAL_QUARTIC: return lambda_4;
	case POTENTIAL_SEXTIC: return lambda_6;
	case POTENTIAL_AXION: return f_axion;
	case POTENTIAL_SOLITONIC: return sigma_soliton;
	case POTENTIAL_KKLS: return kappa_kkls;
	default: return 0.0;
	}
}

int potential_type_from_name(const char *name)
{
	int type;
	for (type = POTENTIAL_FREE; type <= POTENTIAL_KKLS; ++type)
		if (strcmp(name, potential_name(type)) == 0)
			return type;
	return -1;
}

void potential_output_tag(char *buffer, size_t size, int type,
	double lambda_4, double lambda_6, double f_axion,
	double sigma_soliton, double kappa_kkls)
{
	if (type == POTENTIAL_FREE)
		snprintf(buffer, size, "pot=free");
	else
		snprintf(buffer, size, "pot=%s,%s=%.5E", potential_name(type),
			potential_coupling_name(type), potential_coupling_value(type,
			lambda_4, lambda_6, f_axion, sigma_soliton, kappa_kkls));
}
