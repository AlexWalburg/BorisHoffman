#include "iDMExchangeCUDA.h"

#if COMPILECUDA == 1

#ifdef MODULE_COMPILATION_IDMEXCHANGE

#include "BorisCUDALib.cuh"

#include "MeshCUDA.h"
#include "MeshParamsControlCUDA.h"
#include "MeshDefs.h"

//////////////////////////////////////////////////////////////////////// UPDATE FIELD

__global__ void iDMExchangeCUDA_FM_UpdateField(ManagedMeshCUDA& cuMesh, cuBReal& energy, bool do_reduction)
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

			if (M.is_plane_interior(idx)) {

				//interior point : can use cheaper neu versions

				//direct exchange contribution
				Hexch = 2 * A * M.delsq_neu(idx) / ((cuBReal)MU0 * Ms * Ms);

				//Dzyaloshinskii-Moriya interfacial exchange contribution

				//Differentials of M components (we only need 4, not all 9 so this could be optimised). First index is the differential direction, second index is the M component
				cuReal33 Mdiff = M.grad_neu(idx);

				//Hdm, ex = -2D / (mu0*Ms) * (dmz / dx, dmz / dy, -dmx / dx - dmy / dy)
				Hexch += -2 * D * cuReal3(Mdiff.x.z, Mdiff.y.z, -Mdiff.x.x - Mdiff.y.y) / ((cuBReal)MU0 * Ms * Ms);
			}
			else {

				//Non-homogeneous Neumann boundary conditions apply when using DMI. Required to ensure Brown's condition is fulfilled, i.e. m x h -> 0 when relaxing.
				cuReal3 bnd_dm_dx = (D / (2 * A)) * cuReal3(M[idx].z, 0, -M[idx].x);
				cuReal3 bnd_dm_dy = (D / (2 * A)) * cuReal3(0, M[idx].z, -M[idx].y);
				cuReal33 bnd_nneu = cuReal33(bnd_dm_dx, bnd_dm_dy, cuReal3());

				//direct exchange contribution
				Hexch = 2 * A * M.delsq_nneu(idx, bnd_nneu) / ((cuBReal)MU0 * Ms * Ms);

				//Dzyaloshinskii-Moriya interfacial exchange contribution

				//Differentials of M components (we only need 4, not all 9 so this could be optimised). First index is the differential direction, second index is the M component
				cuReal33 Mdiff = M.grad_nneu(idx, bnd_nneu);

				//Hdm, ex = -2D / (mu0*Ms) * (dmz / dx, dmz / dy, -dmx / dx - dmy / dy)
				Hexch += -2 * D * cuReal3(Mdiff.x.z, Mdiff.y.z, -Mdiff.x.x - Mdiff.y.y) / ((cuBReal)MU0 * Ms * Ms);
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

__global__ void iDMExchangeCUDA_AFM_UpdateField(ManagedMeshCUDA& cuMesh, cuBReal& energy, bool do_reduction)
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

			if (M.is_plane_interior(idx)) {

				//interior point : can use cheaper neu versions

				//1. direct exchange contribution + AFM contribution
				cuReal3 delsq_M_A = M.delsq_neu(idx);
				cuReal3 delsq_M_B = M2.delsq_neu(idx);

				cuReal2 Mmag = cuReal2(M[idx].norm(), M2[idx].norm());

				Hexch = 2 * A_AFM.i * delsq_M_A / ((cuBReal)MU0 * Ms_AFM.i * Ms_AFM.i) + (-4 * Ah.i * (M[idx] ^ (M[idx] ^ M2[idx])) / (Mmag.i*Mmag.i) + Anh.i * delsq_M_B) / ((cuBReal)MU0*Ms_AFM.i*Ms_AFM.j);
				Hexch2 = 2 * A_AFM.j * delsq_M_B / ((cuBReal)MU0 * Ms_AFM.j * Ms_AFM.j) + (-4 * Ah.j * (M2[idx] ^ (M2[idx] ^ M[idx])) / (Mmag.j*Mmag.j) + Anh.j * delsq_M_A) / ((cuBReal)MU0*Ms_AFM.i*Ms_AFM.j);

				//Dzyaloshinskii-Moriya interfacial exchange contribution

				//Differentials of M components (we only need 4, not all 9 so this could be optimised). First index is the differential direction, second index is the M component
				cuReal33 Mdiff = M.grad_neu(idx);

				//Hdm, ex = -2D / (mu0*Ms) * (dmz / dx, dmz / dy, -dmx / dx - dmy / dy)
				Hexch += -2 * D_AFM.i * cuReal3(Mdiff.x.z, Mdiff.y.z, -Mdiff.x.x - Mdiff.y.y) / ((cuBReal)MU0 * Ms_AFM.i * Ms_AFM.i);

				//same thing on sub-lattice B (2)

				Mdiff = M2.grad_neu(idx);
				Hexch2 += -2 * D_AFM.j * cuReal3(Mdiff.x.z, Mdiff.y.z, -Mdiff.x.x - Mdiff.y.y) / ((cuBReal)MU0 * Ms_AFM.j * Ms_AFM.j);
			}
			else {

				cuReal33 bndA_nneu, bndB_nneu;

				cuReal2 nhconst = Anh / (2 * A_AFM);

				if (fabs(nhconst.i) != 1.0) {

					//Non-homogeneous Neumann boundary conditions apply when using DMI. Required to ensure Brown's condition is fulfilled, i.e. m x h -> 0 when relaxing.
					cuReal3 bnd_dm_dx = (D_AFM.i / (2 * A_AFM.i * (1 - nhconst.i * nhconst.i))) * cuReal3(M[idx].z - nhconst.i * M2[idx].z, 0, -M[idx].x + nhconst.i * M2[idx].x);
					cuReal3 bnd_dm_dy = (D_AFM.i / (2 * A_AFM.i * (1 - nhconst.i * nhconst.i))) * cuReal3(0, M[idx].z - nhconst.i * M2[idx].z, -M[idx].y + nhconst.i * M2[idx].y);

					bndA_nneu = cuReal33(bnd_dm_dx, bnd_dm_dy, cuReal3());
				}
				else {

					cuReal3 bnd_dm_dx = (D_AFM.i / (4 * A_AFM.i)) * cuReal3(M[idx].z, 0, -M[idx].x);
					cuReal3 bnd_dm_dy = (D_AFM.i / (4 * A_AFM.i)) * cuReal3(0, M[idx].z, -M[idx].y);

					bndA_nneu = cuReal33(bnd_dm_dx, bnd_dm_dy, cuReal3());
				}

				if (fabs(nhconst.j) != 1.0) {

					cuReal3 bnd_dm_dx = (D_AFM.j / (2 * A_AFM.j * (1 - nhconst.j * nhconst.j))) * cuReal3(M2[idx].z - nhconst.j * M[idx].z, 0, -M2[idx].x + nhconst.j * M[idx].x);
					cuReal3 bnd_dm_dy = (D_AFM.j / (2 * A_AFM.j * (1 - nhconst.j * nhconst.j))) * cuReal3(0, M2[idx].z - nhconst.j * M[idx].z, -M2[idx].y + nhconst.j * M[idx].y);

					bndB_nneu = cuReal33(bnd_dm_dx, bnd_dm_dy, cuReal3());
				}
				else {

					cuReal3 bnd_dm_dx = (D_AFM.j / (4 * A_AFM.j)) * cuReal3(M2[idx].z, 0, -M2[idx].x);
					cuReal3 bnd_dm_dy = (D_AFM.j / (4 * A_AFM.j)) * cuReal3(0, M2[idx].z, -M2[idx].y);

					bndB_nneu = cuReal33(bnd_dm_dx, bnd_dm_dy, cuReal3());
				}

				cuReal3 delsq_M_A = M.delsq_nneu(idx, bndA_nneu);
				cuReal3 delsq_M_B = M2.delsq_nneu(idx, bndB_nneu);

				cuReal2 Mmag = cuReal2(M[idx].norm(), M2[idx].norm());

				//1. direct exchange contribution + AFM contribution

				//cells marked with cmbnd are calculated using exchange coupling to other ferromagnetic meshes - see below; the delsq_nneu evaluates to zero in the CMBND coupling direction.
				Hexch = 2 * A_AFM.i * delsq_M_A / ((cuBReal)MU0 * Ms_AFM.i * Ms_AFM.i) + (-4 * Ah.i * (M[idx] ^ (M[idx] ^ M2[idx])) / (Mmag.i*Mmag.i) + Anh.i * delsq_M_B) / ((cuBReal)MU0*Ms_AFM.i*Ms_AFM.j);
				Hexch2 = 2 * A_AFM.j * delsq_M_B / ((cuBReal)MU0 * Ms_AFM.j * Ms_AFM.j) + (-4 * Ah.j * (M2[idx] ^ (M2[idx] ^ M[idx])) / (Mmag.j*Mmag.j) + Anh.j * delsq_M_A) / ((cuBReal)MU0*Ms_AFM.i*Ms_AFM.j);

				//2. Dzyaloshinskii-Moriya interfacial exchange contribution

				//Differentials of M components (we only need 4, not all 9 so this could be optimised). First index is the differential direction, second index is the M component
				//For cmbnd cells grad_nneu does not evaluate to zero in the CMBND coupling direction, but sided differentials are used - when setting values at CMBND cells for exchange coupled meshes must correct for this.
				cuReal33 Mdiff_A = M.grad_nneu(idx, bndA_nneu);
				cuReal33 Mdiff_B = M2.grad_nneu(idx, bndB_nneu);

				//Hdm, ex = -2D / (mu0*Ms) * (dmz / dx, dmz / dy, -dmx / dx - dmy / dy)
				Hexch += -2 * D_AFM.i * cuReal3(Mdiff_A.x.z, Mdiff_A.y.z, -Mdiff_A.x.x - Mdiff_A.y.y) / ((cuBReal)MU0 * Ms_AFM.i * Ms_AFM.i);
				Hexch2 += -2 * D_AFM.j * cuReal3(Mdiff_B.x.z, Mdiff_B.y.z, -Mdiff_B.x.x - Mdiff_B.y.y) / ((cuBReal)MU0 * Ms_AFM.j * Ms_AFM.j);
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

void iDMExchangeCUDA::UpdateField(void)
{
	if (pMeshCUDA->GetMeshType() == MESH_ANTIFERROMAGNETIC) {

		//anti-ferromagnetic mesh

		if (pMeshCUDA->CurrentTimeStepSolved()) {

			ZeroEnergy();

			iDMExchangeCUDA_AFM_UpdateField << < (pMeshCUDA->n.dim() + CUDATHREADS) / CUDATHREADS, CUDATHREADS >> > (pMeshCUDA->cuMesh, energy, true);
		}
		else {

			iDMExchangeCUDA_AFM_UpdateField << < (pMeshCUDA->n.dim() + CUDATHREADS) / CUDATHREADS, CUDATHREADS >> > (pMeshCUDA->cuMesh, energy, false);
		}
	}
	else {

		//ferromagnetic mesh

		if (pMeshCUDA->CurrentTimeStepSolved()) {

			ZeroEnergy();

			iDMExchangeCUDA_FM_UpdateField << < (pMeshCUDA->n.dim() + CUDATHREADS) / CUDATHREADS, CUDATHREADS >> > (pMeshCUDA->cuMesh, energy, true);
		}
		else {

			iDMExchangeCUDA_FM_UpdateField << < (pMeshCUDA->n.dim() + CUDATHREADS) / CUDATHREADS, CUDATHREADS >> > (pMeshCUDA->cuMesh, energy, false);
		}
	}

	if (pMeshCUDA->GetMeshExchangeCoupling()) CalculateExchangeCoupling(energy);
}

//////////////////////////////////////////////////////////////////////// ENERGY DENSITY DATA METHODS

__global__ void iDMExchangeCUDA_FM_GetEnergy(ManagedMeshCUDA& cuMesh, cuBReal& energy, size_t& points_count, cuRect avRect)
{
	cuVEC_VC<cuReal3>& M = *cuMesh.pM;

	int idx = blockIdx.x * blockDim.x + threadIdx.x;

	cuBReal energy_ = 0.0;

	bool include_in_reduction = false;

	if (idx < M.linear_size()) {

		cuReal3 Hexch = cuReal3();

		if (M.is_not_empty(idx) && avRect.contains(M.cellidx_to_position(idx))) {

			cuBReal Ms = *cuMesh.pMs;
			cuBReal A = *cuMesh.pA;
			cuBReal D = *cuMesh.pD;
			cuMesh.update_parameters_mcoarse(idx, *cuMesh.pMs, Ms, *cuMesh.pA, A, *cuMesh.pD, D);

			if (M.is_plane_interior(idx)) {

				//interior point : can use cheaper neu versions

				//direct exchange contribution
				Hexch = 2 * A * M.delsq_neu(idx) / ((cuBReal)MU0 * Ms * Ms);

				//Dzyaloshinskii-Moriya interfacial exchange contribution

				//Differentials of M components (we only need 4, not all 9 so this could be optimised). First index is the differential direction, second index is the M component
				cuReal33 Mdiff = M.grad_neu(idx);

				//Hdm, ex = -2D / (mu0*Ms) * (dmz / dx, dmz / dy, -dmx / dx - dmy / dy)
				Hexch += -2 * D * cuReal3(Mdiff.x.z, Mdiff.y.z, -Mdiff.x.x - Mdiff.y.y) / ((cuBReal)MU0 * Ms * Ms);
			}
			else {

				//Non-homogeneous Neumann boundary conditions apply when using DMI. Required to ensure Brown's condition is fulfilled, i.e. m x h -> 0 when relaxing.
				cuReal3 bnd_dm_dx = (D / (2 * A)) * cuReal3(M[idx].z, 0, -M[idx].x);
				cuReal3 bnd_dm_dy = (D / (2 * A)) * cuReal3(0, M[idx].z, -M[idx].y);
				cuReal33 bnd_nneu = cuReal33(bnd_dm_dx, bnd_dm_dy, cuReal3());

				//direct exchange contribution
				Hexch = 2 * A * M.delsq_nneu(idx, bnd_nneu) / ((cuBReal)MU0 * Ms * Ms);

				//Dzyaloshinskii-Moriya interfacial exchange contribution

				//Differentials of M components (we only need 4, not all 9 so this could be optimised). First index is the differential direction, second index is the M component
				cuReal33 Mdiff = M.grad_nneu(idx, bnd_nneu);

				//Hdm, ex = -2D / (mu0*Ms) * (dmz / dx, dmz / dy, -dmx / dx - dmy / dy)
				Hexch += -2 * D * cuReal3(Mdiff.x.z, Mdiff.y.z, -Mdiff.x.x - Mdiff.y.y) / ((cuBReal)MU0 * Ms * Ms);
			}

			energy_ = -(cuBReal)MU0 * M[idx] * Hexch / 2;
			include_in_reduction = true;
		}
	}

	reduction_avg(0, 1, &energy_, energy, points_count, include_in_reduction);
}

__global__ void iDMExchangeCUDA_AFM_GetEnergy(ManagedMeshCUDA& cuMesh, cuBReal& energy, size_t& points_count, cuRect avRect)
{
	cuVEC_VC<cuReal3>& M = *cuMesh.pM;
	cuVEC_VC<cuReal3>& M2 = *cuMesh.pM2;

	int idx = blockIdx.x * blockDim.x + threadIdx.x;

	cuBReal energy_ = 0.0;

	bool include_in_reduction = false;

	if (idx < M.linear_size()) {

		cuReal3 Hexch = cuReal3();
		cuReal3 Hexch2 = cuReal3();

		if (M.is_not_empty(idx) && avRect.contains(M.cellidx_to_position(idx))) {

			cuReal2 Ms_AFM = *cuMesh.pMs_AFM;
			cuReal2 A_AFM = *cuMesh.pA_AFM;
			cuReal2 Ah = *cuMesh.pAh;
			cuReal2 Anh = *cuMesh.pAnh;
			cuReal2 D_AFM = *cuMesh.pD_AFM;
			cuMesh.update_parameters_mcoarse(idx, *cuMesh.pMs_AFM, Ms_AFM, *cuMesh.pA_AFM, A_AFM, *cuMesh.pAh, Ah, *cuMesh.pAnh, Anh, *cuMesh.pD_AFM, D_AFM);

			if (M.is_plane_interior(idx)) {

				//interior point : can use cheaper neu versions

				//1. direct exchange contribution + AFM contribution
				cuReal3 delsq_M_A = M.delsq_neu(idx);
				cuReal3 delsq_M_B = M2.delsq_neu(idx);

				cuReal2 Mmag = cuReal2(M[idx].norm(), M2[idx].norm());

				Hexch = 2 * A_AFM.i * delsq_M_A / ((cuBReal)MU0 * Ms_AFM.i * Ms_AFM.i) + (-4 * Ah.i * (M[idx] ^ (M[idx] ^ M2[idx])) / (Mmag.i*Mmag.i) + Anh.i * delsq_M_B) / ((cuBReal)MU0*Ms_AFM.i*Ms_AFM.j);
				Hexch2 = 2 * A_AFM.j * delsq_M_B / ((cuBReal)MU0 * Ms_AFM.j * Ms_AFM.j) + (-4 * Ah.j * (M2[idx] ^ (M2[idx] ^ M[idx])) / (Mmag.j*Mmag.j) + Anh.j * delsq_M_A) / ((cuBReal)MU0*Ms_AFM.i*Ms_AFM.j);

				//Dzyaloshinskii-Moriya interfacial exchange contribution

				//Differentials of M components (we only need 4, not all 9 so this could be optimised). First index is the differential direction, second index is the M component
				cuReal33 Mdiff = M.grad_neu(idx);

				//Hdm, ex = -2D / (mu0*Ms) * (dmz / dx, dmz / dy, -dmx / dx - dmy / dy)
				Hexch += -2 * D_AFM.i * cuReal3(Mdiff.x.z, Mdiff.y.z, -Mdiff.x.x - Mdiff.y.y) / ((cuBReal)MU0 * Ms_AFM.i * Ms_AFM.i);

				//same thing on sub-lattice B (2)

				Mdiff = M2.grad_neu(idx);
				Hexch2 += -2 * D_AFM.j * cuReal3(Mdiff.x.z, Mdiff.y.z, -Mdiff.x.x - Mdiff.y.y) / ((cuBReal)MU0 * Ms_AFM.j * Ms_AFM.j);
			}
			else {

				cuReal33 bndA_nneu, bndB_nneu;

				cuReal2 nhconst = Anh / (2 * A_AFM);

				if (fabs(nhconst.i) != 1.0) {

					//Non-homogeneous Neumann boundary conditions apply when using DMI. Required to ensure Brown's condition is fulfilled, i.e. m x h -> 0 when relaxing.
					cuReal3 bnd_dm_dx = (D_AFM.i / (2 * A_AFM.i * (1 - nhconst.i * nhconst.i))) * cuReal3(M[idx].z - nhconst.i * M2[idx].z, 0, -M[idx].x + nhconst.i * M2[idx].x);
					cuReal3 bnd_dm_dy = (D_AFM.i / (2 * A_AFM.i * (1 - nhconst.i * nhconst.i))) * cuReal3(0, M[idx].z - nhconst.i * M2[idx].z, -M[idx].y + nhconst.i * M2[idx].y);

					bndA_nneu = cuReal33(bnd_dm_dx, bnd_dm_dy, cuReal3());
				}
				else {

					cuReal3 bnd_dm_dx = (D_AFM.i / (4 * A_AFM.i)) * cuReal3(M[idx].z, 0, -M[idx].x);
					cuReal3 bnd_dm_dy = (D_AFM.i / (4 * A_AFM.i)) * cuReal3(0, M[idx].z, -M[idx].y);

					bndA_nneu = cuReal33(bnd_dm_dx, bnd_dm_dy, cuReal3());
				}

				if (fabs(nhconst.j) != 1.0) {

					cuReal3 bnd_dm_dx = (D_AFM.j / (2 * A_AFM.j * (1 - nhconst.j * nhconst.j))) * cuReal3(M2[idx].z - nhconst.j * M[idx].z, 0, -M2[idx].x + nhconst.j * M[idx].x);
					cuReal3 bnd_dm_dy = (D_AFM.j / (2 * A_AFM.j * (1 - nhconst.j * nhconst.j))) * cuReal3(0, M2[idx].z - nhconst.j * M[idx].z, -M2[idx].y + nhconst.j * M[idx].y);

					bndB_nneu = cuReal33(bnd_dm_dx, bnd_dm_dy, cuReal3());
				}
				else {

					cuReal3 bnd_dm_dx = (D_AFM.j / (4 * A_AFM.j)) * cuReal3(M2[idx].z, 0, -M2[idx].x);
					cuReal3 bnd_dm_dy = (D_AFM.j / (4 * A_AFM.j)) * cuReal3(0, M2[idx].z, -M2[idx].y);

					bndB_nneu = cuReal33(bnd_dm_dx, bnd_dm_dy, cuReal3());
				}

				cuReal3 delsq_M_A = M.delsq_nneu(idx, bndA_nneu);
				cuReal3 delsq_M_B = M2.delsq_nneu(idx, bndB_nneu);

				cuReal2 Mmag = cuReal2(M[idx].norm(), M2[idx].norm());

				//1. direct exchange contribution + AFM contribution

				//cells marked with cmbnd are calculated using exchange coupling to other ferromagnetic meshes - see below; the delsq_nneu evaluates to zero in the CMBND coupling direction.
				Hexch = 2 * A_AFM.i * delsq_M_A / ((cuBReal)MU0 * Ms_AFM.i * Ms_AFM.i) + (-4 * Ah.i * (M[idx] ^ (M[idx] ^ M2[idx])) / (Mmag.i*Mmag.i) + Anh.i * delsq_M_B) / ((cuBReal)MU0*Ms_AFM.i*Ms_AFM.j);
				Hexch2 = 2 * A_AFM.j * delsq_M_B / ((cuBReal)MU0 * Ms_AFM.j * Ms_AFM.j) + (-4 * Ah.j * (M2[idx] ^ (M2[idx] ^ M[idx])) / (Mmag.j*Mmag.j) + Anh.j * delsq_M_A) / ((cuBReal)MU0*Ms_AFM.i*Ms_AFM.j);

				//2. Dzyaloshinskii-Moriya interfacial exchange contribution

				//Differentials of M components (we only need 4, not all 9 so this could be optimised). First index is the differential direction, second index is the M component
				//For cmbnd cells grad_nneu does not evaluate to zero in the CMBND coupling direction, but sided differentials are used - when setting values at CMBND cells for exchange coupled meshes must correct for this.
				cuReal33 Mdiff_A = M.grad_nneu(idx, bndA_nneu);
				cuReal33 Mdiff_B = M2.grad_nneu(idx, bndB_nneu);

				//Hdm, ex = -2D / (mu0*Ms) * (dmz / dx, dmz / dy, -dmx / dx - dmy / dy)
				Hexch += -2 * D_AFM.i * cuReal3(Mdiff_A.x.z, Mdiff_A.y.z, -Mdiff_A.x.x - Mdiff_A.y.y) / ((cuBReal)MU0 * Ms_AFM.i * Ms_AFM.i);
				Hexch2 += -2 * D_AFM.j * cuReal3(Mdiff_B.x.z, Mdiff_B.y.z, -Mdiff_B.x.x - Mdiff_B.y.y) / ((cuBReal)MU0 * Ms_AFM.j * Ms_AFM.j);
			}

			energy_ = -(cuBReal)MU0 * (M[idx] * Hexch + M2[idx] * Hexch2) / 4;
			include_in_reduction = true;
		}
	}

	reduction_avg(0, 1, &energy_, energy, points_count, include_in_reduction);
}

__global__ void iDMExchangeCUDA_FM_GetEnergy_Max(ManagedMeshCUDA& cuMesh, cuBReal& energy, cuRect rectangle)
{
	cuVEC_VC<cuReal3>& M = *cuMesh.pM;

	int idx = blockIdx.x * blockDim.x + threadIdx.x;

	cuBReal energy_ = 0.0;

	bool include_in_reduction = false;

	if (idx < M.linear_size()) {

		cuReal3 Hexch = cuReal3();

		if (M.is_not_empty(idx) && rectangle.contains(M.cellidx_to_position(idx))) {

			cuBReal Ms = *cuMesh.pMs;
			cuBReal A = *cuMesh.pA;
			cuBReal D = *cuMesh.pD;
			cuMesh.update_parameters_mcoarse(idx, *cuMesh.pMs, Ms, *cuMesh.pA, A, *cuMesh.pD, D);

			if (M.is_plane_interior(idx)) {

				//interior point : can use cheaper neu versions

				//direct exchange contribution
				Hexch = 2 * A * M.delsq_neu(idx) / ((cuBReal)MU0 * Ms * Ms);

				//Dzyaloshinskii-Moriya interfacial exchange contribution

				//Differentials of M components (we only need 4, not all 9 so this could be optimised). First index is the differential direction, second index is the M component
				cuReal33 Mdiff = M.grad_neu(idx);

				//Hdm, ex = -2D / (mu0*Ms) * (dmz / dx, dmz / dy, -dmx / dx - dmy / dy)
				Hexch += -2 * D * cuReal3(Mdiff.x.z, Mdiff.y.z, -Mdiff.x.x - Mdiff.y.y) / ((cuBReal)MU0 * Ms * Ms);
			}
			else {

				//Non-homogeneous Neumann boundary conditions apply when using DMI. Required to ensure Brown's condition is fulfilled, i.e. m x h -> 0 when relaxing.
				cuReal3 bnd_dm_dx = (D / (2 * A)) * cuReal3(M[idx].z, 0, -M[idx].x);
				cuReal3 bnd_dm_dy = (D / (2 * A)) * cuReal3(0, M[idx].z, -M[idx].y);
				cuReal33 bnd_nneu = cuReal33(bnd_dm_dx, bnd_dm_dy, cuReal3());

				//direct exchange contribution
				Hexch = 2 * A * M.delsq_nneu(idx, bnd_nneu) / ((cuBReal)MU0 * Ms * Ms);

				//Dzyaloshinskii-Moriya interfacial exchange contribution

				//Differentials of M components (we only need 4, not all 9 so this could be optimised). First index is the differential direction, second index is the M component
				cuReal33 Mdiff = M.grad_nneu(idx, bnd_nneu);

				//Hdm, ex = -2D / (mu0*Ms) * (dmz / dx, dmz / dy, -dmx / dx - dmy / dy)
				Hexch += -2 * D * cuReal3(Mdiff.x.z, Mdiff.y.z, -Mdiff.x.x - Mdiff.y.y) / ((cuBReal)MU0 * Ms * Ms);
			}

			energy_ = fabs((cuBReal)MU0 * M[idx] * Hexch / 2);
			include_in_reduction = true;
		}
	}

	reduction_max(0, 1, &energy_, energy, include_in_reduction);
}

__global__ void iDMExchangeCUDA_AFM_GetEnergy_Max(ManagedMeshCUDA& cuMesh, cuBReal& energy, cuRect rectangle)
{
	cuVEC_VC<cuReal3>& M = *cuMesh.pM;
	cuVEC_VC<cuReal3>& M2 = *cuMesh.pM2;

	int idx = blockIdx.x * blockDim.x + threadIdx.x;

	cuBReal energy_ = 0.0;

	bool include_in_reduction = false;

	if (idx < M.linear_size()) {

		cuReal3 Hexch = cuReal3();
		cuReal3 Hexch2 = cuReal3();

		if (M.is_not_empty(idx) && rectangle.contains(M.cellidx_to_position(idx))) {

			cuReal2 Ms_AFM = *cuMesh.pMs_AFM;
			cuReal2 A_AFM = *cuMesh.pA_AFM;
			cuReal2 Ah = *cuMesh.pAh;
			cuReal2 Anh = *cuMesh.pAnh;
			cuReal2 D_AFM = *cuMesh.pD_AFM;
			cuMesh.update_parameters_mcoarse(idx, *cuMesh.pMs_AFM, Ms_AFM, *cuMesh.pA_AFM, A_AFM, *cuMesh.pAh, Ah, *cuMesh.pAnh, Anh, *cuMesh.pD_AFM, D_AFM);

			if (M.is_plane_interior(idx)) {

				//interior point : can use cheaper neu versions

				//1. direct exchange contribution + AFM contribution
				cuReal3 delsq_M_A = M.delsq_neu(idx);
				cuReal3 delsq_M_B = M2.delsq_neu(idx);

				cuReal2 Mmag = cuReal2(M[idx].norm(), M2[idx].norm());

				Hexch = 2 * A_AFM.i * delsq_M_A / ((cuBReal)MU0 * Ms_AFM.i * Ms_AFM.i) + (-4 * Ah.i * (M[idx] ^ (M[idx] ^ M2[idx])) / (Mmag.i*Mmag.i) + Anh.i * delsq_M_B) / ((cuBReal)MU0*Ms_AFM.i*Ms_AFM.j);
				Hexch2 = 2 * A_AFM.j * delsq_M_B / ((cuBReal)MU0 * Ms_AFM.j * Ms_AFM.j) + (-4 * Ah.j * (M2[idx] ^ (M2[idx] ^ M[idx])) / (Mmag.j*Mmag.j) + Anh.j * delsq_M_A) / ((cuBReal)MU0*Ms_AFM.i*Ms_AFM.j);

				//Dzyaloshinskii-Moriya interfacial exchange contribution

				//Differentials of M components (we only need 4, not all 9 so this could be optimised). First index is the differential direction, second index is the M component
				cuReal33 Mdiff = M.grad_neu(idx);

				//Hdm, ex = -2D / (mu0*Ms) * (dmz / dx, dmz / dy, -dmx / dx - dmy / dy)
				Hexch += -2 * D_AFM.i * cuReal3(Mdiff.x.z, Mdiff.y.z, -Mdiff.x.x - Mdiff.y.y) / ((cuBReal)MU0 * Ms_AFM.i * Ms_AFM.i);

				//same thing on sub-lattice B (2)

				Mdiff = M2.grad_neu(idx);
				Hexch2 += -2 * D_AFM.j * cuReal3(Mdiff.x.z, Mdiff.y.z, -Mdiff.x.x - Mdiff.y.y) / ((cuBReal)MU0 * Ms_AFM.j * Ms_AFM.j);
			}
			else {

				cuReal33 bndA_nneu, bndB_nneu;

				cuReal2 nhconst = Anh / (2 * A_AFM);

				if (fabs(nhconst.i) != 1.0) {

					//Non-homogeneous Neumann boundary conditions apply when using DMI. Required to ensure Brown's condition is fulfilled, i.e. m x h -> 0 when relaxing.
					cuReal3 bnd_dm_dx = (D_AFM.i / (2 * A_AFM.i * (1 - nhconst.i * nhconst.i))) * cuReal3(M[idx].z - nhconst.i * M2[idx].z, 0, -M[idx].x + nhconst.i * M2[idx].x);
					cuReal3 bnd_dm_dy = (D_AFM.i / (2 * A_AFM.i * (1 - nhconst.i * nhconst.i))) * cuReal3(0, M[idx].z - nhconst.i * M2[idx].z, -M[idx].y + nhconst.i * M2[idx].y);

					bndA_nneu = cuReal33(bnd_dm_dx, bnd_dm_dy, cuReal3());
				}
				else {

					cuReal3 bnd_dm_dx = (D_AFM.i / (4 * A_AFM.i)) * cuReal3(M[idx].z, 0, -M[idx].x);
					cuReal3 bnd_dm_dy = (D_AFM.i / (4 * A_AFM.i)) * cuReal3(0, M[idx].z, -M[idx].y);

					bndA_nneu = cuReal33(bnd_dm_dx, bnd_dm_dy, cuReal3());
				}

				if (fabs(nhconst.j) != 1.0) {

					cuReal3 bnd_dm_dx = (D_AFM.j / (2 * A_AFM.j * (1 - nhconst.j * nhconst.j))) * cuReal3(M2[idx].z - nhconst.j * M[idx].z, 0, -M2[idx].x + nhconst.j * M[idx].x);
					cuReal3 bnd_dm_dy = (D_AFM.j / (2 * A_AFM.j * (1 - nhconst.j * nhconst.j))) * cuReal3(0, M2[idx].z - nhconst.j * M[idx].z, -M2[idx].y + nhconst.j * M[idx].y);

					bndB_nneu = cuReal33(bnd_dm_dx, bnd_dm_dy, cuReal3());
				}
				else {

					cuReal3 bnd_dm_dx = (D_AFM.j / (4 * A_AFM.j)) * cuReal3(M2[idx].z, 0, -M2[idx].x);
					cuReal3 bnd_dm_dy = (D_AFM.j / (4 * A_AFM.j)) * cuReal3(0, M2[idx].z, -M2[idx].y);

					bndB_nneu = cuReal33(bnd_dm_dx, bnd_dm_dy, cuReal3());
				}

				cuReal3 delsq_M_A = M.delsq_nneu(idx, bndA_nneu);
				cuReal3 delsq_M_B = M2.delsq_nneu(idx, bndB_nneu);

				cuReal2 Mmag = cuReal2(M[idx].norm(), M2[idx].norm());

				//1. direct exchange contribution + AFM contribution

				//cells marked with cmbnd are calculated using exchange coupling to other ferromagnetic meshes - see below; the delsq_nneu evaluates to zero in the CMBND coupling direction.
				Hexch = 2 * A_AFM.i * delsq_M_A / ((cuBReal)MU0 * Ms_AFM.i * Ms_AFM.i) + (-4 * Ah.i * (M[idx] ^ (M[idx] ^ M2[idx])) / (Mmag.i*Mmag.i) + Anh.i * delsq_M_B) / ((cuBReal)MU0*Ms_AFM.i*Ms_AFM.j);
				Hexch2 = 2 * A_AFM.j * delsq_M_B / ((cuBReal)MU0 * Ms_AFM.j * Ms_AFM.j) + (-4 * Ah.j * (M2[idx] ^ (M2[idx] ^ M[idx])) / (Mmag.j*Mmag.j) + Anh.j * delsq_M_A) / ((cuBReal)MU0*Ms_AFM.i*Ms_AFM.j);

				//2. Dzyaloshinskii-Moriya interfacial exchange contribution

				//Differentials of M components (we only need 4, not all 9 so this could be optimised). First index is the differential direction, second index is the M component
				//For cmbnd cells grad_nneu does not evaluate to zero in the CMBND coupling direction, but sided differentials are used - when setting values at CMBND cells for exchange coupled meshes must correct for this.
				cuReal33 Mdiff_A = M.grad_nneu(idx, bndA_nneu);
				cuReal33 Mdiff_B = M2.grad_nneu(idx, bndB_nneu);

				//Hdm, ex = -2D / (mu0*Ms) * (dmz / dx, dmz / dy, -dmx / dx - dmy / dy)
				Hexch += -2 * D_AFM.i * cuReal3(Mdiff_A.x.z, Mdiff_A.y.z, -Mdiff_A.x.x - Mdiff_A.y.y) / ((cuBReal)MU0 * Ms_AFM.i * Ms_AFM.i);
				Hexch2 += -2 * D_AFM.j * cuReal3(Mdiff_B.x.z, Mdiff_B.y.z, -Mdiff_B.x.x - Mdiff_B.y.y) / ((cuBReal)MU0 * Ms_AFM.j * Ms_AFM.j);
			}

			energy_ = fabs((cuBReal)MU0 * (M[idx] * Hexch + M2[idx] * Hexch2) / 4);
			include_in_reduction = true;
		}
	}

	reduction_max(0, 1, &energy_, energy, include_in_reduction);
}

cuBReal iDMExchangeCUDA::GetEnergyDensity(cuRect avRect)
{
	ZeroEnergy();

	if (pMeshCUDA->GetMeshType() == MESH_ANTIFERROMAGNETIC) {

		//anti-ferromagnetic mesh

		iDMExchangeCUDA_AFM_GetEnergy <<< (pMeshCUDA->n.dim() + CUDATHREADS) / CUDATHREADS, CUDATHREADS >>> (pMeshCUDA->cuMesh, energy, points_count, avRect);
	}
	else {

		//ferromagnetic mesh

		iDMExchangeCUDA_FM_GetEnergy <<< (pMeshCUDA->n.dim() + CUDATHREADS) / CUDATHREADS, CUDATHREADS >>> (pMeshCUDA->cuMesh, energy, points_count, avRect);
	}

	size_t points_count_cpu = points_count.to_cpu();

	if (points_count_cpu) return energy.to_cpu() / points_count_cpu;
	else return 0.0;
}

cuBReal iDMExchangeCUDA::GetEnergy_Max(cuRect rectangle)
{
	ZeroEnergy();

	if (pMeshCUDA->GetMeshType() == MESH_ANTIFERROMAGNETIC) {

		//anti-ferromagnetic mesh

		iDMExchangeCUDA_AFM_GetEnergy_Max <<< (pMeshCUDA->n.dim() + CUDATHREADS) / CUDATHREADS, CUDATHREADS >>> (pMeshCUDA->cuMesh, energy, rectangle);
	}
	else {

		//ferromagnetic mesh

		iDMExchangeCUDA_FM_GetEnergy_Max <<< (pMeshCUDA->n.dim() + CUDATHREADS) / CUDATHREADS, CUDATHREADS >>> (pMeshCUDA->cuMesh, energy, rectangle);
	}

	return energy.to_cpu();
}

//////////////////////////////////////////////////////////////////////// ENERGY DENSITY DISPLAY METHODS

__global__ void iDMExchangeCUDA_FM_Compute_Exchange(ManagedMeshCUDA& cuMesh, cuVEC<cuBReal>& exchange_displayVEC)
{
	cuVEC_VC<cuReal3>& M = *cuMesh.pM;

	int idx = blockIdx.x * blockDim.x + threadIdx.x;

	if (idx < M.linear_size()) {

		cuReal3 Hexch = cuReal3();

		if (M.is_not_empty(idx)) {

			cuBReal Ms = *cuMesh.pMs;
			cuBReal A = *cuMesh.pA;
			cuBReal D = *cuMesh.pD;
			cuMesh.update_parameters_mcoarse(idx, *cuMesh.pMs, Ms, *cuMesh.pA, A, *cuMesh.pD, D);

			if (M.is_plane_interior(idx)) {

				//interior point : can use cheaper neu versions

				//direct exchange contribution
				Hexch = 2 * A * M.delsq_neu(idx) / ((cuBReal)MU0 * Ms * Ms);

				//Dzyaloshinskii-Moriya interfacial exchange contribution

				//Differentials of M components (we only need 4, not all 9 so this could be optimised). First index is the differential direction, second index is the M component
				cuReal33 Mdiff = M.grad_neu(idx);

				//Hdm, ex = -2D / (mu0*Ms) * (dmz / dx, dmz / dy, -dmx / dx - dmy / dy)
				Hexch += -2 * D * cuReal3(Mdiff.x.z, Mdiff.y.z, -Mdiff.x.x - Mdiff.y.y) / ((cuBReal)MU0 * Ms * Ms);
			}
			else {

				//Non-homogeneous Neumann boundary conditions apply when using DMI. Required to ensure Brown's condition is fulfilled, i.e. m x h -> 0 when relaxing.
				cuReal3 bnd_dm_dx = (D / (2 * A)) * cuReal3(M[idx].z, 0, -M[idx].x);
				cuReal3 bnd_dm_dy = (D / (2 * A)) * cuReal3(0, M[idx].z, -M[idx].y);
				cuReal33 bnd_nneu = cuReal33(bnd_dm_dx, bnd_dm_dy, cuReal3());

				//direct exchange contribution
				Hexch = 2 * A * M.delsq_nneu(idx, bnd_nneu) / ((cuBReal)MU0 * Ms * Ms);

				//Dzyaloshinskii-Moriya interfacial exchange contribution

				//Differentials of M components (we only need 4, not all 9 so this could be optimised). First index is the differential direction, second index is the M component
				cuReal33 Mdiff = M.grad_nneu(idx, bnd_nneu);

				//Hdm, ex = -2D / (mu0*Ms) * (dmz / dx, dmz / dy, -dmx / dx - dmy / dy)
				Hexch += -2 * D * cuReal3(Mdiff.x.z, Mdiff.y.z, -Mdiff.x.x - Mdiff.y.y) / ((cuBReal)MU0 * Ms * Ms);
			}
		}

		exchange_displayVEC[idx] = -(cuBReal)MU0 * (M[idx] * Hexch) / 2;
	}
}

__global__ void iDMExchangeCUDA_AFM_Compute_Exchange(ManagedMeshCUDA& cuMesh, cuVEC<cuBReal>& exchange_displayVEC)
{
	cuVEC_VC<cuReal3>& M = *cuMesh.pM;
	cuVEC_VC<cuReal3>& M2 = *cuMesh.pM2;

	int idx = blockIdx.x * blockDim.x + threadIdx.x;

	if (idx < M.linear_size()) {

		cuReal3 Hexch = cuReal3();
		cuReal3 Hexch2 = cuReal3();

		if (M.is_not_empty(idx)) {

			cuReal2 Ms_AFM = *cuMesh.pMs_AFM;
			cuReal2 A_AFM = *cuMesh.pA_AFM;
			cuReal2 Ah = *cuMesh.pAh;
			cuReal2 Anh = *cuMesh.pAnh;
			cuReal2 D_AFM = *cuMesh.pD_AFM;
			cuMesh.update_parameters_mcoarse(idx, *cuMesh.pMs_AFM, Ms_AFM, *cuMesh.pA_AFM, A_AFM, *cuMesh.pAh, Ah, *cuMesh.pAnh, Anh, *cuMesh.pD_AFM, D_AFM);

			if (M.is_plane_interior(idx)) {

				//interior point : can use cheaper neu versions

				//1. direct exchange contribution + AFM contribution
				cuReal3 delsq_M_A = M.delsq_neu(idx);
				cuReal3 delsq_M_B = M2.delsq_neu(idx);

				cuReal2 Mmag = cuReal2(M[idx].norm(), M2[idx].norm());

				Hexch = 2 * A_AFM.i * delsq_M_A / ((cuBReal)MU0 * Ms_AFM.i * Ms_AFM.i) + (-4 * Ah.i * (M[idx] ^ (M[idx] ^ M2[idx])) / (Mmag.i*Mmag.i) + Anh.i * delsq_M_B) / ((cuBReal)MU0*Ms_AFM.i*Ms_AFM.j);
				Hexch2 = 2 * A_AFM.j * delsq_M_B / ((cuBReal)MU0 * Ms_AFM.j * Ms_AFM.j) + (-4 * Ah.j * (M2[idx] ^ (M2[idx] ^ M[idx])) / (Mmag.j*Mmag.j) + Anh.j * delsq_M_A) / ((cuBReal)MU0*Ms_AFM.i*Ms_AFM.j);

				//Dzyaloshinskii-Moriya interfacial exchange contribution

				//Differentials of M components (we only need 4, not all 9 so this could be optimised). First index is the differential direction, second index is the M component
				cuReal33 Mdiff = M.grad_neu(idx);

				//Hdm, ex = -2D / (mu0*Ms) * (dmz / dx, dmz / dy, -dmx / dx - dmy / dy)
				Hexch += -2 * D_AFM.i * cuReal3(Mdiff.x.z, Mdiff.y.z, -Mdiff.x.x - Mdiff.y.y) / ((cuBReal)MU0 * Ms_AFM.i * Ms_AFM.i);

				//same thing on sub-lattice B (2)

				Mdiff = M2.grad_neu(idx);
				Hexch2 += -2 * D_AFM.j * cuReal3(Mdiff.x.z, Mdiff.y.z, -Mdiff.x.x - Mdiff.y.y) / ((cuBReal)MU0 * Ms_AFM.j * Ms_AFM.j);
			}
			else {

				cuReal33 bndA_nneu, bndB_nneu;

				cuReal2 nhconst = Anh / (2 * A_AFM);

				if (fabs(nhconst.i) != 1.0) {

					//Non-homogeneous Neumann boundary conditions apply when using DMI. Required to ensure Brown's condition is fulfilled, i.e. m x h -> 0 when relaxing.
					cuReal3 bnd_dm_dx = (D_AFM.i / (2 * A_AFM.i * (1 - nhconst.i * nhconst.i))) * cuReal3(M[idx].z - nhconst.i * M2[idx].z, 0, -M[idx].x + nhconst.i * M2[idx].x);
					cuReal3 bnd_dm_dy = (D_AFM.i / (2 * A_AFM.i * (1 - nhconst.i * nhconst.i))) * cuReal3(0, M[idx].z - nhconst.i * M2[idx].z, -M[idx].y + nhconst.i * M2[idx].y);

					bndA_nneu = cuReal33(bnd_dm_dx, bnd_dm_dy, cuReal3());
				}
				else {

					cuReal3 bnd_dm_dx = (D_AFM.i / (4 * A_AFM.i)) * cuReal3(M[idx].z, 0, -M[idx].x);
					cuReal3 bnd_dm_dy = (D_AFM.i / (4 * A_AFM.i)) * cuReal3(0, M[idx].z, -M[idx].y);

					bndA_nneu = cuReal33(bnd_dm_dx, bnd_dm_dy, cuReal3());
				}

				if (fabs(nhconst.j) != 1.0) {

					cuReal3 bnd_dm_dx = (D_AFM.j / (2 * A_AFM.j * (1 - nhconst.j * nhconst.j))) * cuReal3(M2[idx].z - nhconst.j * M[idx].z, 0, -M2[idx].x + nhconst.j * M[idx].x);
					cuReal3 bnd_dm_dy = (D_AFM.j / (2 * A_AFM.j * (1 - nhconst.j * nhconst.j))) * cuReal3(0, M2[idx].z - nhconst.j * M[idx].z, -M2[idx].y + nhconst.j * M[idx].y);

					bndB_nneu = cuReal33(bnd_dm_dx, bnd_dm_dy, cuReal3());
				}
				else {

					cuReal3 bnd_dm_dx = (D_AFM.j / (4 * A_AFM.j)) * cuReal3(M2[idx].z, 0, -M2[idx].x);
					cuReal3 bnd_dm_dy = (D_AFM.j / (4 * A_AFM.j)) * cuReal3(0, M2[idx].z, -M2[idx].y);

					bndB_nneu = cuReal33(bnd_dm_dx, bnd_dm_dy, cuReal3());
				}

				cuReal3 delsq_M_A = M.delsq_nneu(idx, bndA_nneu);
				cuReal3 delsq_M_B = M2.delsq_nneu(idx, bndB_nneu);

				cuReal2 Mmag = cuReal2(M[idx].norm(), M2[idx].norm());

				//1. direct exchange contribution + AFM contribution

				//cells marked with cmbnd are calculated using exchange coupling to other ferromagnetic meshes - see below; the delsq_nneu evaluates to zero in the CMBND coupling direction.
				Hexch = 2 * A_AFM.i * delsq_M_A / ((cuBReal)MU0 * Ms_AFM.i * Ms_AFM.i) + (-4 * Ah.i * (M[idx] ^ (M[idx] ^ M2[idx])) / (Mmag.i*Mmag.i) + Anh.i * delsq_M_B) / ((cuBReal)MU0*Ms_AFM.i*Ms_AFM.j);
				Hexch2 = 2 * A_AFM.j * delsq_M_B / ((cuBReal)MU0 * Ms_AFM.j * Ms_AFM.j) + (-4 * Ah.j * (M2[idx] ^ (M2[idx] ^ M[idx])) / (Mmag.j*Mmag.j) + Anh.j * delsq_M_A) / ((cuBReal)MU0*Ms_AFM.i*Ms_AFM.j);

				//2. Dzyaloshinskii-Moriya interfacial exchange contribution

				//Differentials of M components (we only need 4, not all 9 so this could be optimised). First index is the differential direction, second index is the M component
				//For cmbnd cells grad_nneu does not evaluate to zero in the CMBND coupling direction, but sided differentials are used - when setting values at CMBND cells for exchange coupled meshes must correct for this.
				cuReal33 Mdiff_A = M.grad_nneu(idx, bndA_nneu);
				cuReal33 Mdiff_B = M2.grad_nneu(idx, bndB_nneu);

				//Hdm, ex = -2D / (mu0*Ms) * (dmz / dx, dmz / dy, -dmx / dx - dmy / dy)
				Hexch += -2 * D_AFM.i * cuReal3(Mdiff_A.x.z, Mdiff_A.y.z, -Mdiff_A.x.x - Mdiff_A.y.y) / ((cuBReal)MU0 * Ms_AFM.i * Ms_AFM.i);
				Hexch2 += -2 * D_AFM.j * cuReal3(Mdiff_B.x.z, Mdiff_B.y.z, -Mdiff_B.x.x - Mdiff_B.y.y) / ((cuBReal)MU0 * Ms_AFM.j * Ms_AFM.j);
			}
		}

		exchange_displayVEC[idx] = -(cuBReal)MU0 * (M[idx] * Hexch + M2[idx] * Hexch2) / 4;
	}
}

void iDMExchangeCUDA::Compute_ExchangeCUDA(void)
{
	exchange_displayVEC()->resize(pMeshCUDA->h, pMeshCUDA->meshRect);

	if (pMeshCUDA->GetMeshType() == MESH_ANTIFERROMAGNETIC) {

		//anti-ferromagnetic mesh

		iDMExchangeCUDA_AFM_Compute_Exchange <<< (pMeshCUDA->n.dim() + CUDATHREADS) / CUDATHREADS, CUDATHREADS >>> (pMeshCUDA->cuMesh, exchange_displayVEC);
	}
	else {

		//ferromagnetic mesh

		iDMExchangeCUDA_FM_Compute_Exchange <<< (pMeshCUDA->n.dim() + CUDATHREADS) / CUDATHREADS, CUDATHREADS >>> (pMeshCUDA->cuMesh, exchange_displayVEC);
	}
}

#endif

#endif