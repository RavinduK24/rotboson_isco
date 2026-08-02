#include <math.h>
#include <stdio.h>

#include "isco_export.h"
#include "potential.h"

#ifndef M_PI
#define M_PI 3.14159265358979323846
#endif

#define ISCO_THETA_POINTS 9

enum grid_kind
{
	GRID_RADIUS,
	GRID_THETA,
	GRID_LOG_ALPHA,
	GRID_BETA,
	GRID_LOG_SPATIAL
};

static int write_grid(const char *filename, enum grid_kind kind,
	const double *r, const double *log_alpha, const double *log_psi,
	long long dim, long long ghost)
{
	long long i;
	int j;
	FILE *file = fopen(filename, "w");
	if (file == NULL)
	{
		fprintf(stderr, "OUTPUT: could not write %s\n", filename);
		return -1;
	}

	for (i = ghost; i < dim; ++i)
	{
		for (j = 0; j < ISCO_THETA_POINTS; ++j)
		{
			double value = 0.0;
			switch (kind)
			{
			case GRID_RADIUS: value = r[i]; break;
			case GRID_THETA: value = 0.5 * M_PI * j / (ISCO_THETA_POINTS - 1); break;
			case GRID_LOG_ALPHA: value = log_alpha[i]; break;
			case GRID_LOG_SPATIAL: value = 2.0 * log_psi[i]; break;
			case GRID_BETA: value = 0.0; break;
			}
			fprintf(file, j + 1 == ISCO_THETA_POINTS ? "%.18E" : "%.18E ", value);
		}
		fputc('\n', file);
	}

	if (fclose(file) != 0)
	{
		fprintf(stderr, "OUTPUT: could not close %s\n", filename);
		return -1;
	}
	return 0;
}

static int write_metadata(double m, double omega, int potential_type,
	double lambda_4, double lambda_6, double f_axion,
	double sigma_soliton, double kappa_kkls,
	double M_Komar, double M_ADM, double phi_max, long long error_code,
	double dr, long long NrInterior, long long order, long long radial_points)
{
	FILE *file = fopen("run_metadata.txt", "w");
	if (file == NULL)
	{
		fprintf(stderr, "OUTPUT: could not write run_metadata.txt\n");
		return -1;
	}

	fprintf(file, "format_version=1\n");
	fprintf(file, "solver=SPHBOSON\n");
	fprintf(file, "potential=%s\n", potential_name(potential_type));
	fprintf(file, "potential_type=%d\n", potential_type);
	fprintf(file, "coupling_name=%s\n", potential_coupling_name(potential_type));
	fprintf(file, "coupling_value=%.17E\n", potential_coupling_value(potential_type,
		lambda_4, lambda_6, f_axion, sigma_soliton, kappa_kkls));
	fprintf(file, "lambda_4=%.17E\n", lambda_4);
	fprintf(file, "lambda_6=%.17E\n", lambda_6);
	fprintf(file, "f_axion=%.17E\n", f_axion);
	fprintf(file, "sigma_soliton=%.17E\n", sigma_soliton);
	fprintf(file, "kappa_kkls=%.17E\n", kappa_kkls);
	fprintf(file, "m=%.17E\n", m);
	fprintf(file, "l=0\n");
	fprintf(file, "omega=%.17E\n", omega);
	fprintf(file, "phi_max=%.17E\n", phi_max);
	fprintf(file, "dr=%.17E\n", dr);
	fprintf(file, "NrInterior=%lld\n", NrInterior);
	fprintf(file, "order=%lld\n", order);
	fprintf(file, "NrrTotal=%lld\n", radial_points);
	fprintf(file, "NthTotal=%d\n", ISCO_THETA_POINTS);
	fprintf(file, "error_code=%lld\n", error_code);
	fprintf(file, "convergence_status=%s\n", error_code == 0 ? "converged" : "not_converged");
	fprintf(file, "M_Komar=%.17E\n", M_Komar);
	fprintf(file, "M_ADM=%.17E\n", M_ADM);
	fprintf(file, "J_Komar=0.00000000000000000E+00\n");
	return fclose(file) == 0 ? 0 : -1;
}

int write_isco_export(const double *r, const double *log_alpha,
	const double *log_psi, long long dim, long long ghost,
	double m, double omega, int potential_type,
	double lambda_4, double lambda_6, double f_axion,
	double sigma_soliton, double kappa_kkls,
	double M_Komar, double M_ADM, double phi_max, long long error_code,
	double dr, long long NrInterior, long long order)
{
	int status = 0;
	status |= write_grid("sph_rr.asc", GRID_RADIUS, r, log_alpha, log_psi, dim, ghost);
	status |= write_grid("sph_th.asc", GRID_THETA, r, log_alpha, log_psi, dim, ghost);
	status |= write_grid("sph_log_alpha_f.asc", GRID_LOG_ALPHA, r, log_alpha, log_psi, dim, ghost);
	status |= write_grid("sph_beta_f.asc", GRID_BETA, r, log_alpha, log_psi, dim, ghost);
	status |= write_grid("sph_log_h_f.asc", GRID_LOG_SPATIAL, r, log_alpha, log_psi, dim, ghost);
	status |= write_grid("sph_log_a_f.asc", GRID_LOG_SPATIAL, r, log_alpha, log_psi, dim, ghost);
	status |= write_metadata(m, omega, potential_type, lambda_4, lambda_6,
		f_axion, sigma_soliton, kappa_kkls, M_Komar, M_ADM, phi_max, error_code,
		dr, NrInterior, order, dim - ghost);
	return status;
}
