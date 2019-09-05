#pragma once

#include "BorisLib.h"
#include "Modules.h"

using namespace std;

class Mesh;
class FMesh;

#ifdef MODULE_DEMAG

#include "Convolution.h"
#include "DemagKernel.h"

class Demag : 
	public Modules, 
	public Convolution<DemagKernel>,
	public ProgramState<Demag, tuple<INT3>, tuple<>>
{

private:

	//pointer to mesh object holding this effective field module
	FMesh *pMesh;

	//number of pbc images in each dimension (set to zero to disable).
	//There is also a copy of this in ConvolutionData inherited from Convolution - we need another copy here to detect changes
	//these pbc images are applicable in individual demag modules only
	INT3 demag_pbc_images = INT3();

	//The demag field computed separately : at certain steps in the ODE evaluation method we don't need to recalculate the demag field but can use a previous evaluation with an acceptable impact on the numerical error.
	//This mode needs to be enabled by the user, and can be much faster than the default mode. The default mode is to re-evaluate the demag field at every step.
	VEC<DBL3> Hdemag;

public:

	Demag(Mesh *pMesh_);
	~Demag() {}

	//-------------------Implement ProgramState method

	void RepairObjectState(void) {}

	//-------------------Abstract base class method implementations

	void Uninitialize(void) { initialized = false; }

	BError Initialize(void);

	BError UpdateConfiguration(UPDATECONFIG_ cfgMessage = UPDATECONFIG_GENERIC);

	BError MakeCUDAModule(void);

	double UpdateField(void);

	//-------------------Setters

	//Set PBC
	void Set_PBC(INT3 demag_pbc_images_);

	//-------------------Getters

	//Get PBC images
	INT3 Get_PBC(void) { return demag_pbc_images; }
};

#else

class Demag :
	public Modules
{

private:

	//pointer to mesh object holding this effective field module
	FMesh * pMesh;

public:

	Demag(Mesh *pMesh_) {}
	~Demag() {}

	//-------------------Implement ProgramState method

	void RepairObjectState(void) {}

	//-------------------Abstract base class method implementations

	void Uninitialize(void) {}

	BError Initialize(void) { return BError(); }

	BError UpdateConfiguration(UPDATECONFIG_ cfgMessage = UPDATECONFIG_GENERIC) { return BError(); }

	BError MakeCUDAModule(void) { return BError(); }

	double UpdateField(void) { return 0.0; }
};

#endif