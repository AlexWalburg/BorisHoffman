#include "stdafx.h"
#include "TransportCUDA_Poisson_Spin_V.h"

#if COMPILECUDA == 1

#ifdef MODULE_COMPILATION_TRANSPORT

#include "MeshCUDA.h"
#include "Atom_MeshCUDA.h"
#include "TransportBaseCUDA.h"

//for modules held in micromagnetic meshes
BError TransportCUDA_Spin_V_Funcs::set_pointers_transport(MeshCUDA* pMeshCUDA, TransportBaseCUDA* pTransportBaseCUDA)
{
	BError error(__FUNCTION__);

	//Mesh quantities

	if (set_gpu_value(pcuMesh, pMeshCUDA->cuMesh.get_managed_object()) != cudaSuccess) error(BERROR_GPUERROR_CRIT);

	if (set_gpu_value(pdM_dt, pTransportBaseCUDA->dM_dt.get_managed_object()) != cudaSuccess) error(BERROR_GPUERROR_CRIT);
	if (set_gpu_value(pdelsq_V_fixed, pTransportBaseCUDA->delsq_V_fixed.get_managed_object()) != cudaSuccess) error(BERROR_GPUERROR_CRIT);

	if (set_gpu_value(stsolve, pTransportBaseCUDA->Get_STSolveType()) != cudaSuccess) error(BERROR_GPUERROR_CRIT);

	//atomistic version not used
	nullgpuptr(pcuaMesh);

	return error;
}

//for modules held in atomistic meshes
BError TransportCUDA_Spin_V_Funcs::set_pointers_atomtransport(Atom_MeshCUDA* paMeshCUDA, TransportBaseCUDA* pTransportBaseCUDA)
{
	BError error(__FUNCTION__);

	//Mesh quantities

	if (set_gpu_value(pcuaMesh, paMeshCUDA->cuaMesh.get_managed_object()) != cudaSuccess) error(BERROR_GPUERROR_CRIT);

	if (set_gpu_value(pdM_dt, pTransportBaseCUDA->dM_dt.get_managed_object()) != cudaSuccess) error(BERROR_GPUERROR_CRIT);
	if (set_gpu_value(pdelsq_V_fixed, pTransportBaseCUDA->delsq_V_fixed.get_managed_object()) != cudaSuccess) error(BERROR_GPUERROR_CRIT);

	if (set_gpu_value(stsolve, pTransportBaseCUDA->Get_STSolveType()) != cudaSuccess) error(BERROR_GPUERROR_CRIT);

	//micromagnetic version not used
	nullgpuptr(pcuMesh);

	return error;
}

#endif

#endif