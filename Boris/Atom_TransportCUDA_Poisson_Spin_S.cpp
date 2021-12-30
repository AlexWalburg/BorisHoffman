#include "stdafx.h"
#include "Atom_TransportCUDA_Poisson_Spin_S.h"

#if COMPILECUDA == 1

#if defined(MODULE_COMPILATION_TRANSPORT) && ATOMISTIC == 1

#include "Atom_MeshCUDA.h"
#include "Atom_DiffEqCubicCUDA.h"
#include "Atom_TransportCUDA.h"

BError Atom_TransportCUDA_Spin_S_Funcs::set_pointers(Atom_MeshCUDA* paMeshCUDA, Atom_DifferentialEquationCubicCUDA* pdiffEqCUDA, Atom_TransportCUDA* pTransportCUDA)
{
	BError error(__FUNCTION__);

	if (set_gpu_value(pcuaMesh, paMeshCUDA->cuaMesh.get_managed_object()) != cudaSuccess) error(BERROR_GPUERROR_CRIT);

	if (pdiffEqCUDA) {

		if (set_gpu_value(pcuDiffEq, pdiffEqCUDA->Get_ManagedAtom_DiffEqCUDA().get_managed_object()) != cudaSuccess) error(BERROR_GPUERROR_CRIT);
	}
	else {

		nullgpuptr(pcuDiffEq);
	}

	if (set_gpu_value(pPoisson_Spin_V, pTransportCUDA->poisson_Spin_V.get_managed_object()) != cudaSuccess) error(BERROR_GPUERROR_CRIT);

	if (set_gpu_value(pdM_dt, pTransportCUDA->dM_dt.get_managed_object()) != cudaSuccess) error(BERROR_GPUERROR_CRIT);
	if (set_gpu_value(pdelsq_S_fixed, pTransportCUDA->delsq_S_fixed.get_managed_object()) != cudaSuccess) error(BERROR_GPUERROR_CRIT);

	if (set_gpu_value(stsolve, pTransportCUDA->Get_STSolveType()) != cudaSuccess) error(BERROR_GPUERROR_CRIT);

	return error;
}

#endif

#endif