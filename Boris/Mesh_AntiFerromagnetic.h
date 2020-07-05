#pragma once

#include "Mesh.h"

#include "DiffEqAFM.h"

#if COMPILECUDA == 1
#include "Mesh_AntiFerromagneticCUDA.h"
#endif

#ifdef MESH_COMPILATION_ANTIFERROMAGNETIC

#include "SkyrmionTrack.h"

#include "Exchange.h"
#include "DMExchange.h"
#include "iDMExchange.h"
#include "SurfExchange.h"
#include "Demag.h"
#include "Demag_N.h"
#include "SDemag_Demag.h"
#include "Zeeman.h"
#include "MOptical.h"
#include "Anisotropy.h"
#include "AnisotropyCubi.h"
#include "Transport.h"
#include "Heat.h"
#include "SOTField.h"
#include "Roughness.h"

/////////////////////////////////////////////////////////////////////
//
//Anti-Ferromagnetic Material Mesh

class SuperMesh;

class AFMesh :
	public Mesh,
	public ProgramState<AFMesh,
	tuple<
	//Mesh members
	int, int, int, 
	int, int, int, int, 
	Rect, SZ3, DBL3, SZ3, DBL3, SZ3, DBL3, SZ3, DBL3, SZ3, DBL3, bool,
	VEC_VC<DBL3>, VEC_VC<DBL3>, VEC_VC<double>, VEC_VC<double>, VEC_VC<double>, VEC_VC<double>, 
	vector_lut<Modules*>, 
	bool,
	//Members in this derived class
	bool, SkyrmionTrack, bool,
	//Material Parameters
	MatP<DBL2, double>, MatP<DBL2, double>, MatP<DBL2, double>, MatP<DBL2, double>, 
	MatP<DBL2, double>, MatP<DBL2, double>, MatP<DBL2, double>, MatP<DBL2, double>, MatP<DBL2, double>, MatP<DBL2, double>,
	MatP<DBL2, double>, MatP<DBL2, double>, MatP<DBL3, DBL3>, MatP<DBL3, DBL3>,
	MatP<DBL2, double>, MatP<double, double>, MatP<double, double>,
	MatP<double, double>, MatP<double, double>, MatP<double, double>, MatP<double, double>, MatP<double, double>,
	double, TEquation<double>, double, MatP<double, double>, MatP<DBL2, double>, 
	MatP<double, double>, 
	MatP<double, double>, MatP<double, double>, MatP<double, double>, MatP<double, double>, MatP<double, double>, MatP<double, double>>,
	//Module Implementations
	tuple<Demag_N, Demag, SDemag_Demag, Exch_6ngbr_Neu, DMExchange, iDMExchange, SurfExchange, Zeeman, MOptical, Anisotropy_Uniaxial, Anisotropy_Cubic, Transport, Heat, SOTField, Roughness> >
{
#if COMPILECUDA == 1
	friend AFMeshCUDA;
#endif

private:

	//The set ODE, associated with this ferromagnetic mesh (the ODE type and evaluation method is controlled from SuperMesh)
	DifferentialEquationAFM meshODE;

	//is this mesh used to trigger mesh movement? i.e. the CheckMoveMesh method should only be used if this flag is set
	bool move_mesh_trigger = false;

	//object used to track one or more skyrmions in this mesh
	SkyrmionTrack skyShift;

	//direct exchange coupling to neighboring meshes?
	//If true this is applicable for this mesh only for cells at contacts with other antiferromagnetic meshes 
	//i.e. if two distinct meshes with the same materials are in contact, setting this flag to true will make the simulation behave as if the two materials are in the same computational mesh (provided the demag field is computed on the supermesh).
	//this is precisely what it is intended for; if two dissimilar materials are in contact then you probably shouldn't be using this mechanism.
	bool exchange_couple_to_meshes = false;

public:

	//constructor taking only a SuperMesh pointer (SuperMesh is the owner) only needed for loading : all required values will be set by LoadObjectState method in ProgramState
	AFMesh(SuperMesh *pSMesh_);

	AFMesh(Rect meshRect_, DBL3 h_, SuperMesh *pSMesh_);

	~AFMesh();

	//implement pure virtual method from ProgramState
	void RepairObjectState(void);

	//----------------------------------- INITIALIZATION

	//----------------------------------- IMPORTANT CONTROL METHODS

	//call when a configuration change has occurred - some objects might need to be updated accordingly
	BError UpdateConfiguration(UPDATECONFIG_ cfgMessage);
	void UpdateConfiguration_Values(UPDATECONFIG_ cfgMessage);

	BError SwitchCUDAState(bool cudaState);

	//called at the start of each iteration
	void PrepareNewIteration(void) { Heff.set(DBL3(0)); Heff2.set(DBL3(0)); }

#if COMPILECUDA == 1
	void PrepareNewIterationCUDA(void) 
	{ 
		if (pMeshCUDA) {

			pMeshCUDA->Heff()->set(n.dim(), cuReal3());
			pMeshCUDA->Heff2()->set(n.dim(), cuReal3());
		}
	}
#endif

	//Check if mesh needs to be moved (using the MoveMesh method) - return amount of movement required (i.e. parameter to use when calling MoveMesh).
	double CheckMoveMesh(void);

	//couple this mesh to touching dipoles by setting skip cells as required : used for domain wall moving mesh algorithms
	void CoupleToDipoles(bool status);

	//----------------------------------- MOVING MESH TRIGGER FLAG

	bool GetMoveMeshTrigger(void) { return move_mesh_trigger; }
	void SetMoveMeshTrigger(bool status) { move_mesh_trigger = status; }

	//----------------------------------- ODE CONTROL METHODS IN (ANTI)FERROMAGNETIC MESH : Mesh_AntiFerromagnetic_ODEControl.cpp

	//get rate of change of magnetization (overloaded by Antiferromagnetic meshes)
	DBL3 dMdt(int idx);

	//----------------------------------- ANTIFERROMAGNETIC MESH QUANTITIES CONTROL : Mesh_Ferromagnetic_Control.cpp

	//The following methods are very similar to the ones in the ferromagnetic mesh, but set M and M2 anti-parallel

	//this method is also used by the dipole mesh where it does something else - sets the dipole direction
	void SetMagAngle(double polar, double azim, Rect rectangle = Rect());

	//Invert magnetisation direction in given mesh
	void SetInvertedMag(bool x, bool y, bool z);

	//Mirror magnetisation in given axis (literal x, y, or z) in given mesh (must be magnetic)
	void SetMirroredMag(string axis);

	//Set random magentisation distribution in given mesh
	void SetRandomMag(void);

	//set a domain wall with given width (metric units) at position within mesh (metric units). 
	//Longitudinal and transverse are magnetisation componets as: 1: x, 2: y, 3: z, 1: -x, 2: -y, 3: -z
	void SetMagDomainWall(int longitudinal, int transverse, double width, double position);

	//set Neel skyrmion with given orientation (core is up: 1, core is down: -1), chirality (1 for towards centre, -1 away from it) in given rectangle (relative to mesh), calculated in the x-y plane
	void SetSkyrmion(int orientation, int chirality, Rect skyrmion_rect);

	//set Bloch skyrmion with given chirality (outside is up: 1, outside is down: -1) in given rectangle (relative to mesh), calculated in the x-y plane
	void SetSkyrmionBloch(int orientation, int chirality, Rect skyrmion_rect);

	//set M from given data VEC (0 values mean empty points) -> stretch data to M dimensions if needed.
	void SetMagFromData(VEC<DBL3>& data, const Rect& dstRect = Rect());

	//----------------------------------- OVERLOAD MESH VIRTUAL METHODS

	//Neel temperature for antiferromagnetic meshes. Calling this forces recalculation of affected material parameters temperature dependence - any custom dependence set will be overwritten.
	void SetCurieTemperature(double Tc, bool set_default_dependences);

	//atomic moment (as multiple of Bohr magneton) for antiferromagnetic meshes. Calling this forces recalculation of affected material parameters temperature dependence - any custom dependence set will be overwritten.
	void SetAtomicMoment(DBL2 atomic_moment_ub);

	//set tau_ii and tau_ij values
	void SetTcCoupling(DBL2 tau_intra, DBL2 tau_inter);
	void SetTcCoupling_Intra(DBL2 tau);
	void SetTcCoupling_Inter(DBL2 tau);

	//get skyrmion shift for a skyrmion initially in the given rectangle (works only with data in data box or output data, not with ShowData)
	//the rectangle must use relative coordinates
	DBL2 Get_skyshift(Rect skyRect)
	{
#if COMPILECUDA == 1
		if (pMeshCUDA) return skyShift.Get_skyshiftCUDA(n.dim(), h, meshRect, pMeshCUDA->M, skyRect);
#endif
		return skyShift.Get_skyshift(M, skyRect);
	}

	//get skyrmion shift for a skyrmion initially in the given rectangle (works only with data in output data, not with ShowData or with data box), as well as diameters along x and y directions.
	DBL4 Get_skypos_diameters(Rect skyRect)
	{
#if COMPILECUDA == 1
		if (pMeshCUDA) return skyShift.Get_skypos_diametersCUDA(n.dim(), h, meshRect, pMeshCUDA->M, skyRect);
#endif
		return skyShift.Get_skypos_diameters(M, skyRect);
	}

	//set/get exchange_couple_to_meshes status flag
	void SetMeshExchangeCoupling(bool status) { exchange_couple_to_meshes = status; }
	bool GetMeshExchangeCoupling(void) { return exchange_couple_to_meshes; }

	//----------------------------------- GETTERS

#if COMPILECUDA == 1
	//get reference to stored differential equation object (meshODE)
	DifferentialEquation& Get_DifferentialEquation(void) { return meshODE; }
#endif
};

#else

class AFMesh :
	public Mesh
{

private:

	//The set ODE, associated with this ferromagnetic mesh (the ODE type and evaluation method is controlled from SuperMesh)
	DifferentialEquationAFM meshODE;

public:

	//constructor taking only a SuperMesh pointer (SuperMesh is the owner) only needed for loading : all required values will be set by LoadObjectState method in ProgramState
	AFMesh(SuperMesh *pSMesh_) :
		Mesh(MESH_ANTIFERROMAGNETIC, pSMesh_),
		meshODE(this)
	{}

	AFMesh(Rect meshRect_, DBL3 h_, SuperMesh *pSMesh_) :
		Mesh(MESH_ANTIFERROMAGNETIC, pSMesh_),
		meshODE(this)
	{}

	~AFMesh() {}

	//----------------------------------- INITIALIZATION

	//----------------------------------- IMPORTANT CONTROL METHODS

	//call when a configuration change has occurred - some objects might need to be updated accordingly
	BError UpdateConfiguration(UPDATECONFIG_ cfgMessage) { return BError(); }
	void UpdateConfiguration_Values(UPDATECONFIG_ cfgMessage) {}

	BError SwitchCUDAState(bool cudaState) { return BError(); }

	//called at the start of each iteration
	void PrepareNewIteration(void) {}

#if COMPILECUDA == 1
	void PrepareNewIterationCUDA(void) {}
#endif

	//Check if mesh needs to be moved (using the MoveMesh method) - return amount of movement required (i.e. parameter to use when calling MoveMesh).
	double CheckMoveMesh(void) { return 0.0; }

	//----------------------------------- GETTERS

#if COMPILECUDA == 1
	//get reference to stored differential equation object (meshODE)
	DifferentialEquation& Get_DifferentialEquation(void) { return meshODE; }
#endif
};

#endif