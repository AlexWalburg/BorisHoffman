#pragma once

#include "Boris_Enums_Defs.h"
#if COMPILECUDA == 1

#if defined(MODULE_COMPILATION_TRANSPORT) && ATOMISTIC == 1

#include "BorisCUDALib.h"

#include "ErrorHandler.h"

#include "ManagedAtom_MeshCUDA.h"

#include "Atom_MeshParamsControlCUDA.h"

#include "Transport_Defs.h"

class Atom_MeshCUDA;
class Atom_TransportCUDA;

//This is held as a cu_obj managed class in TransportCUDA modules
//It provides methods and access to mesh data for use in cuVEC_VC methods.
//The methods have fixed names, e.g. Poisson_RHS is used by Poisson solvers to evaluate the r.h.s. of the Poisson equation
//The a_func, b_func and diff2_func methods are used to set CMBND conditions based on the continuity of a quantity and a flux.
//If V is the potential, then the flux is the function f(V) = a_func + b_func * V', where the V' differential direction is perpendicular to the interface.
//This particular class is used for charge transport within the spin current solver.
class Atom_TransportCUDA_Spin_V_Funcs {

public:

	//spin transport solver type (see Transport_Defs.h) : copy of stsolve in TransportCUDA, but on the gpu so we can use it in device code
	int stsolve;

	//managed mesh for access to all required mesh VECs and material parameters
	ManagedAtom_MeshCUDA* pcuaMesh;

	//dM_dt VEC when we need to do vector calculus operations on it
	//points to cuVEC in TransportCUDA
	cuVEC_VC<cuReal3>* pdM_dt;

	//for Poisson equations for V some values are fixed during relaxation, so pre-calculate them and store here to re-use.
	//points to cuVEC in TransportCUDA
	cuVEC<cuBReal>* pdelsq_V_fixed;

public:

	__host__ void construct_cu_obj(void) {}
	__host__ void destruct_cu_obj(void) {}

	BError set_pointers(Atom_MeshCUDA* paMeshCUDA, Atom_TransportCUDA* pTransportCUDA);

	__host__ void set_stsolve(int stsolve_) { set_gpu_value(stsolve, stsolve_); }

	//this evaluates the Poisson RHS when solving the Poisson equation on V (in the context of full spin solver)
	__device__ cuBReal Poisson_RHS(int idx)
	{
		cuVEC_VC<cuBReal>& V = *pcuaMesh->pV;
		cuVEC_VC<cuBReal>& elC = *pcuaMesh->pelC;
		cuVEC_VC<cuReal3>& S = *pcuaMesh->pS;
		cuVEC_VC<cuReal3>& M1 = *pcuaMesh->pM1;

		//The Poisson solver calls this method to evaluate the RHS of this equation
		cuBReal value = 0.0;

		if (stsolve == STSOLVE_NONE) {

			value = -(V.grad_diri(idx) * elC.grad_sided(idx)) / elC[idx];
		}
		else {

			//TO DO
			/*

			//homogeneous Neumann boundary condition applies to V in magnetic meshes
			cuReal3 grad_V = V.grad_diri(idx);

			//1. principal term : always present
			value = -(grad_V * elC.grad_sided(idx)) / elC[idx];

			//2. topological Hall effect contribution
			if (cuIsNZ(pcuaMesh->pthe_eff->get0())) {

				cuBReal Ms = *pcuaMesh->pMs;
				cuBReal P = *pcuaMesh->pP;
				cuBReal n_density = *pcuaMesh->pn_density;
				pcuaMesh->update_parameters_ecoarse(idx, *pcuaMesh->pMs, Ms, *pcuaMesh->pP, P, *pcuaMesh->pn_density, n_density);

				int idx_M = M.position_to_cellidx(V.cellidx_to_position(idx));
				cuReal3 m = M[idx_M] / Ms;

				cuReal33 grad_m = M.grad_neu(idx_M) / Ms;
				cuReal3 dx_m = grad_m.x;
				cuReal3 dy_m = grad_m.y;
				cuReal3 dxy_m = M.dxy_neu(idx_M) / Ms;
				cuReal3 dxx_m = M.dxx_neu(idx_M) / Ms;
				cuReal3 dyy_m = M.dyy_neu(idx_M) / Ms;

				cuReal3 B_the = cuReal3(
					((dxy_m ^ dy_m) + (dx_m ^ dyy_m)) * m,
					-1.0 * ((dxx_m ^ dy_m) + (dx_m ^ dxy_m)) * m,
					0.0);

				value -= (pcuaMesh->pthe_eff->get0() * P * elC[idx] * (cuBReal)HBAR_E / ((cuBReal)ECHARGE * n_density)) * (grad_V * B_the);
			}
			*/
		}

		//additional fixed contributions if needed (e.g. CPP-GMR and charge pumping)
		if (pdelsq_V_fixed->linear_size()) value += (*pdelsq_V_fixed)[idx];

		return value;
	}

	//boundary differential of V for non-homogeneous Neumann boundary conditions
	__device__ cuVAL3<cuBReal> bdiff(int idx)
	{
		return cuReal3();
	}

	//Functions used for calculating CMBND values

	//CMBND for V
	//flux = a + b V' at the interface, b = -sigma, a = betaD * (De*e/muB) * (grad S)m + (SHA*De*e/muB) * curl S + charge pumping + topological Hall effect
	//Note, the topological Hall effect term includes E, thus gradients in V, but we can include these in the a term for 2 reasons:
	//1. these CMBND functions especially with the topological Hall effect enabled is used for interfaces along z direction normally, and here Ez is zero 
	//(for such interfaces both charge pumping and topological Hall effect have zero contribution to z direction charge current)
	//2. even if the interface is along x or y we can still use the previously calculated E field, and the solution will converge to the same value (but might take more iterations).
	__device__ cuBReal a_func_pri(int cell1_idx, int cell2_idx, cuReal3 shift)
	{
		cuVEC_VC<cuReal3>& S = *pcuaMesh->pS;
		cuVEC_VC<cuBReal>& V = *pcuaMesh->pV;
		cuVEC_VC<cuBReal>& elC = *pcuaMesh->pelC;
		cuVEC_VC<cuReal3>& M1 = *pcuaMesh->pM1;

		cuBReal a = 0.0;

		cuReal3 u = shift.normalized() * -1;

		//TO DO

		/*

		bool cppgmr_enabled = cuIsNZ(pcuaMesh->pbetaD->get0());
		bool cpump_enabled = cuIsNZ(pcuaMesh->pcpump_eff->get0()) && cuIsZ(shift.z);
		bool the_enabled = cuIsNZ(pcuaMesh->pthe_eff->get0()) && cuIsZ(shift.z);

		if (stsolve == STSOLVE_FERROMAGNETIC && (cppgmr_enabled || cpump_enabled || the_enabled)) {

			//magnetic mesh

			cuBReal Ms = *pcuaMesh->pMs;
			pcuaMesh->update_parameters_ecoarse(cell1_idx, *pcuaMesh->pMs, Ms);

			int idx_M1 = M.position_to_cellidx(V.cellidx_to_position(cell1_idx));
			int idx_M2 = M.position_to_cellidx(V.cellidx_to_position(cell2_idx));

			cuReal3 m1 = M[idx_M1] / Ms;
			cuReal3 m2 = M[idx_M2] / Ms;

			//1. CPP-GMR contribution
			if (cppgmr_enabled) {

				cuBReal betaD = *pcuaMesh->pbetaD;
				cuBReal De = *pcuaMesh->pDe;
				pcuaMesh->update_parameters_ecoarse(cell1_idx, *pcuaMesh->pbetaD, betaD, *pcuaMesh->pDe, De);

				//value a1
				cuReal33 grad_S1 = S.grad_neu(cell1_idx);

				cuBReal a1 = ((grad_S1 * m1) * betaD * De / (cuBReal)MUB_E) * u;

				//value a2
				cuReal33 grad_S2 = S.grad_neu(cell2_idx);

				cuBReal a2 = ((grad_S2 * m2) * betaD * De / (cuBReal)MUB_E) * u;

				//final interpolated a value
				a += (1.5 * a1 - 0.5 * a2);
			}

			//2. Charge pumping
			//3. Topological Hall effect
			if (cpump_enabled || the_enabled) {

				cuBReal P = *pcuaMesh->pP;
				cuBReal n_density = *pcuaMesh->pn_density;
				pcuaMesh->update_parameters_ecoarse(cell1_idx, *pcuaMesh->pP, P, *pcuaMesh->pn_density, n_density);

				cuReal33 grad_m1 = M.grad_neu(idx_M1) / Ms;
				cuReal33 grad_m2 = M.grad_neu(idx_M2) / Ms;

				//do not read off the E field directly as it's only calculated after the spin solver (charge part) has relaxed
				cuReal3 E1 = -1.0 * V.grad_diri(cell1_idx);
				cuReal3 E2 = -1.0 * V.grad_diri(cell2_idx);

				cuBReal sigma_1 = elC[cell1_idx];
				cuBReal sigma_2 = elC[cell2_idx];

				//topological Hall effect contribution
				if (the_enabled) {

					//value a1
					cuBReal Bz_the_1 = (grad_m1.x ^ grad_m1.y) * m1;
					cuBReal a1 = pcuaMesh->pthe_eff->get0() * (-P * sigma_1 * sigma_1 * (cuBReal)HBAR_E / ((cuBReal)ECHARGE * n_density)) * cuReal3(E1.y * Bz_the_1, -E1.x * Bz_the_1, 0.0) * u;

					//value a2
					cuBReal Bz_the_2 = (grad_m2.x ^ grad_m2.y) * m2;
					cuBReal a2 = pcuaMesh->pthe_eff->get0() * (-P * sigma_2 * sigma_2 * (cuBReal)HBAR_E / ((cuBReal)ECHARGE * n_density)) * cuReal3(E1.y * Bz_the_1, -E1.x * Bz_the_1, 0.0) * u;

					//final interpolated a value
					a += (1.5 * a1 - 0.5 * a2);
				}

				//charge pumping contribution
				if (cpump_enabled) {

					//value a1
					cuReal3 dm_dt_1 = (*pdM_dt)[idx_M1] / Ms;
					cuBReal a1 = pcuaMesh->pcpump_eff->get0() * (P * sigma_1 * (cuBReal)HBAR_E / 2) * cuReal3((dm_dt_1 ^ grad_m1.x) * m1, (dm_dt_1 ^ grad_m1.y) * m1, 0.0) * u;

					//value a2
					cuReal3 dm_dt_2 = (*pdM_dt)[idx_M2] / Ms;
					cuBReal a2 = pcuaMesh->pcpump_eff->get0() * (P * sigma_2 * (cuBReal)HBAR_E / 2) * cuReal3((dm_dt_2 ^ grad_m2.x) * m2, (dm_dt_2 ^ grad_m2.y) * m2, 0.0) * u;

					//final interpolated a value
					a += (1.5 * a1 - 0.5 * a2);
				}
			}
		}
		*/
		return a;
	}

	//CMBND for V
	//flux = a + b V' at the interface, b = -sigma, a = betaD * (De*e/muB) * (grad S)m + (SHA*De*e/muB) * curl S + charge pumping + topological Hall effect
	//Note, the topological Hall effect term includes E, thus gradients in V, but we can include these in the a term for 2 reasons:
	//1. these CMBND functions especially with the topological Hall effect enabled is used for interfaces along z direction normally, and here Ez is zero 
	//(for such interfaces both charge pumping and topological Hall effect have zero contribution to z direction charge current)
	//2. even if the interface is along x or y we can still use the previously calculated E field, and the solution will converge to the same value (but might take more iterations).
	__device__ cuBReal a_func_sec(cuReal3 relpos_m1, cuReal3 shift, cuReal3 stencil)
	{
		cuVEC_VC<cuReal3>& S = *pcuaMesh->pS;
		cuVEC_VC<cuBReal>& V = *pcuaMesh->pV;
		cuVEC_VC<cuBReal>& elC = *pcuaMesh->pelC;
		cuVEC_VC<cuReal3>& M1 = *pcuaMesh->pM1;

		cuBReal a = 0.0;

		cuReal3 u = shift.normalized() * -1;

		//TO DO

		/*

		bool cppgmr_enabled = cuIsNZ(pcuaMesh->pbetaD->get0());
		bool cpump_enabled = cuIsNZ(pcuaMesh->pcpump_eff->get0()) && cuIsZ(shift.z);
		bool the_enabled = cuIsNZ(pcuaMesh->pthe_eff->get0()) && cuIsZ(shift.z);

		if (stsolve == STSOLVE_FERROMAGNETIC && (cppgmr_enabled || cpump_enabled || the_enabled)) {

			//magnetic mesh

			cuBReal Ms = *pcuaMesh->pMs;
			pcuaMesh->update_parameters_atposition(relpos_m1, *pcuaMesh->pMs, Ms);

			cuReal3 m1 = M.weighted_average(relpos_m1, stencil) / Ms;
			cuReal3 m2 = M.weighted_average(relpos_m1 + shift, stencil) / Ms;

			//1. CPP-GMR contribution
			if (cppgmr_enabled) {

				cuBReal betaD = *pcuaMesh->pbetaD;
				cuBReal De = *pcuaMesh->pDe;
				pcuaMesh->update_parameters_atposition(relpos_m1, *pcuaMesh->pbetaD, betaD, *pcuaMesh->pDe, De);

				int idx_S1 = S.position_to_cellidx(relpos_m1);
				int idx_S2 = S.position_to_cellidx(relpos_m1 + shift);

				//value a1
				cuReal33 grad_S1 = S.grad_neu(idx_S1);

				cuBReal a1 = ((grad_S1 * m1) * betaD * De / (cuBReal)MUB_E) * u;

				//value a2
				cuReal33 grad_S2 = S.grad_neu(idx_S2);

				cuBReal a2 = ((grad_S2 * m2) * betaD * De / (cuBReal)MUB_E) * u;

				//final interpolated a value
				a += (1.5 * a1 - 0.5 * a2);
			}

			//2. Charge pumping
			//3. Topological Hall effect
			if (cpump_enabled || the_enabled) {

				cuBReal P = *pcuaMesh->pP;
				cuBReal n_density = *pcuaMesh->pn_density;
				pcuaMesh->update_parameters_atposition(relpos_m1, *pcuaMesh->pP, P, *pcuaMesh->pn_density, n_density);

				int idx_M1 = M.position_to_cellidx(relpos_m1);
				int idx_M2 = M.position_to_cellidx(relpos_m1 + shift);

				cuReal33 grad_m1 = M.grad_neu(idx_M1) / Ms;
				cuReal33 grad_m2 = M.grad_neu(idx_M2) / Ms;

				int idx_V1 = V.position_to_cellidx(relpos_m1);
				//do not read off the E field directly as it's only calculated after the spin solver (charge part) has relaxed
				cuReal3 E1 = -1.0 * V.grad_diri(idx_V1);

				int idx_V2 = V.position_to_cellidx(relpos_m1 + shift);
				cuReal3 E2 = -1.0 * V.grad_diri(idx_V2);

				cuBReal sigma_1 = elC.weighted_average(relpos_m1, stencil);
				cuBReal sigma_2 = elC.weighted_average(relpos_m1 + shift, stencil);

				//topological Hall effect contribution
				if (the_enabled) {

					//value a1
					cuBReal Bz_the_1 = (grad_m1.x ^ grad_m1.y) * m1;
					cuBReal a1 = pcuaMesh->pthe_eff->get0() * (-P * sigma_1 * sigma_1 * (cuBReal)HBAR_E / ((cuBReal)ECHARGE * n_density)) * cuReal3(E1.y * Bz_the_1, -E1.x * Bz_the_1, 0.0) * u;

					//value a2
					cuBReal Bz_the_2 = (grad_m2.x ^ grad_m2.y) * m2;
					cuBReal a2 = pcuaMesh->pthe_eff->get0() * (-P * sigma_2 * sigma_2 * (cuBReal)HBAR_E / ((cuBReal)ECHARGE * n_density)) * cuReal3(E1.y * Bz_the_1, -E1.x * Bz_the_1, 0.0) * u;

					//final interpolated a value
					a += (1.5 * a1 - 0.5 * a2);
				}

				//charge pumping contribution
				if (cpump_enabled) {

					//value a1
					cuReal3 dm_dt_1 = pdM_dt->weighted_average(relpos_m1, stencil) / Ms;
					cuBReal a1 = pcuaMesh->pcpump_eff->get0() * (P * sigma_1 * (cuBReal)HBAR_E / 2) * cuReal3((dm_dt_1 ^ grad_m1.x) * m1, (dm_dt_1 ^ grad_m1.y) * m1, 0.0) * u;

					//value a2
					cuReal3 dm_dt_2 = pdM_dt->weighted_average(relpos_m1 + shift, stencil) / Ms;
					cuBReal a2 = pcuaMesh->pcpump_eff->get0() * (P * sigma_2 * (cuBReal)HBAR_E / 2) * cuReal3((dm_dt_2 ^ grad_m2.x) * m2, (dm_dt_2 ^ grad_m2.y) * m2, 0.0) * u;

					//final interpolated a value
					a += (1.5 * a1 - 0.5 * a2);
				}
			}
		}

		*/

		return a;
	}

	__device__ cuBReal b_func_pri(int cell1_idx, int cell2_idx)
	{
		cuVEC_VC<cuBReal>& elC = *pcuaMesh->pelC;

		return (-1.5 * elC[cell1_idx] + 0.5 * elC[cell2_idx]);
	}

	__device__ cuBReal b_func_sec(cuReal3 relpos_m1, cuReal3 shift, cuReal3 stencil)
	{
		cuVEC_VC<cuBReal>& elC = *pcuaMesh->pelC;

		return (-1.5 * elC.weighted_average(relpos_m1, stencil) + 0.5 * elC.weighted_average(relpos_m1 + shift, stencil));
	}

	//second order differential of V along the shift axis
	//this is simply Evaluate_SpinSolver_delsqV_RHS from which we subtract second order differentials orthogonal to the shift axis
	__device__ cuBReal diff2_pri(int cell1_idx, cuReal3 shift)
	{
		return Poisson_RHS(cell1_idx);
	}

	//second order differential of V along the shift axis
	//this is simply Evaluate_SpinSolver_delsqV_RHS from which we subtract second order differentials orthogonal to the shift axis
	__device__ cuBReal diff2_sec(cuReal3 relpos_m1, cuReal3 stencil, cuReal3 shift)
	{
		cuVEC_VC<cuBReal>& V = *pcuaMesh->pV;

		int cellm1_idx = V.position_to_cellidx(relpos_m1);

		return Poisson_RHS(cellm1_idx);
	}
};

#endif

#endif
