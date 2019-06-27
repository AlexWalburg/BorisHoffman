#include "stdafx.h"
#include "SurfExchangeCUDA.h"

#if COMPILECUDA == 1

#ifdef MODULE_SURFEXCHANGE

#include "SurfExchange.h"
#include "Mesh_Ferromagnetic.h"
#include "Mesh_FerromagneticCUDA.h"

SurfExchangeCUDA::SurfExchangeCUDA(FMeshCUDA* pMeshCUDA_, SurfExchange* pSurfExch_)
	: ModulesCUDA()
{
	pMeshCUDA = pMeshCUDA_;
	pSurfExch = pSurfExch_;
}

SurfExchangeCUDA::~SurfExchangeCUDA()
{}

BError SurfExchangeCUDA::Initialize(void)
{
	BError error(CLASS_STR(SurfExchangeCUDA));

	//clear cu_arrs then rebuild them from information in SurfExchange module
	pMesh_Bot.clear();
	pMesh_Top.clear();

	//make sure information in SurfExchange module is up to date
	error = pSurfExch->Initialize();

	if (!error) {

		for (int idx = 0; idx < pSurfExch->pMesh_Bot.size(); idx++) {

			pMesh_Bot.push_back(pSurfExch->pMesh_Bot[idx]->pMeshCUDA->cuMesh.get_managed_object());
		}

		for (int idx = 0; idx < pSurfExch->pMesh_Top.size(); idx++) {

			pMesh_Top.push_back(pSurfExch->pMesh_Top[idx]->pMeshCUDA->cuMesh.get_managed_object());
		}

		initialized = true;
	}

	return error;
}

BError SurfExchangeCUDA::UpdateConfiguration(UPDATECONFIG_ cfgMessage)
{
	BError error(CLASS_STR(SurfExchangeCUDA));

	Uninitialize();

	return error;
}

#endif

#endif

