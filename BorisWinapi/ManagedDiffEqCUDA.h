#pragma once

#include "Boris_Enums_Defs.h"
#if COMPILECUDA == 1

#include "BorisCUDALib.h"
#include "Mesh_FerromagneticCUDA.h"

#include "ErrorHandler.h"

class DifferentialEquationCUDA;

//This holds pointers to managed objects in DiffEqCUDA : set and forget. They are available for use in cuda kernels by passing a cu_obj-managed object ManagedDiffEqCUDA

class ManagedDiffEqCUDA {

	typedef cuReal3(ManagedDiffEqCUDA::*pODE_t)(int);

public:

	//Pointers to data in ODECommonCUDA

	cuReal* pdT;
	cuReal* pdT_last;
	
	cuReal* pmxh;
	cuReal3* pmxh_av;
	size_t* pavpoints;
	
	cuReal* plte;
	
	bool* prenormalize;
	
	bool* psolve_spin_current;
	
	int* psetODE;
	
	bool* palternator;

	//Pointers to data in DifferentialEquationCUDA

	//Used for Trapezoidal Euler, RK4, ABM
	cuVEC<cuReal3>* psM1;

	//Used for RK4 (0, 1, 2); ABM (0, 1)
	cuVEC<cuReal3>* psEval0;
	cuVEC<cuReal3>* psEval1;
	cuVEC<cuReal3>* psEval2;

	//Additional for use with RKF45
	cuVEC<cuReal3>* psEval3;
	cuVEC<cuReal3>* psEval4;

	//Thermal field and torques, enabled only for the stochastic equations
	cuVEC<cuReal3>* pH_Thermal;
	cuVEC<cuReal3>* pTorque_Thermal;

	//Managed cuda mesh pointer so all mesh data can be accessed in device code
	ManagedMeshCUDA* pcuMesh;

	//pointer to device methods ODEs
	pODE_t pODEFunc;

public:

	//---------------------------------------- CONSTRUCTION

	__host__ void construct_cu_obj(void) {}

	__host__ void destruct_cu_obj(void) {}

	__host__ BError set_pointers(DifferentialEquationCUDA* pDiffEqCUDA);

	//---------------------------------------- EQUATIONS : DiffEq_EquationsCUDA.h and DiffEq_SEquationsCUDA.h
	
	//Landau-Lifshitz-Gilbert equation
	__device__ cuReal3 LLG(int idx);

	//Landau-Lifshitz-Gilbert equation with Zhang-Li STT
	__device__ cuReal3 LLGSTT(int idx);

	//Landau-Lifshitz-Bloch equation
	__device__ cuReal3 LLB(int idx);
	
	//Landau-Lifshitz-Bloch equation with Zhang-Li STT
	__device__ cuReal3 LLBSTT(int idx);
	
	//Stochastic Landau-Lifshitz-Gilbert equation
	__device__ cuReal3 SLLG(int idx);

	//Stochastic Landau-Lifshitz-Gilbert equation with Zhang-Li STT
	__device__ cuReal3 SLLGSTT(int idx);

	//Stochastic Landau-Lifshitz-Bloch equation
	__device__ cuReal3 SLLB(int idx);

	//Stochastic Landau-Lifshitz-Bloch equation with Zhang-Li STT
	__device__ cuReal3 SLLBSTT(int idx);

	//---------------------------------------- GETTERS

	//return dM by dT - should only be used when evaluation sequence has ended (TimeStepSolved() == true)
	__device__ cuReal3 dMdt(int idx) { return ((*(pcuMesh->pM))[idx] - (*psM1)[idx]) / *pdT_last; }
};

#endif