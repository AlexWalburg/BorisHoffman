#include "DiffEqCUDA.h"
#include "MeshParamsControlCUDA.h"

#if COMPILECUDA == 1
#ifdef ODE_EVAL_EULER

//defines evaluation methods kernel launchers

#include "BorisCUDALib.cuh"

//----------------------------------------- EVALUATIONS: Euler

__global__ void RunEuler_Kernel_withReductions(ManagedDiffEqCUDA& cuDiffEq, ManagedMeshCUDA& cuMesh)
{
	int idx = blockIdx.x * blockDim.x + threadIdx.x;

	cuReal dT = *cuDiffEq.pdT;

	cuReal3 mxh = cuReal3();
	cuReal3 dmdt = cuReal3();

	if (idx < cuMesh.pM->linear_size()) {

		if (cuMesh.pM->is_not_empty(idx)) {

			//Save current magnetization
			(*cuDiffEq.psM1)[idx] = (*cuMesh.pM)[idx];

			if (!cuMesh.pM->is_skipcell(idx)) {

				//obtain average normalized torque term
				cuReal Mnorm = (*cuMesh.pM)[idx].norm();
				
				if (cuDiffEq.pH_Thermal->linear_size()) {

					mxh = ((*cuMesh.pM)[idx] ^ ((*cuMesh.pHeff)[idx] + (*cuDiffEq.pH_Thermal)[idx])) / (Mnorm * Mnorm);
				}
				else mxh = ((*cuMesh.pM)[idx] ^ (*cuMesh.pHeff)[idx]) / (Mnorm * Mnorm);

				//First evaluate RHS of set equation at the current time step
				cuReal3 rhs = (cuDiffEq.*(cuDiffEq.pODEFunc))(idx);

				//Now estimate magnetization for the next time step
				(*cuMesh.pM)[idx] += rhs * dT;

				if (*cuDiffEq.prenormalize) {

					cuReal Ms = *cuMesh.pMs;
					cuMesh.update_parameters_mcoarse(idx, *cuMesh.pMs, Ms);
					(*cuMesh.pM)[idx].renormalize(Ms);
				}

				//obtain maximum normalized dmdt term
				dmdt = ((*cuMesh.pM)[idx] - (*cuDiffEq.psM1)[idx]) / (dT * (cuReal)GAMMA * Mnorm * Mnorm);
			}
			else {

				cuReal Ms = *cuMesh.pMs;
				cuMesh.update_parameters_mcoarse(idx, *cuMesh.pMs, Ms);
				(*cuMesh.pM)[idx].renormalize(Ms);		//re-normalize the skipped cells no matter what - temperature can change
			}
		}
	}

	//only reduce for dmdt (and mxh) if grel is not zero (if it's zero this means magnetisation dynamics is disabled in this mesh)
	if (cuMesh.pgrel->get0()) {

		reduction_avg(0, 1, &mxh, *cuDiffEq.pmxh_av, *cuDiffEq.pavpoints);
		reduction_avg(0, 1, &dmdt, *cuDiffEq.pdmdt_av, *cuDiffEq.pavpoints2);
	}
}

__global__ void RunEuler_Kernel(ManagedDiffEqCUDA& cuDiffEq, ManagedMeshCUDA& cuMesh)
{
	int idx = blockIdx.x * blockDim.x + threadIdx.x;

	cuReal dT = *cuDiffEq.pdT;

	if (idx < cuMesh.pM->linear_size()) {

		if (cuMesh.pM->is_not_empty(idx)) {

			//Save current magnetization
			(*cuDiffEq.psM1)[idx] = (*cuMesh.pM)[idx];

			if (!cuMesh.pM->is_skipcell(idx)) {

				//First evaluate RHS of set equation at the current time step
				cuReal3 rhs = (cuDiffEq.*(cuDiffEq.pODEFunc))(idx);

				//Now estimate magnetization for the next time step
				(*cuMesh.pM)[idx] += rhs * dT;

				if (*cuDiffEq.prenormalize) {

					cuReal Ms = *cuMesh.pMs;
					cuMesh.update_parameters_mcoarse(idx, *cuMesh.pMs, Ms);
					(*cuMesh.pM)[idx].renormalize(Ms);
				}
			}
			else {

				cuReal Ms = *cuMesh.pMs;
				cuMesh.update_parameters_mcoarse(idx, *cuMesh.pMs, Ms);
				(*cuMesh.pM)[idx].renormalize(Ms);		//re-normalize the skipped cells no matter what - temperature can change
			}
		}
	}
}

//----------------------------------------- DifferentialEquationCUDA Launchers

//EULER

void DifferentialEquationCUDA::RunEuler(bool calculate_mxh, bool calculate_dmdt)
{
	if (calculate_mxh || calculate_dmdt) {

		RunEuler_Kernel_withReductions << < (pMeshCUDA->n.dim() + CUDATHREADS) / CUDATHREADS, CUDATHREADS >> > (cuDiffEq, pMeshCUDA->cuMesh);
	}
	else {

		RunEuler_Kernel << < (pMeshCUDA->n.dim() + CUDATHREADS) / CUDATHREADS, CUDATHREADS >> > (cuDiffEq, pMeshCUDA->cuMesh);
	}
}

#endif
#endif