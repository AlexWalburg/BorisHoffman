#include "stdafx.h"
#include "DiffEqFM.h"

#ifdef MESH_COMPILATION_FERROMAGNETIC

#include "Mesh_Ferromagnetic.h"
#include "SuperMesh.h"
#include "MeshParamsControl.h"

//------------------------------------------------------------------------------------------------------ THERMAL VECs GENERATIONS

//
// Thermal field given as :
//
// Hth_magnitude = rand * SQRT( 2*alpha* kb*T / (MU0*|gamma_e|*V*MU0*Ms0*dT)) / alpha   (A/m) -> the thermal field is added only to the damping torque in LLG or in the LLB transverse damping torque.
// 
// For LLB thermal damping field, it is rand * SQRT( 2*(alpha_per - alpha_par)* kb*T / (MU0*|gamma_e|*V*MU0*Ms0*dT)) / alpha_per -> reduces to  the LLG version at T = 0K
// For LLB longitudinal thermal torque, its magnitude is rand * SQRT(2*|gamma_e|*Ms0* kb*T * alpha_par / V * dT) -> this is the sLLB-II version from PRB 85, 014433 (2012)
//
// Note : alpha_per = alpha0*(1 - T/3Tc) for T < Tc, 2*alpha0*T/3Tc for T>=Tc
//		  alpha_par = 2*alpha0*T/3Tc for T < Tc, alpha_par = alpha_per for T >= Tc
//
// So : alpha_per - alpha_par = alpha0 * (1 - T/Tc) for T < Tc, then 0 for T >= Tc
//
// kB has units of m^2kg / s^2K
// gamma_e has units of As/kg
// mu0 has units of N/A^2
//
// V is the volume of the mesh cell
//
// rand is a random factor between 0 and 1
//

void DifferentialEquationFM::GenerateThermalField(void)
{
	//NOTE !!! Do not use separate distributions for theta and phi. I tried first for the polar angle a distribution from 0 to pi, and for azimuthal 0 to 2pi - It doesn't work, the resulting field tends to be polarized towards the left. I don't understand!!!!

	double grel = pMesh->grel.get0();

	if (IsNZ(grel)) {

#pragma omp parallel for
		for (int idx = 0; idx < pMesh->n_s.dim(); idx++) {

			double Temperature;

			if (pMesh->Temp.linear_size()) {

				Temperature = pMesh->Temp[H_Thermal.cellidx_to_position(idx)];
			}
			else Temperature = pMesh->GetBaseTemperature();

			//do not include any damping here - this will be included in the stochastic equations
			double Hth_const = sqrt(2 * BOLTZMANN * Temperature / (GAMMA * grel * pMesh->h_s.dim() * MU0 * pMesh->Ms.get0() * dT));
				
			H_Thermal[idx] = Hth_const * DBL3(prng.rand_gauss(0, 1), prng.rand_gauss(0, 1), prng.rand_gauss(0, 1));
		}
	}
}

void DifferentialEquationFM::GenerateThermalField_and_Torque(void)
{
	double grel = pMesh->grel.get0();

	if (IsNZ(grel)) {

#pragma omp parallel for
		for (int idx = 0; idx < pMesh->n_s.dim(); idx++) {

			double Temperature;

			if (pMesh->Temp.linear_size()) {

				Temperature = pMesh->Temp[H_Thermal.cellidx_to_position(idx)];
			}
			else Temperature = pMesh->GetBaseTemperature();

			//1. Thermal Field

			//do not include any damping here - this will be included in the stochastic equations
			double Hth_const = sqrt(2 * BOLTZMANN * Temperature / (GAMMA * grel * pMesh->h_s.dim() * MU0 * pMesh->Ms.get0() * dT));

			H_Thermal[idx] = Hth_const * DBL3(prng.rand_gauss(0, 1), prng.rand_gauss(0, 1), prng.rand_gauss(0, 1));

			//2. Thermal Torque

			//do not include any damping here - this will be included in the stochastic equations
			double Tth_const = sqrt(2 * BOLTZMANN * Temperature * GAMMA * grel * pMesh->Ms.get0() / (MU0 * pMesh->h_s.dim() * dT));

			Torque_Thermal[idx] = Tth_const * DBL3(prng.rand_gauss(0, 1), prng.rand_gauss(0, 1), prng.rand_gauss(0, 1));
		}
	}
}


//------------------------------------------------------------------------------------------------------ STOCHASTIC EQUATIONS

DBL3 DifferentialEquationFM::SLLG(int idx)
{
	//gamma = -mu0 * gamma_e = mu0 * g e / 2m_e = 2.212761569e5 m/As

	//LLG in explicit form : dm/dt = [mu0*gamma_e/(1+alpha^2)] * [m*H + alpha * m*(m*H)]

	//Add thermal field to damping term, remembering to include damping contribution which was not included when H_Thermal was generated
	
	double Ms = pMesh->Ms;
	double alpha = pMesh->alpha;
	double grel = pMesh->grel;
	pMesh->update_parameters_mcoarse(idx, pMesh->Ms, Ms, pMesh->alpha, alpha, pMesh->grel, grel);

	DBL3 position = pMesh->M.cellidx_to_position(idx);
	DBL3 H_Thermal_Value = H_Thermal[position] / sqrt(alpha);

	return (-GAMMA * pMesh->grel / (1 + alpha*alpha)) * ((pMesh->M[idx] ^ pMesh->Heff[idx]) + 
		alpha * ((pMesh->M[idx] / Ms) ^ (pMesh->M[idx] ^ (pMesh->Heff[idx] + H_Thermal_Value))));
}

//------------------------------------------------------------------------------------------------------

DBL3 DifferentialEquationFM::SLLGSTT(int idx)
{
	//gmub_2e is -hbar * gamma_e / 2e = g mu_b / 2e)

	// LLG with STT in explicit form : dm/dt = [mu0*gamma_e/(1+alpha^2)] * [m*H + alpha * m*(m*H)] + (1+alpha*beta)/((1+alpha^2)*(1+beta^2)) * (u.del)m - (beta - alpha)/(1+alpha^2) * m * (u.del) m
	// where u = j * P g mu_b / 2e Ms = -(hbar * gamma_e * P / 2 *e * Ms) * j, j is the current density = conductivity * E (A/m^2)

	// STT is Zhang-Li equationtion (not Thiaville, the velocity used by Thiaville needs to be divided by (1+beta^2) to obtain Zhang-Li, also Thiaville's EPL paper has wrong STT signs!!)

	//Add thermal field to damping term, remembering to include damping contribution which was not included when H_Thermal was generated
	
	double Ms = pMesh->Ms;
	double alpha = pMesh->alpha;
	double grel = pMesh->grel;
	double P = pMesh->P;
	double beta = pMesh->beta;
	pMesh->update_parameters_mcoarse(idx, pMesh->Ms, Ms, pMesh->alpha, alpha, pMesh->grel, grel, pMesh->P, P, pMesh->beta, beta);

	DBL3 position = pMesh->M.cellidx_to_position(idx);
	DBL3 H_Thermal_Value = H_Thermal[position] / sqrt(alpha);

	DBL3 LLGSTT_Eval = (-GAMMA * pMesh->grel / (1 + alpha*alpha)) * ((pMesh->M[idx] ^ pMesh->Heff[idx]) +
		alpha * ((pMesh->M[idx] / Ms) ^ (pMesh->M[idx] ^ (pMesh->Heff[idx] + H_Thermal_Value))));

	if (pMesh->E.linear_size()) {

		DBL33 grad_M = pMesh->M.grad_neu(idx);

		DBL3 u = (pMesh->elC[position] * pMesh->E.weighted_average(position, pMesh->h) * P * GMUB_2E) / (Ms * (1 + beta*beta));

		DBL3 u_dot_del_M = (u.x * grad_M.x) + (u.y * grad_M.y) + (u.z * grad_M.z);

		LLGSTT_Eval +=
			(((1 + alpha * beta) * u_dot_del_M) -
			((beta - alpha) * ((pMesh->M[idx] / Ms) ^ u_dot_del_M))) / (1 + alpha * alpha);
	}

	return LLGSTT_Eval;
}

//------------------------------------------------------------------------------------------------------

DBL3 DifferentialEquationFM::SLLB(int idx)
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

	//Add thermal field to damping term, and thermal torque to evaluation, remembering to include damping contribution which was not included when H_Thermal was generated

	DBL3 position = pMesh->M.cellidx_to_position(idx);

	double T_Curie = pMesh->GetCurieTemperature();

	//cell temperature : the base temperature if uniform temperature, else get the temperature from Temp
	double Temperature;
	if (pMesh->Temp.linear_size()) Temperature = pMesh->Temp[position];
	else Temperature = pMesh->base_temperature;

	//m is M / Ms0 : magnitude of M in this cell divided by the saturation magnetization at 0K.
	double M = pMesh->M[idx].norm();
	double Ms0 = pMesh->Ms.get0();
	double mM = M * M / Ms0;

	double Ms = pMesh->Ms;
	double alpha = pMesh->alpha;
	double grel = pMesh->grel;
	double susrel = pMesh->susrel;

	double alpha_par;

	//the longitudinal relaxation field - an effective field contribution, but only need to add it to the longitudinal relaxation term as the others involve cross products with pMesh->M[idx]
	DBL3 Hl;

	if (Temperature < T_Curie) {

		if (Temperature > T_Curie - TCURIE_EPSILON) {

			Ms = pMesh->Ms.get(T_Curie - TCURIE_EPSILON);
			alpha = pMesh->alpha.get(T_Curie - TCURIE_EPSILON);
			grel = pMesh->grel.get(T_Curie - TCURIE_EPSILON);
			susrel = pMesh->susrel.get(T_Curie - TCURIE_EPSILON);
		}
		else pMesh->update_parameters_mcoarse(idx, pMesh->Ms, Ms, pMesh->alpha, alpha, pMesh->grel, grel, pMesh->susrel, susrel);

		alpha_par = 2 * (pMesh->alpha.get0() - alpha);

		//Note, the parallel susceptibility is related to susrel by : susrel = suspar / mu0Ms
		Hl = pMesh->M[idx] * ((1 - (M / Ms) * (M / Ms)) / (2 * susrel * MU0 * Ms0));
	}
	else {

		if (Temperature < T_Curie + TCURIE_EPSILON) {

			alpha = pMesh->alpha.get(T_Curie + TCURIE_EPSILON);
			grel = pMesh->grel.get(T_Curie + TCURIE_EPSILON);
			susrel = pMesh->susrel.get(T_Curie + TCURIE_EPSILON);
		}
		else pMesh->update_parameters_mcoarse(idx, pMesh->alpha, alpha, pMesh->grel, grel, pMesh->susrel, susrel);

		alpha_par = alpha;

		//Note, the parallel susceptibility is related to susrel by : susrel = suspar / mu0Ms
		Hl = -1.0 * pMesh->M[idx] / (susrel * MU0 * Ms0);
	}

	DBL3 H_Thermal_Value = H_Thermal[position] * sqrt(alpha - alpha_par) / alpha;
	DBL3 Torque_Thermal_Value = Torque_Thermal[position] * sqrt(alpha_par);

	return (-GAMMA * grel / (1 + alpha * alpha)) * ((pMesh->M[idx] ^ pMesh->Heff[idx]) + alpha * ((pMesh->M[idx] / mM) ^ (pMesh->M[idx] ^ (pMesh->Heff[idx] + H_Thermal_Value)))) +
		GAMMA * grel * alpha_par * (pMesh->M[idx] * (pMesh->Heff[idx] + Hl)) * (pMesh->M[idx] / mM) + Torque_Thermal_Value;
}

//------------------------------------------------------------------------------------------------------

DBL3 DifferentialEquationFM::SLLBSTT(int idx)
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

	//Add thermal field to damping term, and thermal torque to evaluation, remembering to include damping contribution which was not included when H_Thermal was generated
	
	DBL3 position = pMesh->M.cellidx_to_position(idx);

	double T_Curie = pMesh->GetCurieTemperature();

	//cell temperature : the base temperature if uniform temperature, else get the temperature from Temp
	double Temperature;
	if (pMesh->Temp.linear_size()) Temperature = pMesh->Temp[position];
	else Temperature = pMesh->base_temperature;

	//m is M / Ms0 : magnitude of M in this cell divided by the saturation magnetization at 0K.
	double M = pMesh->M[idx].norm();
	double Ms0 = pMesh->Ms.get0();
	double m = M / Ms0;
	double mM = M * M / Ms0;

	double Ms = pMesh->Ms;
	double alpha = pMesh->alpha;
	double grel = pMesh->grel;
	double susrel = pMesh->susrel;
	double P = pMesh->P;
	double beta = pMesh->beta;

	double alpha_par;

	//the longitudinal relaxation field - an effective field contribution, but only need to add it to the longitudinal relaxation term as the others involve cross products with pMesh->M[idx]
	DBL3 Hl;

	if (Temperature < T_Curie) {

		if (Temperature > T_Curie - TCURIE_EPSILON) {

			Ms = pMesh->Ms.get(T_Curie - TCURIE_EPSILON);
			alpha = pMesh->alpha.get(T_Curie - TCURIE_EPSILON);
			grel = pMesh->grel.get(T_Curie - TCURIE_EPSILON);
			susrel = pMesh->susrel.get(T_Curie - TCURIE_EPSILON);
			P = pMesh->P.get(T_Curie - TCURIE_EPSILON);
			beta = pMesh->beta.get(T_Curie - TCURIE_EPSILON);
		}
		else pMesh->update_parameters_mcoarse(idx, pMesh->Ms, Ms, pMesh->alpha, alpha, pMesh->grel, grel, pMesh->susrel, susrel, pMesh->P, P, pMesh->beta, beta);

		alpha_par = 2 * (pMesh->alpha.get0() - alpha);

		//Note, the parallel susceptibility is related to susrel by : susrel = suspar / mu0Ms
		Hl = pMesh->M[idx] * ((1 - (M / Ms) * (M / Ms)) / (2 * susrel * MU0 * Ms0));
	}
	else {

		if (Temperature < T_Curie + TCURIE_EPSILON) {

			alpha = pMesh->alpha.get(T_Curie + TCURIE_EPSILON);
			grel = pMesh->grel.get(T_Curie + TCURIE_EPSILON);
			susrel = pMesh->susrel.get(T_Curie + TCURIE_EPSILON);
			P = pMesh->P.get(T_Curie + TCURIE_EPSILON);
			beta = pMesh->beta.get(T_Curie + TCURIE_EPSILON);
		}
		else pMesh->update_parameters_mcoarse(idx, pMesh->alpha, alpha, pMesh->grel, grel, pMesh->susrel, susrel, pMesh->P, P, pMesh->beta, beta);

		alpha_par = alpha;

		//Note, the parallel susceptibility is related to susrel by : susrel = suspar / mu0Ms
		Hl = -1 * pMesh->M[idx] / (susrel * MU0 * Ms0);
	}

	DBL3 H_Thermal_Value = H_Thermal[position] * sqrt(alpha - alpha_par) / alpha;
	DBL3 Torque_Thermal_Value = Torque_Thermal[position] * sqrt(alpha_par);

	DBL3 LLBSTT_Eval =
		(-GAMMA * grel / (1 + alpha * alpha)) * ((pMesh->M[idx] ^ pMesh->Heff[idx]) + alpha * ((pMesh->M[idx] / mM) ^ (pMesh->M[idx] ^ (pMesh->Heff[idx] + H_Thermal_Value)))) +
		GAMMA * grel * alpha_par * (pMesh->M[idx] * (pMesh->Heff[idx] + Hl)) * (pMesh->M[idx] / mM) + Torque_Thermal_Value;

	if (pMesh->E.linear_size()) {

		DBL33 grad_M = pMesh->M.grad_neu(idx);

		DBL3 u = (pMesh->elC[position] * pMesh->E.weighted_average(position), pMesh->h * P * GMUB_2E) / (Ms * (1 + beta * beta));

		DBL3 u_dot_del_M = (u.x * grad_M.x) + (u.y * grad_M.y) + (u.z * grad_M.z);

		double alpha_perp_red = alpha / m;

		LLBSTT_Eval +=
			(((1 + alpha_perp_red * beta) * u_dot_del_M) -
			((beta - alpha_perp_red) * ((pMesh->M[idx] / M) ^ u_dot_del_M)) -
				(alpha_perp_red * (beta - alpha_perp_red) * (pMesh->M[idx] / M) * ((pMesh->M[idx] / M) * u_dot_del_M))) / (1 + alpha * alpha);
	}

	return LLBSTT_Eval;
}

#endif