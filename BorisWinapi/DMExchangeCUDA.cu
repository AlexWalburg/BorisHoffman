#include "DMExchangeCUDA.h"

#if COMPILECUDA == 1

#ifdef MODULE_DMEXCHANGE

#include "BorisCUDALib.cuh"

#include "MeshCUDA.h"
#include "MeshParamsControlCUDA.h"
#include "MeshDefs.h"

__global__ void DMExchangeCUDA_FM_UpdateField(ManagedMeshCUDA& cuMesh, cuBReal& energy, bool do_reduction)
{
	cuVEC_VC<cuReal3>& M = *cuMesh.pM;
	cuVEC<cuReal3>& Heff = *cuMesh.pHeff;

	int idx = blockIdx.x * blockDim.x + threadIdx.x;

	cuBReal energy_ = 0.0;

	if (idx < Heff.linear_size()) {

		cuReal3 Hexch = cuReal3();

		if (M.is_not_empty(idx)) {

			cuBReal Ms = *cuMesh.pMs;
			cuBReal A = *cuMesh.pA;
			cuBReal D = *cuMesh.pD;
			cuMesh.update_parameters_mcoarse(idx, *cuMesh.pMs, Ms, *cuMesh.pA, A, *cuMesh.pD, D);

			if (M.is_interior(idx)) {

				//interior point : can use cheaper neu versions

				//direct exchange contribution
				Hexch = 2 * A * M.delsq_neu(idx) / ((cuBReal)MU0 * Ms * Ms);

				//Dzyaloshinskii-Moriya exchange contribution

				//Hdm, ex = -2D / (mu0*Ms) * curl m
				Hexch += -2 * D * M.curl_neu(idx) / ((cuBReal)MU0 * Ms * Ms);
			}
			else {

				//Non-homogeneous Neumann boundary conditions apply when using DMI. Required to ensure Brown's condition is fulfilled, i.e. m x h -> 0 when relaxing.
				cuReal3 bnd_dm_dx = (D / (2 * A)) * cuReal3(0, -M[idx].z, M[idx].y);
				cuReal3 bnd_dm_dy = (D / (2 * A)) * cuReal3(M[idx].z, 0, -M[idx].x);
				cuReal3 bnd_dm_dz = (D / (2 * A)) * cuReal3(-M[idx].y, M[idx].x, 0);
				cuReal33 bnd_nneu = cuReal33(bnd_dm_dx, bnd_dm_dy, bnd_dm_dz);

				//direct exchange contribution
				Hexch = 2 * A * M.delsq_nneu(idx, bnd_nneu) / ((cuBReal)MU0 * Ms * Ms);

				//Dzyaloshinskii-Moriya exchange contribution

				//Hdm, ex = -2D / (mu0*Ms) * curl m
				Hexch += -2 * D * M.curl_nneu(idx, bnd_nneu) / ((cuBReal)MU0 * Ms * Ms);
			}

			if (do_reduction) {

				int non_empty_cells = M.get_nonempty_cells();
				if (non_empty_cells) energy_ = -(cuBReal)MU0 * M[idx] * Hexch / (2 * non_empty_cells);
			}
		}

		Heff[idx] += Hexch;
	}

	if (do_reduction) reduction_sum(0, 1, &energy_, energy);
}

__global__ void DMExchangeCUDA_AFM_UpdateField(ManagedMeshCUDA& cuMesh, cuBReal& energy, bool do_reduction)
{
	cuVEC_VC<cuReal3>& M = *cuMesh.pM;
	cuVEC<cuReal3>& Heff = *cuMesh.pHeff;

	cuVEC_VC<cuReal3>& M2 = *cuMesh.pM2;
	cuVEC<cuReal3>& Heff2 = *cuMesh.pHeff2;

	int idx = blockIdx.x * blockDim.x + threadIdx.x;

	cuBReal energy_ = 0.0;

	if (idx < Heff.linear_size()) {

		cuReal3 Hexch = cuReal3();
		cuReal3 Hexch2 = cuReal3();

		if (M.is_not_empty(idx)) {

			cuReal2 Ms_AFM = *cuMesh.pMs_AFM;
			cuReal2 A_AFM = *cuMesh.pA_AFM;
			cuReal2 Ah = *cuMesh.pAh;
			cuReal2 Anh = *cuMesh.pAnh;
			cuReal2 D_AFM = *cuMesh.pD_AFM;
			cuMesh.update_parameters_mcoarse(idx, *cuMesh.pMs_AFM, Ms_AFM, *cuMesh.pA_AFM, A_AFM, *cuMesh.pAh, Ah, *cuMesh.pAnh, Anh, *cuMesh.pD_AFM, D_AFM);

			if (M.is_interior(idx)) {

				//interior point : can use cheaper neu versions

				//1. direct exchange contribution + AFM contribution
				cuReal3 delsq_M_A = M.delsq_neu(idx);
				cuReal3 delsq_M_B = M2.delsq_neu(idx);

				cuReal2 Mmag = cuReal2(M[idx].norm(), M2[idx].norm());

				Hexch = 2 * A_AFM.i * delsq_M_A / ((cuBReal)MU0 * Ms_AFM.i * Ms_AFM.i) + (-4 * Ah.i * (M[idx] ^ (M[idx] ^ M2[idx])) / (Mmag.i*Mmag.i) + Anh.i * delsq_M_B) / ((cuBReal)MU0*Ms_AFM.i*Ms_AFM.j);
				Hexch2 = 2 * A_AFM.j * delsq_M_B / ((cuBReal)MU0 * Ms_AFM.j * Ms_AFM.j) + (-4 * Ah.j * (M2[idx] ^ (M2[idx] ^ M[idx])) / (Mmag.j*Mmag.j) + Anh.j * delsq_M_A) / ((cuBReal)MU0*Ms_AFM.i*Ms_AFM.j);

				//Dzyaloshinskii-Moriya exchange contribution

				//Hdm, ex = -2D / (mu0*Ms) * curl m
				Hexch += -2 * D_AFM.i * M.curl_neu(idx) / ((cuBReal)MU0 * Ms_AFM.i * Ms_AFM.i);
				Hexch2 += -2 * D_AFM.j * M2.curl_neu(idx) / ((cuBReal)MU0 * Ms_AFM.j * Ms_AFM.j);
			}
			else {

				//Non-homogeneous Neumann boundary conditions apply when using DMI. Required to ensure Brown's condition is fulfilled, i.e. m x h -> 0 when relaxing.
				cuReal3 bnd_dm_dx = (D_AFM.i / (2 * A_AFM.i)) * cuReal3(0, -M[idx].z, M[idx].y);
				cuReal3 bnd_dm_dy = (D_AFM.i / (2 * A_AFM.i)) * cuReal3(M[idx].z, 0, -M[idx].x);
				cuReal3 bnd_dm_dz = (D_AFM.i / (2 * A_AFM.i)) * cuReal3(-M[idx].y, M[idx].x, 0);
				cuReal33 bndA_nneu = cuReal33(bnd_dm_dx, bnd_dm_dy, bnd_dm_dz);

				bnd_dm_dx = (D_AFM.j / (2 * A_AFM.j)) * cuReal3(0, -M2[idx].z, M2[idx].y);
				bnd_dm_dy = (D_AFM.j / (2 * A_AFM.j)) * cuReal3(M2[idx].z, 0, -M2[idx].x);
				bnd_dm_dz = (D_AFM.j / (2 * A_AFM.j)) * cuReal3(-M2[idx].y, M2[idx].x, 0);
				cuReal33 bndB_nneu = cuReal33(bnd_dm_dx, bnd_dm_dy, bnd_dm_dz);

				cuReal3 delsq_M_A = M.delsq_nneu(idx, bndA_nneu);
				cuReal3 delsq_M_B = M2.delsq_nneu(idx, bndB_nneu);

				cuReal2 Mmag = cuReal2(M[idx].norm(), M2[idx].norm());

				//1. direct exchange contribution + AFM contribution

				//cells marked with cmbnd are calculated using exchange coupling to other ferromagnetic meshes - see below; the delsq_nneu evaluates to zero in the CMBND coupling direction.
				Hexch = 2 * A_AFM.i * delsq_M_A / ((cuBReal)MU0 * Ms_AFM.i * Ms_AFM.i) + (-4 * Ah.i * (M[idx] ^ (M[idx] ^ M2[idx])) / (Mmag.i*Mmag.i) + Anh.i * delsq_M_B) / ((cuBReal)MU0*Ms_AFM.i*Ms_AFM.j);
				Hexch2 = 2 * A_AFM.j * delsq_M_B / ((cuBReal)MU0 * Ms_AFM.j * Ms_AFM.j) + (-4 * Ah.j * (M2[idx] ^ (M2[idx] ^ M[idx])) / (Mmag.j*Mmag.j) + Anh.j * delsq_M_A) / ((cuBReal)MU0*Ms_AFM.i*Ms_AFM.j);

				//2. Dzyaloshinskii-Moriya exchange contribution

				//Hdm, ex = -2D / (mu0*Ms) * curl m
				//For cmbnd cells curl_nneu does not evaluate to zero in the CMBND coupling direction, but sided differentials are used - when setting values at CMBND cells for exchange coupled meshes must correct for this.
				Hexch += -2 * D_AFM.i * M.curl_nneu(idx, bndA_nneu) / ((cuBReal)MU0 * Ms_AFM.i * Ms_AFM.i);
				Hexch2 += -2 * D_AFM.j * M2.curl_nneu(idx, bndB_nneu) / ((cuBReal)MU0 * Ms_AFM.j * Ms_AFM.j);
			}

			if (do_reduction) {

				int non_empty_cells = M.get_nonempty_cells();
				if (non_empty_cells) energy_ = -(cuBReal)MU0 * (M[idx] * Hexch + M2[idx] * Hexch2) / (4 * non_empty_cells);
			}
		}

		Heff[idx] += Hexch;
		Heff2[idx] += Hexch2;
	}

	if (do_reduction) reduction_sum(0, 1, &energy_, energy);
}

//----------------------- UpdateField LAUNCHER

void DMExchangeCUDA::UpdateField(void)
{

	if (pMeshCUDA->GetMeshType() == MESH_ANTIFERROMAGNETIC) {

		//anti-ferromagnetic mesh

		if (pMeshCUDA->CurrentTimeStepSolved()) {

			ZeroEnergy();

			DMExchangeCUDA_AFM_UpdateField << < (pMeshCUDA->n.dim() + CUDATHREADS) / CUDATHREADS, CUDATHREADS >> > (pMeshCUDA->cuMesh, energy, true);
		}
		else {

			DMExchangeCUDA_AFM_UpdateField << < (pMeshCUDA->n.dim() + CUDATHREADS) / CUDATHREADS, CUDATHREADS >> > (pMeshCUDA->cuMesh, energy, false);
		}
	}
	else {

		//ferromagnetic mesh

		if (pMeshCUDA->CurrentTimeStepSolved()) {

			ZeroEnergy();

			DMExchangeCUDA_FM_UpdateField << < (pMeshCUDA->n.dim() + CUDATHREADS) / CUDATHREADS, CUDATHREADS >> > (pMeshCUDA->cuMesh, energy, true);
		}
		else {

			DMExchangeCUDA_FM_UpdateField << < (pMeshCUDA->n.dim() + CUDATHREADS) / CUDATHREADS, CUDATHREADS >> > (pMeshCUDA->cuMesh, energy, false);
		}
	}

	if (pMeshCUDA->GetMeshExchangeCoupling()) CalculateExchangeCoupling(energy);
}

#endif

#endif