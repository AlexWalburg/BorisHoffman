#include "stdafx.h"
#include "Simulation.h"

//MAIN SIMULATION LOOP. Runs in SimulationThread launched in BorisWinapi.
void Simulation::Simulate(void)
{
	//stop other parts of the program from changing simulation parameters in the middle of an interation
	//non-blocking mutex is needed here so we can stop the simulation from HandleCommand - it also uses the simulationMutex. If Simulation thread gets blocked by this mutex they'll wait on each other forever.
	if (simulationMutex.try_lock()) {

		//Check conditions for saving data
		CheckSaveDataConditions();

		//advance time for this iteration
#if COMPILECUDA == 1
		if (cudaEnabled) SMesh.AdvanceTimeCUDA();
		else SMesh.AdvanceTime();
#else
		SMesh.AdvanceTime();
#endif

		//Display update
		if (iterUpdate && SMesh.GetIteration() % iterUpdate == 0) UpdateScreen_Quick();

		//Check conditions for advancing simulation schedule
		CheckSimulationSchedule();

		//finished this iteration
		simulationMutex.unlock();

		//THREAD_HANDLEMESSAGE is used to run HandleCommand, which also uses simulationMutex to guard access.
		//With Visual Studio 2017 v141 toolset : without the short wait below, when HandleCommand has been called, simulationMutex will block access for a long time as this Simulate method gets called over and over again on its thread.
		//This means the command gets executed very late (ten seconds not unusual) - not good!
		//This wasn't a problem with Visual Studio 2012, v110 or v120 toolset. Maybe with the VS2017 compiler the calls to Simulate on the infinite loop thread are all inlined. 
		//Effectively there is almost no delay between unlocking and locking the mutex again on the next iteration - THREAD_HANDLEMESSAGE cannot sneak in to lock simulationMutex easily!
		if (is_thread_running(THREAD_HANDLEMESSAGE)) Sleep(1);
	}
}

//Similar to Simulate but only runs for one iteration and does not advance time
void Simulation::ComputeFields(void)
{
	if (is_thread_running(THREAD_LOOP)) {

		StopSimulation();
	}
	else {

		BD.DisplayConsoleMessage("Initializing modules...");

		bool initialization_error;

		if (!cudaEnabled) {

			initialization_error = err_hndl.qcall(&SuperMesh::InitializeAllModules, &SMesh);
		}
		else {

#if COMPILECUDA == 1
			initialization_error = err_hndl.qcall(&SuperMesh::InitializeAllModulesCUDA, &SMesh);
#endif
		}

		if (initialization_error) {

			BD.DisplayConsoleError("Failed to initialize simulation.");
			return;
		}
	}

	BD.DisplayConsoleMessage("Initialized. Updating fields.");

	//advance time for this iteration
#if COMPILECUDA == 1
	if (cudaEnabled) SMesh.ComputeFieldsCUDA();
	else SMesh.ComputeFields();
#else
	SMesh.ComputeFields();
#endif

	//Display update
	UpdateScreen();

	BD.DisplayConsoleMessage("Fields updated.");
}

void Simulation::RunSimulation(void)
{
	if (is_thread_running(THREAD_LOOP)) {

		BD.DisplayConsoleMessage("Simulation already running.");
		return;
	}

	BD.DisplayConsoleMessage("Initializing modules...");

	bool initialization_error;

	if (!cudaEnabled) {

		initialization_error = err_hndl.qcall(&SuperMesh::InitializeAllModules, &SMesh);
	}
	else {
#if COMPILECUDA == 1
		initialization_error = err_hndl.qcall(&SuperMesh::InitializeAllModulesCUDA, &SMesh);
#endif
	}

	if (initialization_error) {

		BD.DisplayConsoleError("Failed to initialize simulation.");
		return;
	}

	//set initial stage values if at the beginning (stage = 0, step = 0, and stageiteration = 0)
	if (Check_and_GetStageStep() == INT2()) {

		if (SMesh.GetStageIteration() == 0) {

			SetSimulationStageValue();
			appendToDataFile = false;
		}
	}

	infinite_loop_launch(&Simulation::Simulate, THREAD_LOOP);
	BD.DisplayConsoleMessage("Initialized. Simulation running. Started at: " + Get_Date_Time());

	sim_start_ms = GetTickCount();
}

void Simulation::StopSimulation(void)
{
	if (is_thread_running(THREAD_LOOP)) {

		stop_thread(THREAD_LOOP);

		//make sure the current time step is finished, by iterating a bit more if necessary, before relinquishing control
		while (!SMesh.CurrentTimeStepSolved()) Simulate();

		sim_end_ms = GetTickCount();

		BD.DisplayConsoleMessage("Simulation stopped. " + Get_Date_Time());

		//if client connected, signal simulation has finished
		commSocket.SetSendData({ "stopped" });
		commSocket.SendDataParams();

		UpdateScreen();
	}
}

void Simulation::ResetSimulation(void)
{
	StopSimulation();

	stage_step = INT2();
	SMesh.ResetODE();

	UpdateScreen();
}