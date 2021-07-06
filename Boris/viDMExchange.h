#pragma once

#include "BorisLib.h"
#include "Modules.h"

class Mesh;

#ifdef MODULE_COMPILATION_VIDMEXCHANGE

#include "ExchangeBase.h"

//Exchange modules can only be used in a magnetic mesh

class viDMExchange :
	public Modules,
	public ExchangeBase,
	public ProgramState<viDMExchange, std::tuple<>, std::tuple<>>
{

private:

	//pointer to mesh object holding this effective field module
	Mesh * pMesh;

public:

	viDMExchange(Mesh *pMesh_);
	~viDMExchange();

	//-------------------Implement ProgramState method

	void RepairObjectState(void) {}

	//-------------------Abstract base class method implementations

	void Uninitialize(void) { initialized = false; }

	BError Initialize(void);

	BError UpdateConfiguration(UPDATECONFIG_ cfgMessage);
	void UpdateConfiguration_Values(UPDATECONFIG_ cfgMessage) {}

	BError MakeCUDAModule(void);

	double UpdateField(void);

	//-------------------Energy methods

	double Get_EnergyChange(int spin_index, DBL3 Mnew);

	//-------------------Torque methods

	DBL3 GetTorque(Rect& avRect);
};

#else

class viDMExchange :
	public Modules
{

private:

public:

	viDMExchange(Mesh *pMesh_) {}
	~viDMExchange() {}

	//-------------------Abstract base class method implementations

	void Uninitialize(void) {}

	BError Initialize(void) { return BError(); }

	BError UpdateConfiguration(UPDATECONFIG_ cfgMessage) { return BError(); }
	void UpdateConfiguration_Values(UPDATECONFIG_ cfgMessage) {}

	BError MakeCUDAModule(void) { return BError(); }

	double UpdateField(void) { return 0.0; }
};

#endif