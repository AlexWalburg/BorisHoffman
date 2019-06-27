#pragma once

#include "Boris_Enums_Defs.h"
#if COMPILECUDA == 1

//Defines non-stochastic equations

#include "BorisCUDALib.h"

#include "ManagedDiffEqCUDA.h"

#include "DiffEq_Defs.h"

#include "Funcs_Math_base.h" //includes constant values

#include "MeshParamsControlCUDA.h"

//----------------------------------------- EQUATIONS

//------------------------------------------------------------------------------------------------------

__device__ cuReal3 ManagedDiffEqCUDA::LLG(int idx)
{
	//gamma = -mu0 * gamma_e = mu0 * g e / 2m_e = 2.212761569e5 m/As

	//LLG in explicit form : dm/dt = [mu0*gamma_e/(1+alpha^2)] * [m*H + alpha * m*(m*H)]

	cuVEC_VC<cuReal3>& M = *pcuMesh->pM;
	cuVEC<cuReal3>& Heff = *pcuMesh->pHeff;

	cuReal Ms = *pcuMesh->pMs;
	cuReal alpha = *pcuMesh->palpha;
	cuReal grel = *pcuMesh->pgrel;
	pcuMesh->update_parameters_mcoarse(idx, *pcuMesh->pMs, Ms, *pcuMesh->palpha, alpha, *pcuMesh->pgrel, grel);

	return (-(cuReal)GAMMA * grel / (1 + alpha * alpha)) * ((M[idx] ^ Heff[idx]) + alpha * ((M[idx] / Ms) ^ (M[idx] ^ Heff[idx])));
}

//------------------------------------------------------------------------------------------------------

__device__ cuReal3 ManagedDiffEqCUDA::LLGSTT(int idx)
{
	//gmub_2e is -hbar * gamma_e / 2e = g mu_b / 2e)

	// LLG with STT in explicit form : dm/dt = [mu0*gamma_e/(1+alpha^2)] * [m*H + alpha * m*(m*H)] + (1+alpha*beta)/((1+alpha^2)*(1+beta^2)) * (u.del)m - (beta - alpha)/(1+alpha^2) * m * (u.del) m
	// where u = j * P g mu_b / 2e Ms = -(hbar * gamma_e * P / 2 *e * Ms) * j, j is the current density = conductivity * E (A/m^2)

	// STT is Zhang-Li formulation (not Thiaville, the velocity used by Thiaville needs to be divided by (1+beta^2) to obtain Zhang-Li, also Thiaville's EPL paper has wrong STT signs!!)

	cuVEC_VC<cuReal3>& M = *pcuMesh->pM;
	cuVEC<cuReal3>& Heff = *pcuMesh->pHeff;
	cuVEC<cuReal3>& Jc = *pcuMesh->pJc;

	cuReal Ms = *pcuMesh->pMs;
	cuReal alpha = *pcuMesh->palpha;
	cuReal grel = *pcuMesh->pgrel;
	cuReal P = *pcuMesh->pP;
	cuReal beta = *pcuMesh->pbeta;
	pcuMesh->update_parameters_mcoarse(idx, *pcuMesh->pMs, Ms, *pcuMesh->palpha, alpha, *pcuMesh->pgrel, grel, *pcuMesh->pP, P, *pcuMesh->pbeta, beta);

	cuReal3 LLGSTT_Eval = (-(cuReal)GAMMA * grel / (1 + alpha*alpha)) * ((M[idx] ^ Heff[idx]) + alpha * ((M[idx] / Ms) ^ (M[idx] ^ Heff[idx])));

	if (Jc.linear_size()) {

		cuSZ3 n = M.n;
		cuReal3 h = M.h;

		cuReal33 grad_M = M.grad_neu(idx);

		cuReal3 u = (Jc.weighted_average(cuINT3(idx % n.x, (idx / n.x) % n.y, idx / (n.x*n.y)), h) * P * (cuReal)GMUB_2E) / (Ms * (1 + beta*beta));

		cuReal3 u_dot_del_M = (u.x * grad_M.x) + (u.y * grad_M.y) + (u.z * grad_M.z);

		LLGSTT_Eval += (((1 + alpha * beta) * u_dot_del_M) - ((beta - alpha) * ((M[idx] / Ms) ^ u_dot_del_M))) / (1 + alpha * alpha);
	}

	return LLGSTT_Eval;
}

//------------------------------------------------------------------------------------------------------

__device__ cuReal3 ManagedDiffEqCUDA::LLB(int idx)
{
	//gamma = -mu0 * gamma_e = mu0 * g e / 2m_e = 2.212761569e5 m/As

	//LLB in explicit form : dM/dt = [mu0*gamma_e/(1+alpha_perp_red^2)] * [M*H + alpha_perp_red * (M/|M|)*(M*H)] - mu0*gamma_e* alpha_par_red * (M.(H + Hl)) * (M/|M|)

	//alpha_perp_red = alpha / m
	//alpha_par_red = 2*(alpha0 - alpha)/m up to Tc, then alpha_par_red = alpha_perp_red above Tc, where alpha0 is the zero temperature damping and alpha is the damping at a given temperature
	//m = |M| / Ms0, where Ms0 is the zero temperature saturation magnetization
	//
	//There is a longitudinal relaxation field Hl = M * (1 - (|M|/Ms)^2) / (2*suspar), where Ms is the equilibrium magnetization (i.e. the "saturation" magnetization at the given temperature - obtained from Ms)
	//
	//Ms, suspar and alpha must have temperature dependence set. In particular:
	//alpha = alpha0 * (1 - T/3Tc) up to Tc, alpha = (2*alpha0*T/3Tc) above Tc
	//For Ms and suspar see literature (e.g. S.Lepadatu, JAP 120, 163908 (2016))

	cuVEC_VC<cuReal3>& M = *pcuMesh->pM;
	cuVEC<cuReal3>& Heff = *pcuMesh->pHeff;

	cuReal T_Curie = *pcuMesh->pT_Curie;

	//cell temperature : the base temperature if uniform temperature, else get the temperature from Temp
	cuReal Temperature;
	if (pcuMesh->pTemp->linear_size()) Temperature = (*pcuMesh->pTemp)[pcuMesh->pM->cellidx_to_position(idx)];
	else Temperature = *pcuMesh->pbase_temperature;

	cuReal Ms = *pcuMesh->pMs;
	cuReal alpha = *pcuMesh->palpha;
	cuReal grel = *pcuMesh->pgrel;
	cuReal susrel = *pcuMesh->psusrel;
	pcuMesh->update_parameters_mcoarse(idx, *pcuMesh->pMs, Ms, *pcuMesh->palpha, alpha, *pcuMesh->pgrel, grel, *pcuMesh->psusrel, susrel);

	//m is M / Ms0 : magnitude of M in this cell divided by the saturation magnetization at 0K.
	cuReal Mnorm = M[idx].norm();
	cuReal Ms0 = pcuMesh->pMs->get0();
	cuReal m = Mnorm / Ms0;

	//reduced perpendicular damping - alpha must have the correct temperature dependence set (normally scaled by 1 - T/3Tc, where Tc is the Curie temperature)
	cuReal alpha_perp_red = alpha / m;

	//reduced parallel damping
	cuReal alpha_par_red;

	if (Temperature < T_Curie) alpha_par_red = 2 * (pcuMesh->palpha->get0() / m - alpha_perp_red);
	else alpha_par_red = alpha_perp_red;

	//the longitudinal relaxation field - an effective field contribution, but only need to add it to the longitudinal relaxation term as the others involve cross products with M[idx]
	cuReal3 Hl;

	//if susrel is zero (e.g. at T = 0K) then turn off longitudinal damping - this reduces LLB to LLG assuming everything is configured correctly
	//Note, the parallel susceptibility is related to susrel by : susrel = suspar / mu0Ms
	if (cuIsNZ((cuReal)susrel)) {

		//longitudinal relaxation field up to the Curie temperature
		if (Temperature <= T_Curie) {

			Hl = M[idx] * ((1 - (Mnorm / Ms) * (Mnorm / Ms)) / (2 * susrel * (cuReal)MU0 * Ms0));
		}
		//longitudinal relaxation field beyond the Curie temperature
		else {

			Hl = -1 * M[idx] * (1 + (3 / 5) * T_Curie * m * m / (Temperature - T_Curie)) / (susrel * (cuReal)MU0 * Ms0);
		}
	}
	else alpha_par_red = 0.0;

	return (-(cuReal)GAMMA * grel / (1 + alpha_perp_red * alpha_perp_red)) * ((M[idx] ^ Heff[idx]) + alpha_perp_red * ((M[idx] / Mnorm) ^ (M[idx] ^ Heff[idx]))) +
		(cuReal)GAMMA * grel * alpha_par_red * (M[idx] * (Heff[idx] + Hl)) * (M[idx] / Mnorm);
}

//------------------------------------------------------------------------------------------------------

__device__ cuReal3 ManagedDiffEqCUDA::LLBSTT(int idx)
{
	//gamma = -mu0 * gamma_e = mu0 * g e / 2m_e = 2.212761569e5 m/As

	//LLB in explicit form : dM/dt = [mu0*gamma_e/(1+alpha_perp_red^2)] * [M*H + alpha_perp_red * (M/|M|)*(M*H)] - mu0*gamma_e* alpha_par_red * (M.(H + Hl)) * (M/|M|)

	//alpha_perp_red = alpha / m
	//alpha_par_red = 2*(alpha0 - alpha)/m up to Tc, then alpha_par_red = alpha_perp_red above Tc, where alpha0 is the zero temperature damping and alpha is the damping at a given temperature
	//m = |M| / Ms0, where Ms0 is the zero temperature saturation magnetization
	//
	//There is a longitudinal relaxation field Hl = M * (1 - (|M|/Ms)^2) / (2*suspar), where Ms is the equilibrium magnetization (i.e. the "saturation" magnetization at the given temperature - obtained from Ms)
	//
	//Ms, suspar and alpha must have temperature dependence set. In particular:
	//alpha = alpha0 * (1 - T/3Tc) up to Tc, alpha = (2*alpha0*T/3Tc) above Tc
	//For Ms and suspar see literature (e.g. S.Lepadatu, JAP 120, 163908 (2016))

	//on top of this we have STT contributions

	cuVEC_VC<cuReal3>& M = *pcuMesh->pM;
	cuVEC<cuReal3>& Heff = *pcuMesh->pHeff;
	cuVEC<cuReal3>& Jc = *pcuMesh->pJc;

	cuReal T_Curie = *pcuMesh->pT_Curie;

	//cell temperature : the base temperature if uniform temperature, else get the temperature from Temp
	cuReal Temperature;
	if (pcuMesh->pTemp->linear_size()) Temperature = (*pcuMesh->pTemp)[pcuMesh->pM->cellidx_to_position(idx)];
	else Temperature = *pcuMesh->pbase_temperature;

	cuReal Ms = *pcuMesh->pMs;
	cuReal alpha = *pcuMesh->palpha;
	cuReal grel = *pcuMesh->pgrel;
	cuReal susrel = *pcuMesh->psusrel;
	cuReal P = *pcuMesh->pP;
	cuReal beta = *pcuMesh->pbeta;
	pcuMesh->update_parameters_mcoarse(idx, *pcuMesh->pMs, Ms, *pcuMesh->palpha, alpha, *pcuMesh->pgrel, grel, *pcuMesh->psusrel, susrel, *pcuMesh->pP, P, *pcuMesh->pbeta, beta);

	//m is M / Ms0 : magnitude of M in this cell divided by the saturation magnetization at 0K.
	cuReal Mnorm = M[idx].norm();
	cuReal Ms0 = pcuMesh->pMs->get0();
	cuReal m = Mnorm / Ms0;

	//reduced perpendicular damping - alpha must have the correct temperature dependence set (normally scaled by 1 - T/3Tc, where Tc is the Curie temperature)
	cuReal alpha_perp_red = alpha / m;

	//reduced parallel damping
	cuReal alpha_par_red = 0.0;

	//set reduced parallel damping
	if (Temperature <= T_Curie) alpha_par_red = 2 * (pcuMesh->palpha->get0() / m - alpha_perp_red);
	else alpha_par_red = alpha_perp_red;

	//the longitudinal relaxation field - an effective field contribution, but only need to add it to the longitudinal relaxation term as the others involve cross products with M[idx]
	cuReal3 Hl = cuReal3(0.0);

	//Note, the parallel susceptibility is related to susrel by : susrel = suspar / mu0Ms

	//set longitudinal relaxation field
	if (cuIsNZ((cuReal)susrel)) {

		//longitudinal relaxation field up to the Curie temperature
		if (Temperature <= T_Curie) {

			Hl = M[idx] * ((1 - (Mnorm / Ms) * (Mnorm / Ms)) / (2 * susrel * (cuReal)MU0 * Ms0));
		}
		//longitudinal relaxation field beyond the Curie temperature
		else {

			Hl = -1 * M[idx] * (1 + (3 / 5) * T_Curie * m * m / (Temperature - T_Curie)) / (susrel * (cuReal)MU0 * Ms0);
		}
	}
	else alpha_par_red = 0.0;

	cuReal3 LLBSTT_Eval =
		(-(cuReal)GAMMA * grel / (1 + alpha_perp_red * alpha_perp_red)) * ((M[idx] ^ Heff[idx]) + alpha_perp_red * ((M[idx] / Mnorm) ^ (M[idx] ^ Heff[idx]))) +
		(cuReal)GAMMA * grel * alpha_par_red * (M[idx] * (Heff[idx] + Hl)) * (M[idx] / Mnorm);

	if (Jc.linear_size()) {

		cuSZ3 n = M.n;
		cuReal3 h = M.h;

		cuReal33 grad_M = M.grad_neu(idx);

		cuReal3 u = (Jc.weighted_average(cuINT3(idx % n.x, (idx / n.x) % n.y, idx / (n.x*n.y)), h) * P * (cuReal)GMUB_2E) / (Ms * (1 + beta * beta));

		cuReal3 u_dot_del_M = (u.x * grad_M.x) + (u.y * grad_M.y) + (u.z * grad_M.z);

		LLBSTT_Eval +=
			(((1 + alpha_perp_red * beta) * u_dot_del_M) -
			((beta - alpha_perp_red) * ((M[idx] / Mnorm) ^ u_dot_del_M)) -
				(alpha_perp_red * (beta - alpha_perp_red) * (M[idx] / Mnorm) * ((M[idx] / Mnorm) * u_dot_del_M))) / (1 + alpha_perp_red * alpha_perp_red);
	}

	return LLBSTT_Eval;
}

#endif