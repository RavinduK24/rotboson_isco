#include "../src/tools.h"
#define MAIN_FILE
#include "../src/param.h"

#include "../src/csr.h"
#include "../src/omega_calc.h"
#include "../src/potential.h"
#include "../src/rhs.h"

static void csr_matvec(const csr_matrix *matrix, const double *vector, double *product)
{
	MKL_INT row, entry;
	for (row = 0; row < matrix->nrows; ++row)
	{
		product[row] = 0.0;
		for (entry = matrix->ia[row] - BASE; entry < matrix->ia[row + 1] - BASE; ++entry)
			product[row] += matrix->a[entry] * vector[matrix->ja[entry] - BASE];
	}
}

static void allocate_work_arrays(void)
{
	Dr_u = SAFE_MALLOC((GNUM * dim + 1) * sizeof(double));
	Dz_u = SAFE_MALLOC((GNUM * dim + 1) * sizeof(double));
	Drr_u = SAFE_MALLOC((GNUM * dim + 1) * sizeof(double));
	Dzz_u = SAFE_MALLOC((GNUM * dim + 1) * sizeof(double));
	Drz_u = SAFE_MALLOC((GNUM * dim + 1) * sizeof(double));
	u_aux = SAFE_MALLOC(2 * dim * sizeof(double));
	Dr_u_aux = SAFE_MALLOC(2 * dim * sizeof(double));
}

static void free_work_arrays(void)
{
	SAFE_FREE(Dr_u);
	SAFE_FREE(Dz_u);
	SAFE_FREE(Drr_u);
	SAFE_FREE(Dzz_u);
	SAFE_FREE(Drz_u);
	SAFE_FREE(u_aux);
	SAFE_FREE(Dr_u_aux);
}

static double check_case(MKL_INT finite_difference_order, MKL_INT type)
{
	const double step = 2.0E-6;
	MKL_INT i, j, field, index, size;
	double numerator = 0.0, denominator = 0.0;
	double *u, *plus, *minus, *direction, *fplus, *fminus, *product;
	csr_matrix jacobian;

	order = finite_difference_order;
	ghost = order / 2;
	NrInterior = 12;
	NzInterior = 13;
	NrTotal = NrInterior + 2 * ghost;
	NzTotal = NzInterior + 2 * ghost;
	dim = NrTotal * NzTotal;
	w_idx = GNUM * dim;
	size = GNUM * dim + 1;
	dr = 0.19;
	dz = 0.17;
	l = 1;
	m = 1.0;
	potential_type = type;
	lambda_4 = 0.7;
	lambda_6 = 0.5;
	f_axion = 0.8;
	sigma_soliton = 1.2;
	kappa_kkls = 12.0;
	fixedPhi = 1;
	fixedPhiR = ghost + 2;
	fixedPhiZ = ghost + 2;
	M_KOMAR = 0.2;
	J_KOMAR = 0.03;

	allocate_work_arrays();
	u = SAFE_MALLOC(size * sizeof(double));
	plus = SAFE_MALLOC(size * sizeof(double));
	minus = SAFE_MALLOC(size * sizeof(double));
	direction = SAFE_MALLOC(size * sizeof(double));
	fplus = SAFE_MALLOC(size * sizeof(double));
	fminus = SAFE_MALLOC(size * sizeof(double));
	product = SAFE_MALLOC(size * sizeof(double));

	for (field = 0; field < GNUM; ++field)
		for (i = 0; i < NrTotal; ++i)
			for (j = 0; j < NzTotal; ++j)
			{
				double radius2 = ((double)(i - ghost) + 0.5) * ((double)(i - ghost) + 0.5)
					+ ((double)(j - ghost) + 0.5) * ((double)(j - ghost) + 0.5);
				double envelope = exp(-0.015 * radius2);
				index = field * dim + IDX(i, j);
				switch (field)
				{
				case 0: u[index] = -0.02 * envelope; break;
				case 1: u[index] = -0.01 * envelope; break;
				case 2: u[index] = 0.01 * envelope; break;
				case 3: u[index] = 0.015 * envelope; break;
				case 4: u[index] = 0.08 * envelope; break;
				default: u[index] = 0.002 * envelope; break;
				}
				direction[index] = sin(0.37 * (double)(index + 1));
			}
	u[w_idx] = inverse_omega_calc(0.82, m);
	direction[w_idx] = 0.13;
	for (index = 0; index < size; ++index)
	{
		plus[index] = u[index] + step * direction[index];
		minus[index] = u[index] - step * direction[index];
	}

	rhs(fplus, plus);
	rhs(fminus, minus);
	csr_allocate(&jacobian, size, size, nnz_jacobian());
	csr_gen_jacobian(jacobian, u, 0);
	csr_matvec(&jacobian, direction, product);
	for (index = 0; index < size; ++index)
	{
		double finite_difference = (fplus[index] - fminus[index]) / (2.0 * step);
		double difference = finite_difference - product[index];
		numerator += difference * difference;
		denominator += finite_difference * finite_difference;
	}

	csr_deallocate(&jacobian);
	SAFE_FREE(u);
	SAFE_FREE(plus);
	SAFE_FREE(minus);
	SAFE_FREE(direction);
	SAFE_FREE(fplus);
	SAFE_FREE(fminus);
	SAFE_FREE(product);
	free_work_arrays();
	return sqrt(numerator / denominator);
}

int main(void)
{
	MKL_INT order_value, type;
	int failures = 0;
	for (order_value = 2; order_value <= 4; order_value += 2)
		for (type = POTENTIAL_FREE; type <= POTENTIAL_KKLS; ++type)
		{
			double error = check_case(order_value, type);
			printf("order=%lld potential=%s relative_directional_error=%.6E\n",
				order_value, potential_name(type), error);
			if (!isfinite(error) || error > 5.0E-5)
				++failures;
		}
	return failures == 0 ? EXIT_SUCCESS : EXIT_FAILURE;
}
