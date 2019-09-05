#include "stdafx.h"
#include "Simulation.h"

void Simulation::AddGenericStage(SS_ stageType, string meshName) 
{
	switch(stageType) {

	case SS_RELAX:
	{
		StageConfig stageConfig = StageConfig(stageDescriptors(stageType), stageStopDescriptors(STOP_MXH));
		stageConfig.set_stopvalue(1e-4);

		simStages.push_back(stageConfig);
	}
	break;

	case SS_HFIELDXYZ:
	{
		//zero field with STOP_MXH
		StageConfig stageConfig = StageConfig(stageDescriptors(stageType), stageStopDescriptors(STOP_MXH), meshName);
		stageConfig.set_value( DBL3(0, 0, 0) );
		stageConfig.set_stopvalue(1e-4);

		simStages.push_back(stageConfig);
	}
	break;

	case SS_HFIELDXYZSEQ:
	{
		//zero field with STOP_MXH
		StageConfig stageConfig = StageConfig(stageDescriptors(stageType), stageStopDescriptors(STOP_MXH), meshName);
		stageConfig.set_value( SEQ3(DBL3(-1e5, 0, 0), DBL3(1e5, 0, 0), 100) );
		stageConfig.set_stopvalue(1e-4);

		simStages.push_back(stageConfig);
	}
	break;

	case SS_HPOLARSEQ:
	{
		//zero field with STOP_MXH
		StageConfig stageConfig = StageConfig(stageDescriptors(stageType), stageStopDescriptors(STOP_MXH), meshName);
		stageConfig.set_value(SEQP(DBL3(-1e5, 90, 0), DBL3(1e5, 90, 0), 100));
		stageConfig.set_stopvalue(1e-4);

		simStages.push_back(stageConfig);
	}
	break;

	case SS_HFMR:
	{
		//Bias field along y with Hrf along x. 1 GHz.
		StageConfig stageConfig = StageConfig(stageDescriptors(stageType), stageStopDescriptors(STOP_TIME), meshName);
		stageConfig.set_value(COSSEQ3(DBL3(0, 1e6, 0), DBL3(1e3, 0, 0), 20, 100));
		stageConfig.set_stopvalue(50e-12);

		simStages.push_back(stageConfig);
	}
	break;
	
	case SS_V:
	{
		//zero potential with STOP_MXH
		StageConfig stageConfig = StageConfig(stageDescriptors(stageType), stageStopDescriptors(STOP_MXH));
		stageConfig.set_value(0.0);
		stageConfig.set_stopvalue(1e-4);

		simStages.push_back(stageConfig);
	}
	break;

	case SS_VSEQ:
	{
		//V 0.0 to 1.0 V in 10 steps with STOP_MXH
		StageConfig stageConfig = StageConfig(stageDescriptors(stageType), stageStopDescriptors(STOP_MXH));
		stageConfig.set_value(SEQ(0.0, 1.0, 10));
		stageConfig.set_stopvalue(1e-4);

		simStages.push_back(stageConfig);
	}
	break;

	case SS_VSIN:
	{
		//10 mV oscillation 1 GHz for 100 cycles
		StageConfig stageConfig = StageConfig(stageDescriptors(stageType), stageStopDescriptors(STOP_TIME));
		stageConfig.set_value(SINOSC(10e-3, 20, 100));
		stageConfig.set_stopvalue(50e-12);

		simStages.push_back(stageConfig);
	}
	break;

	case SS_VCOS:
	{
		//10 mV oscillation 1 GHz for 100 cycles
		StageConfig stageConfig = StageConfig(stageDescriptors(stageType), stageStopDescriptors(STOP_TIME));
		stageConfig.set_value(COSOSC(10e-3, 20, 100));
		stageConfig.set_stopvalue(50e-12);

		simStages.push_back(stageConfig);
	}
	break;

	case SS_I:
	{
		//zero current with STOP_MXH
		StageConfig stageConfig = StageConfig(stageDescriptors(stageType), stageStopDescriptors(STOP_MXH));
		stageConfig.set_value(0.0);
		stageConfig.set_stopvalue(1e-4);

		simStages.push_back(stageConfig);
	}
	break;

	case SS_ISEQ:
	{
		//I 0.0 to 1.0 mA in 10 steps with STOP_MXH
		StageConfig stageConfig = StageConfig(stageDescriptors(stageType), stageStopDescriptors(STOP_MXH));
		stageConfig.set_value(SEQ(0.0, 1.0e-3, 10));
		stageConfig.set_stopvalue(1e-4);

		simStages.push_back(stageConfig);
	}
	break;

	case SS_ISIN:
	{
		//1 mA oscillation 1 GHz for 100 cycles
		StageConfig stageConfig = StageConfig(stageDescriptors(stageType), stageStopDescriptors(STOP_TIME));
		stageConfig.set_value(SINOSC(1e-3, 20, 100));
		stageConfig.set_stopvalue(50e-12);

		simStages.push_back(stageConfig);
	}
	break;

	case SS_ICOS:
	{
		//1 mA oscillation 1 GHz for 100 cycles
		StageConfig stageConfig = StageConfig(stageDescriptors(stageType), stageStopDescriptors(STOP_TIME));
		stageConfig.set_value(COSOSC(1e-3, 20, 100));
		stageConfig.set_stopvalue(50e-12);

		simStages.push_back(stageConfig);
	}
	break;

	case SS_T:
	{
		//zero temperature with STOP_MXH
		StageConfig stageConfig = StageConfig(stageDescriptors(stageType), stageStopDescriptors(STOP_MXH), meshName);
		stageConfig.set_value(0.0);
		stageConfig.set_stopvalue(1e-4);

		simStages.push_back(stageConfig);
	}
	break;

	case SS_TSEQ:
	{
		//T 0.0 to 300K in 10 steps with STOP_MXH
		StageConfig stageConfig = StageConfig(stageDescriptors(stageType), stageStopDescriptors(STOP_MXH), meshName);
		stageConfig.set_value(SEQ(0.0, 300.0, 10));
		stageConfig.set_stopvalue(1e-4);

		simStages.push_back(stageConfig);
	}
	break;
	}
}

void Simulation::DeleteStage(int stageIndex) 
{
	simStages.erase(stageIndex);
}

void Simulation::SetGenericStopCondition(int index, STOP_ stopType) 
{
	if(!GoodIdx(simStages.last(), index)) return;

	switch(stopType) {

	case STOP_NOSTOP:
		simStages[index].set_stoptype( stageStopDescriptors(stopType) );
		simStages[index].clear_stopvalue();
		break;

	case STOP_ITERATIONS:
		simStages[index].set_stoptype( stageStopDescriptors(stopType) );
		simStages[index].set_stopvalue(1000);
		break;

	case STOP_MXH:
		simStages[index].set_stoptype( stageStopDescriptors(stopType) );
		simStages[index].set_stopvalue(1e-4);
		break;

	case STOP_DMDT:
		simStages[index].set_stoptype(stageStopDescriptors(stopType));
		simStages[index].set_stopvalue(1e-5);
		break;

	case STOP_TIME:
		simStages[index].set_stoptype( stageStopDescriptors(stopType) );
		simStages[index].set_stopvalue(10e-9);
		break;
	}
}

void Simulation::SetGenericDataSaveCondition(int index, DSAVE_ dsaveType)
{
	switch(dsaveType) {

	case DSAVE_NONE:
		simStages[index].set_dsavetype( dataSaveDescriptors(dsaveType) );
		simStages[index].clear_dsavevalue();
		break;

	case DSAVE_STAGE:
		simStages[index].set_dsavetype( dataSaveDescriptors(dsaveType) );
		simStages[index].clear_dsavevalue();
		break;

	case DSAVE_STEP:
		simStages[index].set_dsavetype( dataSaveDescriptors(dsaveType) );
		simStages[index].clear_dsavevalue();
		break;

	case DSAVE_ITER:
		simStages[index].set_dsavetype( dataSaveDescriptors(dsaveType) );
		simStages[index].set_dsavevalue(100);
		break;

	case DSAVE_TIME:
		simStages[index].set_dsavetype( dataSaveDescriptors(dsaveType) );
		simStages[index].set_dsavevalue(1e-9);
		break;
	}
}

void Simulation::EditStageType(int index, SS_ stageType, string meshName) 
{
	//if same stage type as before just change the mesh name
	if(GoodIdx(simStages.last(), index) && simStages[index].stage_type() == stageType) {
		
		simStages[index].set_meshname(meshName);

	}
	else {

		//new stage type at this index so set a generic stage to start off with
		AddGenericStage(stageType, meshName);
		simStages.move(simStages.last(), index);
		simStages.erase(index + 1);
	}
}

void Simulation::EditStageValue(int stageIndex, string value_string) 
{
	simStages[stageIndex].set_stagevalue_fromstring(value_string);
}

void Simulation::EditStageStopCondition(int index, STOP_ stopType, string stopValueString) 
{
	//if same stop condition as before just change the stop value
	if(GoodIdx(simStages.last(), index) && simStages[index].stop_condition() == stopType) {

		if(stopValueString.length()) simStages[index].set_stopvalue_fromstring(stopValueString);
	}
	else {

		SetGenericStopCondition(index, stopType);
		if(stopValueString.length()) simStages[index].set_stopvalue_fromstring(stopValueString);
	}
}

void Simulation::EditDataSaveCondition(int index, DSAVE_ dsaveType, string dsaveValueString)
{
	//if same saving condition as before just change the value
	if(GoodIdx(simStages.last(), index) && simStages[index].dsave_type() == dsaveType) {

		if(dsaveValueString.length()) simStages[index].set_dsavevalue_fromstring(dsaveValueString);
	}
	else {

		SetGenericDataSaveCondition(index, dsaveType);
		if(dsaveValueString.length()) simStages[index].set_dsavevalue_fromstring(dsaveValueString);
	}
}

void Simulation::UpdateStageMeshNames(string oldMeshName, string newMeshName) 
{
	for(int idx = 0; idx < simStages.size(); idx++) {

		if (simStages[idx].meshname() == oldMeshName) {

			simStages[idx].set_meshname(newMeshName);
		}
	}
}

INT2 Simulation::Check_and_GetStageStep()
{
	//first make sure stage value is correct - this could only happen if stages have been deleted. If incorrect just reset back to 0.
	if(stage_step.major >= simStages.size()) stage_step = INT2();

	//mak sure step value is correct - if incorrect reset back to zero.
	if(stage_step.minor > simStages[stage_step.major].number_of_steps()) stage_step.minor = 0;

	return stage_step;
}

void Simulation::CheckSimulationSchedule(void) 
{
	//if stage index exceeds number of stages then just set it to the end : stages must have been deleted whilst simulation running.
	if(stage_step.major >= simStages.size()) stage_step.major = simStages.last();

	switch( simStages[ stage_step.major ].stop_condition() ) {

	case STOP_NOSTOP:
		break;

	case STOP_ITERATIONS:

		if( SMesh.GetStageIteration() >= (int)simStages[ stage_step.major ].get_stopvalue() ) AdvanceSimulationSchedule();
		break;

	case STOP_MXH:

		if( SMesh.Get_mxh() <= (double)simStages[ stage_step.major ].get_stopvalue() ) AdvanceSimulationSchedule();
		break;

	case STOP_DMDT:

		if (SMesh.Get_dmdt() <= (double)simStages[stage_step.major].get_stopvalue()) AdvanceSimulationSchedule();
		break;

	case STOP_TIME:

		if( SMesh.GetStageTime() >= (double)simStages[ stage_step.major ].get_stopvalue() ) AdvanceSimulationSchedule();
		break;
	}
}

void Simulation::CheckSaveDataCondtions() 
{
	switch (simStages[stage_step.major].dsave_type()) {

	case DSAVE_NONE:
	case DSAVE_STAGE:
	case DSAVE_STEP:
		//step and stage save data is done in AdvanceSimulationSchedule when step or stage ending is detected
		break;

	case DSAVE_ITER:
		if (!(SMesh.GetIteration() % (int)simStages[stage_step.major].get_dsavevalue())) SaveData();
		break;

	case DSAVE_TIME:
	{
		double time = SMesh.GetTime();
		double tsave = (double)simStages[stage_step.major].get_dsavevalue();
		double dT = SMesh.GetTimeStep();

		//the floor_epsilon is important - don't use floor!
		//the reason for this, if time / tsave ends up being very close, but slightly less, than an integer, e.g. 1.999 due to a floating point error, then floor will round it down, whereas really it should be rounded up.
		//thus with floor only you can end up not saving data points where you should be.
		//Also the *0.99 below is important : if using just delta < dT check, delta can be slightly smaller than dT but within a floating point error close to it - thus we end up double-saving some data points!
		//this happens especially if tsave / dT is an integer -> thus most of the time.
		double delta = time - floor_epsilon(time / tsave) * tsave;
		if (delta < dT * 0.99) SaveData();
	}
		break;
	}
}

void Simulation::AdvanceSimulationSchedule(void) 
{
	//assume stage_step.major is correct

	//do we need to iterate the transport solver? 
	//if static_transport_solver is true then the transport solver was stopped from iterating before reaching the end of a stage or step
	if (static_transport_solver) {

		//turn off flag for now to enable iterating the transport solver
		static_transport_solver = false;

#if COMPILECUDA == 1
		if (cudaEnabled) {

			SMesh.UpdateTransportSolverCUDA();
		}
		else {

			SMesh.UpdateTransportSolver();
		}
#else
		SMesh.UpdateTransportSolver();
#endif

		//turn flag back on
		static_transport_solver = true;
	}

	//first try to increment the step number
	if(stage_step.minor < simStages[stage_step.major].number_of_steps()) {

		//save data at end of current step?
		if(simStages[stage_step.major].dsave_type() == DSAVE_STEP) SaveData();

		//next step and set value for it
		stage_step.minor++;
		SetSimulationStageValue();
	}
	else {

		//save data at end of current stage?
		if(simStages[stage_step.major].dsave_type() == DSAVE_STAGE ||
		   simStages[stage_step.major].dsave_type() == DSAVE_STEP) 
			SaveData();

		//next stage
		stage_step.major++;
		stage_step.minor = 0;

		//if not at the end then set stage value for given stage_step
		if(stage_step.major < simStages.size()) {

			SetSimulationStageValue();
		}
		else {

			//schedule reached end: stop simulation. Note, since this routine is called from Simulate routine, which runs on the THREAD_LOOP thread, cannot stop THREAD_LOOP from within it: stop it from another thread.
			single_call_launch(&Simulation::StopSimulation, THREAD_HANDLEMESSAGE);

			//back to 0, 0
			stage_step = INT2();
		}
	}
}

void Simulation::SetSimulationStageValue(void) {

	SMesh.NewStageODE();

	//assume stage_step is correct (if called from AdvanceSimulationSchedule it will be. could also be called directly at the start of a simulation with stage_step reset, so it's also correct).

	switch( simStages[stage_step.major].stage_type() ) {

	case SS_RELAX:
	break;

	case SS_HFIELDXYZ:
	case SS_HFIELDXYZSEQ:
	case SS_HPOLARSEQ:
	case SS_HFMR:
	{
		string meshName = simStages[stage_step.major].meshname();

		DBL3 appliedField = simStages[stage_step.major].get_value<DBL3>(stage_step.minor);

		if (SMesh.contains(meshName)) SMesh[meshName]->CallModuleMethod(&Zeeman::SetField, appliedField);
		else if (meshName == SMesh.superMeshHandle) {

			for (int idx = 0; idx < SMesh.size(); idx++) {
				SMesh[idx]->CallModuleMethod(&Zeeman::SetField, appliedField);
			}
		}
	}
	break;

	case SS_V:
	case SS_VSEQ:
	case SS_VSIN:
	case SS_VCOS:
	{
		double potential = simStages[stage_step.major].get_value<double>(stage_step.minor);

		SMesh.CallModuleMethod(&STransport::SetPotential, potential);
	}
	break;

	case SS_I:
	case SS_ISEQ:
	case SS_ISIN:
	case SS_ICOS:
	{
		double current = simStages[stage_step.major].get_value<double>(stage_step.minor);

		SMesh.CallModuleMethod(&STransport::SetCurrent, current);
	}
	break;

	case SS_T:
	case SS_TSEQ:
	{
		string meshName = simStages[stage_step.major].meshname();

		double temperature = simStages[stage_step.major].get_value<double>(stage_step.minor);

		if (SMesh.contains(meshName)) SMesh[meshName]->SetBaseTemperature(temperature);
		else if (meshName == SMesh.superMeshHandle) {

			//all meshes
			for (int idx = 0; idx < SMesh.size(); idx++) {

				SMesh[idx]->SetBaseTemperature(temperature);
			}
		}
	}
	break;
	}
}