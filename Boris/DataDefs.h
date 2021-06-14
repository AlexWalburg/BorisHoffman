#pragma once

//Simulation data available as outputs - add new entries at the end to keep older simulation files compatible
enum DATA_
{
	DATA_NONE = 0,
	DATA_STAGESTEP, DATA_TIME, DATA_STAGETIME, DATA_ITERATIONS, DATA_SITERATIONS, DATA_DT, DATA_MXH,
	DATA_AVM, DATA_HA,
	DATA_JC, DATA_JSX, DATA_JSY, DATA_JSZ, DATA_V, DATA_S, DATA_ELC, DATA_POTENTIAL, DATA_CURRENT, DATA_RESISTANCE,
	DATA_E_DEMAG, DATA_E_EXCH, DATA_E_SURFEXCH, DATA_E_ZEE, DATA_E_ANIS, DATA_E_ROUGH,
	DATA_DWSHIFT, DATA_SKYSHIFT,
	DATA_TRANSPORT_ITERSTOCONV, DATA_TRANSPORT_SITERSTOCONV, DATA_TRANSPORT_CONVERROR,
	DATA_TEMP, DATA_HEATDT,
	DATA_E_TOTAL,
	DATA_DMDT, DATA_SKYPOS,
	DATA_AVM2,
	DATA_E_MELASTIC,
	DATA_TEMP_L,

	//Previously used by DATA_E_EXCH_MAX, now deleted
	DATA_RESERVED,

	DATA_Q_TOPO,
	DATA_MX_MINMAX, DATA_MY_MINMAX, DATA_MZ_MINMAX, DATA_M_MINMAX,
	DATA_DWPOS_X, DATA_DWPOS_Y, DATA_DWPOS_Z,
	DATA_MONTECARLOPARAMS,
	DATA_E_MOPTICAL,
	DATA_RESPUMP, DATA_IMSPUMP, DATA_RESPUMP2, DATA_IMSPUMP2
};