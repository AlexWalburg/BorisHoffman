#include "stdafx.h"
#include "DemagTFuncCUDA.h"

#if COMPILECUDA == 1

//Compute the diagonal tensor elements (Dxx, Dyy, Dzz) which has sizes given by N. This applies for irregular cells, specifically for 2D with s.z and d.z allowed to differ; s.x, d.x resp s.y, d.y must be the same.
bool DemagTFuncCUDA::CalcDiagTens2D_Shifted_Irregular_PBC(
	cu_arr<double>& D11, cu_arr<double>& D22, cu_arr<double>& D33,
	cuINT3 N, cuDBL3 s, cuDBL3 d, cuDBL3 shift, 
	bool minus, int asymptotic_distance,
	int x_images, int y_images, int z_images)
{
	//caller can have these negative (which means use inverse pbc for differential operators, but for demag we need them positive)
	x_images = abs(x_images);
	y_images = abs(y_images);
	z_images = abs(z_images);

	//zero the tensor first
	D11.set(0.0);
	D22.set(0.0);
	D33.set(0.0);

	//only use irregular version if you have to
	if (s * 1e-9 == d * 1e-9) return CalcDiagTens2D_Shifted_PBC(D11, D22, D33, N, d, shift, minus, asymptotic_distance, x_images, y_images, z_images);

	if (cuIsZ(shift.x) && cuIsZ(shift.y) && !z_images) {

		//z shift, and no pbc along z
		if (!fill_f_vals_zshifted_irregular(SZ3(
			(x_images ? asymptotic_distance : N.x / 2),
			(y_images ? asymptotic_distance : N.y / 2),
			1), s, d, shift, asymptotic_distance)) return false;
	}

	//Setup asymptotic approximation settings
	demagAsymptoticDiag_xx()->setup(d.x, d.y, d.z);
	demagAsymptoticDiag_yy()->setup(d.y, d.x, d.z);
	demagAsymptoticDiag_zz()->setup(d.z, d.y, d.x);

	int sign = 1;
	if (minus) sign = -1;

	CalcTens2D_Shifted_Irregular_Ldia_PBC(D11, D22, D33, N, s, d, shift, sign, asymptotic_distance, x_images, y_images, z_images);

	return true;
}

//Compute the off-diagonal tensor elements (Dxy, Dxz, Dyz) which has sizes given by N. This applies for irregular cells, specifically for 2D with s.z and d.z allowed to differ; s.x, d.x resp s.y, d.y must be the same.
bool DemagTFuncCUDA::CalcOffDiagTens2D_Shifted_Irregular_PBC(
	cu_arr<double>& D12, cu_arr<double>& D13, cu_arr<double>& D23,
	cuINT3 N, cuDBL3 s, cuDBL3 d, cuDBL3 shift, 
	bool minus, int asymptotic_distance,
	int x_images, int y_images, int z_images)
{
	//caller can have these negative (which means use inverse pbc for differential operators, but for demag we need them positive)
	x_images = abs(x_images);
	y_images = abs(y_images);
	z_images = abs(z_images);

	//zero the tensor first
	D12.set(0.0);
	D13.set(0.0);
	D23.set(0.0);

	//only use irregular version if you have to
	if (s * 1e-9 == d * 1e-9) return CalcOffDiagTens2D_Shifted_PBC(D12, D13, D23, N, s, shift, minus, asymptotic_distance, x_images, y_images, z_images);

	if (cuIsZ(shift.x) && cuIsZ(shift.y) && !z_images) {

		//z shift, and no pbc along z
		if (!fill_g_vals_zshifted_irregular(SZ3(
			(x_images ? asymptotic_distance : N.x / 2),
			(y_images ? asymptotic_distance : N.y / 2),
			1), s, d, shift, asymptotic_distance)) return false;
	}

	//Setup asymptotic approximation settings
	demagAsymptoticOffDiag_xy()->setup(d.x, d.y, d.z);
	demagAsymptoticOffDiag_xz()->setup(d.x, d.z, d.y);
	demagAsymptoticOffDiag_yz()->setup(d.y, d.z, d.x);

	int sign = 1;
	if (minus) sign = -1;

	CalcTens2D_Shifted_Irregular_Lodia_PBC(D12, D13, D23, N, s, d, shift, sign, asymptotic_distance, x_images, y_images, z_images);

	return true;
}

#endif