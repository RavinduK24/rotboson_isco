#ifndef SPHBOSON_ISCO_EXPORT_H
#define SPHBOSON_ISCO_EXPORT_H

int write_isco_export(const double *r, const double *log_alpha,
	const double *log_psi, long long dim, long long ghost,
	double m, double omega, int potential_type,
	double lambda_4, double lambda_6, double f_axion,
	double sigma_soliton, double kappa_kkls,
	double M_Komar, double M_ADM, long long error_code,
	double dr, long long NrInterior, long long order);

#endif
