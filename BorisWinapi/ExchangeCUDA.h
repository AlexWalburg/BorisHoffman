#pragma once

#include "Boris_Enums_Defs.h"
#if COMPILECUDA == 1

#ifdef MODULE_EXCHANGE

#include "BorisCUDALib.h"
#include "ModulesCUDA.h"
#include "ExchangeBaseCUDA.h"

class FMeshCUDA;
class Exch_6ngbr_Neu;

class Exch_6ngbr_NeuCUDA :
	public ModulesCUDA,
	public ExchangeBaseCUDA
{

	//pointer to CUDA version of mesh object holding the effective field module holding this CUDA module
	FMeshCUDA* pMeshCUDA;

public:

	Exch_6ngbr_NeuCUDA(FMeshCUDA* pMeshCUDA_, Exch_6ngbr_Neu* pExch_6ngbr_Neu);
	~Exch_6ngbr_NeuCUDA();

	//-------------------Abstract base class method implementations

	void Uninitialize(void) { initialized = false; }

	BError Initialize(void);

	BError UpdateConfiguration(UPDATECONFIG_ cfgMessage = UPDATECONFIG_GENERIC);

	void UpdateField(void);

	//-------------------

};

#else

class Exch_6ngbr_NeuCUDA
{
};

#endif

#endif

