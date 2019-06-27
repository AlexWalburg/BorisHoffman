#include "stdafx.h"
#include "DemagKernelCollection.h"

#ifdef MODULE_SDEMAG

//-------------------------- KERNEL CALCULATION

//this initializes all the convolution kernels for the given mesh dimensions. 2D is for n.z == 1.
BError DemagKernelCollection::Calculate_Demag_Kernels(std::vector<DemagKernelCollection*>& kernelCollection)
{
	BError error(__FUNCTION__);

	for (int index = 0; index < Rect_collection.size(); index++) {

		if (!error) {

			//before allocating and computing kernel, check to see if any other DemagKernelCollection module has not already calculated one like it

			//Rect_collection is in one-to-one correspondence with kernelCollection
			//For a demag kernel to be identical to the one we need, it must have the same shift, same h source and same h destination

			//shift for source as Rect_collection[index] and destination as this_rect
			DBL3 shift = (this_rect.s - Rect_collection[index].s);

			DBL3 h_src = kernelCollection[index]->h;
			DBL3 h_dst = h;
			
			for (int idx = 0; idx < kernelCollection.size(); idx++) {

				shared_ptr<KerType> existing_kernel = kernelCollection[idx]->KernelAlreadyComputed(shift, h_src, h_dst);

				if (existing_kernel != nullptr) {

					//found one : just increase ref count
					kernels[index] = existing_kernel;

					//is it inverse z-shifted?
					if (IsZ(shift.x) && IsZ(shift.y)) {

						if (IsNZ(shift.z) && IsZ(shift.z + kernels[index]->shift.z)) {

							//yes it is. mark it here so we can adjust the kernel multiplications
							inverse_shifted[index] = true;
						}
					}

					break;
				}
			}
			
			if (kernels[index] == nullptr) {

				//no -> allocate then compute it
				kernels[index] = shared_ptr<KerType>(new KerType());
				error = kernels[index]->AllocateKernels(Rect_collection[index], this_rect, N);
				if (error) return error;

				//now compute it
				if (kernels[index]->internal_demag) {

					kernels[index]->shift = DBL3();
					kernels[index]->h_dst = h;
					kernels[index]->h_src = h;

					//use self versions
					if (n.z == 1) error = Calculate_Demag_Kernels_2D_Self(index);
					else error = Calculate_Demag_Kernels_3D_Self(index);
				}
				else {

					//shift for source as Rect_collection[index] and destination as this_rect
					kernels[index]->shift = (this_rect.s - Rect_collection[index].s);
					kernels[index]->h_dst = h;
					kernels[index]->h_src = kernelCollection[index]->h;

					if (n.z == 1) {

						if (IsZ(kernels[index]->shift.x) && IsZ(kernels[index]->shift.y)) {

							//z-shifted kernels for 2D
							error = Calculate_Demag_Kernels_2D_zShifted(index);
						}
						else {

							//general 2D kernels (not z-shifted)
							error = Calculate_Demag_Kernels_2D_Complex_Full(index);
						}
					}
					else {

						if (IsZ(kernels[index]->shift.x) && IsZ(kernels[index]->shift.y)) {

							//z-shifted kernels for 3D
							error = Calculate_Demag_Kernels_3D_zShifted(index);
						}
						else {

							//general 3D kernels (not z-shifted)
							error = Calculate_Demag_Kernels_3D_Complex_Full(index);
						}
					}
				}

				//set flag to say it's been computed so it could be reused if needed
				kernels[index]->kernel_calculated = true;
			}
		}
	}

	return error;
}

//search to find a matching kernel that has already been computed and return pointer to it -> kernel can be identified from shift, source and destination discretisation
shared_ptr<KerType> DemagKernelCollection::KernelAlreadyComputed(DBL3 shift, DBL3 h_src, DBL3 h_dst)
{
	//kernels[index] must not be nullptr, must have kernel_calculated = true and shift, h_src, h_dst must match the corresponding values in kernels[index] 

	for (int idx = 0; idx < kernels.size(); idx++) {

		if (kernels[idx] && kernels[idx]->kernel_calculated) {

			//match in source and destination cellsizes?
			if (kernels[idx]->h_src == h_src && kernels[idx]->h_dst == h_dst) {

				//do the shifts match?
				if (kernels[idx]->shift == shift) {

					return kernels[idx];
				}

				//are the shifts z shifts that differ only in sign? Only applies in 2D mode.
				if (N.z == 1 && IsZ(shift.x) && IsZ(shift.y) && IsZ(kernels[idx]->shift.x) && IsZ(kernels[idx]->shift.y) && IsZ(shift.z + kernels[idx]->shift.z)) {

					return kernels[idx];
				}
			}
		}
	}

	return nullptr;
}

//2D kernels (Kdiag_real, and K2D_odiag, with full use of kernel symmetries)
BError DemagKernelCollection::Calculate_Demag_Kernels_2D_Self(int index)
{
	BError error(__FUNCTION__);

	//-------------- CALCULATE DEMAG TENSOR

	//Demag tensor components
	//
	// D11 D12 0
	// D12 D22 0
	// 0   0   D33

	//Ddiag : D11, D22, D33 are the diagonal tensor elements
	VEC<DBL3> Ddiag;
	if (!Ddiag.resize(N)) return error(BERROR_OUTOFMEMORY_NCRIT);

	//off-diagonal tensor elements
	vector<double> Dodiag;
	if (!malloc_vector(Dodiag, N.x*N.y)) return error(BERROR_OUTOFMEMORY_NCRIT);

	//use ratios instead of cellsizes directly - same result but better in terms of floating point errors
	DemagTFunc dtf;

	if (!dtf.CalcDiagTens2D(Ddiag, n, N, h / h_max)) return error(BERROR_OUTOFMEMORY_NCRIT);
	if (!dtf.CalcOffDiagTens2D(Dodiag, n, N, h / h_max)) return error(BERROR_OUTOFMEMORY_NCRIT);

	//-------------- SETUP FFT

	//setup fft object with fft computation lines
	FFTMethods_Cpp<double> fft;

	size_t maxN = maximum(N.x / 2 + 1, N.y / 2 + 1);

	vector<ReIm3> fft_line(maxN);
	vector<ReIm3> fft_line2(maxN);
	vector<ReIm> fft_line2d(maxN);
	vector<ReIm> fft_line2d2(maxN);

	//-------------- FFT REAL TENSOR INTO REAL KERNELS

	//NOTE : don't use parallel for loops as it will mess up the packing in the D tensor
	//If you want parallel loops you'll need to allocate additional temporary spaces, so not worth it for initialization
	//rather have slightly slower initialization than fail due to running out of memory for large problem sizes

	//FFT into Kernel forms ready for convolution multiplication
	for (int j = 0; j < N.y; j++) {

		fft.CopyRealShuffle(Ddiag.data() + j * N.x, fft_line.data(), N.x / 2);
		fft.FFT_Radix4_DIT(fft_line.data(), log2(N.x) - 1, N.x / 2);
		fft.RealfromComplexFFT(fft_line.data(), fft_line2.data(), N.x / 2);

		fft.CopyRealShuffle(Dodiag.data() + j * N.x, fft_line2d.data(), N.x / 2);
		fft.FFT_Radix4_DIT(fft_line2d.data(), log2(N.x) - 1, N.x / 2);
		fft.RealfromComplexFFT(fft_line2d.data(), fft_line2d2.data(), N.x / 2);

		//pack into Ddiag and Dodiag for next step
		for (int i = 0; i < N.x / 2 + 1; i++) {

			//even w.r.t. to x so output is purely real
			Ddiag[i + j * (N.x / 2 + 1)] = DBL3(fft_line2[i].x.Re, fft_line2[i].y.Re, fft_line2[i].z.Re);

			//odd w.r.t. to x so output is purely imaginary
			Dodiag[i + j * (N.x / 2 + 1)] = fft_line2d2[i].Im;
		}
	}

	for (int i = 0; i < N.x / 2 + 1; i++) {

		fft.CopyRealShuffle(Ddiag.data() + i, fft_line.data(), N.x / 2 + 1, N.y / 2);
		fft.FFT_Radix4_DIT(fft_line.data(), log2(N.y) - 1, N.y / 2);
		fft.RealfromComplexFFT(fft_line.data(), fft_line2.data(), N.y / 2);

		//the input sequence should actually be purely imaginary not purely real (but see below)
		fft.CopyRealShuffle(Dodiag.data() + i, fft_line2d.data(), N.x / 2 + 1, N.y / 2);
		fft.FFT_Radix4_DIT(fft_line2d.data(), log2(N.y) - 1, N.y / 2);
		fft.RealfromComplexFFT(fft_line2d.data(), fft_line2d2.data(), N.y / 2);

		//pack into output real kernels with reduced strides
		for (int j = 0; j < N.y / 2 + 1; j++) {

			//even w.r.t. y so output is purely real
			kernels[index]->Kdiag_real[i + j * (N.x / 2 + 1)] = DBL3(fft_line2[j].x.Re, fft_line2[j].y.Re, fft_line2[j].z.Re);

			//odd w.r.t. y so the purely imaginary input becomes purely real
			//however since we used CopyRealShuffle and RealfromComplexFFT, i.e. treating the input as purely real rather than purely imaginary we need to account for the i * i = -1 term, hence the - sign below
			kernels[index]->K2D_odiag[i + j * (N.x / 2 + 1)] = -fft_line2d2[j].Im;
		}
	}

	return error;
}

//2D layers, z shift only : Kernels can be stored as real with use of kernel symmetries. Kxx, Kyy, Kzz, Kxy real, Kxz, Kyz imaginary
BError DemagKernelCollection::Calculate_Demag_Kernels_2D_zShifted(int index)
{
	BError error(__FUNCTION__);

	//-------------- DEMAG TENSOR

	//Demag tensor components
	//
	// D11 D12 D13
	// D12 D22 D23
	// D13 D23 D33

	//D11, D22, D33 are the diagonal tensor elements
	//D12, D13, D23 are the off-diagonal tensor elements
	VEC<DBL3> D;

	if (!D.resize(N)) return error(BERROR_OUTOFMEMORY_NCRIT);

	//object used to compute tensor elements
	DemagTFunc dtf;

	//-------------- FFT SETUP

	//setup fft object with fft computation lines
	FFTMethods_Cpp<double> fft;

	size_t maxN = maximum(N.x / 2 + 1, N.y, N.z);

	vector<ReIm3> fft_line(maxN);
	vector<ReIm3> fft_line2(maxN);

	//lambda used to transform an input tensor into an output kernel
	auto tensor_to_kernel = [&](VEC<DBL3>& tensor, VEC<DBL3>& kernel, bool off_diagonal) -> void {

		//-------------- FFT REAL TENSOR

		//NOTE : don't use parallel for loops as it will mess up the packing in the D tensor
		//If you want parallel loops you'll need to allocate additional temporary spaces, so not worth it for initialization
		//rather have slightly slower initialization than fail due to running out of memory for large problem sizes

		//FFT into Kernel forms ready for convolution multiplication - diagonal components
		for (int j = 0; j < N.y; j++) {

			fft.CopyRealShuffle(tensor.data() + j * N.x, fft_line.data(), N.x / 2);
			fft.FFT_Radix4_DIT(fft_line.data(), log2(N.x) - 1, N.x / 2);
			fft.RealfromComplexFFT(fft_line.data(), fft_line2.data(), N.x / 2);

			if (!off_diagonal) {

				//diagonal elements even in x

				//pack into tensor
				for (int i = 0; i < N.x / 2 + 1; i++) {

					tensor[i + j * (N.x / 2 + 1)] = DBL3(fft_line2[i].x.Re, fft_line2[i].y.Re, fft_line2[i].z.Re);
				}
			}
			else {

				//Nxy, Nxz odd in x, Nyz even in x

				//pack into tensor
				for (int i = 0; i < N.x / 2 + 1; i++) {

					tensor[i + j * (N.x / 2 + 1)] = DBL3(fft_line2[i].x.Im, fft_line2[i].y.Im, fft_line2[i].z.Re);
				}
			}
		}

		for (int i = 0; i < N.x / 2 + 1; i++) {

			fft.CopyRealShuffle(tensor.data() + i, fft_line.data(), N.x / 2 + 1, N.y / 2);
			fft.FFT_Radix4_DIT(fft_line.data(), log2(N.y) - 1, N.y / 2);
			fft.RealfromComplexFFT(fft_line.data(), fft_line2.data(), N.y / 2);

			if (!off_diagonal) {

				//pack into output real kernels
				for (int j = 0; j < N.y / 2 + 1; j++) {

					kernel[i + j * (N.x / 2 + 1)] = DBL3(fft_line2[j].x.Re, fft_line2[j].y.Re, fft_line2[j].z.Re);
				}
			}
			else {

				//Nxy odd in y, Nxz even in y, Nyz odd in y

				//pack into output real kernels
				for (int j = 0; j < N.y / 2 + 1; j++) {

					//adjust for i * i = -1 in Nxy element
					kernel[i + j * (N.x / 2 + 1)] = DBL3(-fft_line2[j].x.Im, fft_line2[j].y.Re, fft_line2[j].z.Im);
				}
			}
		}
	};

	//-------------- CALCULATE DIAGONAL TENSOR ELEMENTS THEN TRANSFORM INTO KERNEL

	//no need to pass the actual cellsize values, just normalized values will do

	if (!dtf.CalcDiagTens2D_Shifted_Irregular(D, n, N, kernels[index]->h_src / h_max, kernels[index]->h_dst / h_max, kernels[index]->shift / h_max)) return error(BERROR_OUTOFMEMORY_NCRIT);

	tensor_to_kernel(D, kernels[index]->Kdiag_real, false);

	//-------------- CALCULATE OFF-DIAGONAL TENSOR ELEMENTS THEN TRANSFORM INTO KERNEL

	//important to zero D before calculating new tensor elements
	D.set(DBL3());

	if (!dtf.CalcOffDiagTens2D_Shifted_Irregular(D, n, N, kernels[index]->h_src / h_max, kernels[index]->h_dst / h_max, kernels[index]->shift / h_max)) return error(BERROR_OUTOFMEMORY_NCRIT);

	tensor_to_kernel(D, kernels[index]->Kodiag_real, true);

	//Done
	return error;
}

//2D layers, complex kernels most general case (Kdiag_cmpl, and Kodiag_cmpl, without any kernel symmetries)
BError DemagKernelCollection::Calculate_Demag_Kernels_2D_Complex_Full(int index)
{
	BError error(__FUNCTION__);

	//-------------- DEMAG TENSOR

	//Demag tensor components
	//
	// D11 D12 D13
	// D12 D22 D23
	// D13 D23 D33

	//D11, D22, D33 are the diagonal tensor elements
	//D12, D13, D23 are the off-diagonal tensor elements
	VEC<DBL3> D;

	if (!D.resize(N)) return error(BERROR_OUTOFMEMORY_NCRIT);

	//object used to compute tensor elements
	DemagTFunc dtf;

	//-------------- FFT SETUP

	//setup fft object with fft computation lines
	FFTMethods_Cpp<double> fft;

	size_t maxN = maximum(N.x / 2 + 1, N.y, N.z);

	vector<ReIm3> fft_line(maxN);
	vector<ReIm3> fft_line2(maxN);

	//lambda used to transform an input tensor into an output kernel
	auto tensor_to_kernel = [&](VEC<DBL3>& tensor, VEC<ReIm3>& kernel) -> void {

		//-------------- FFT REAL TENSOR

		//NOTE : don't use parallel for loops as it will mess up the packing in the D tensor
		//If you want parallel loops you'll need to allocate additional temporary spaces, so not worth it for initialization
		//rather have slightly slower initialization than fail due to running out of memory for large problem sizes

		//FFT into Kernel forms ready for convolution multiplication - diagonal components
		for (int j = 0; j < N.y; j++) {

			fft.CopyRealShuffle(tensor.data() + j * N.x, fft_line.data(), N.x / 2);
			fft.FFT_Radix4_DIT(fft_line.data(), log2(N.x) - 1, N.x / 2);
			fft.RealfromComplexFFT(fft_line.data(), fft_line2.data(), N.x / 2);

			//pack into scratch space
			for (int i = 0; i < N.x / 2 + 1; i++) {

				F[i + j * (N.x / 2 + 1)] = fft_line2[i];
			}
		}

		for (int i = 0; i < N.x / 2 + 1; i++) {

			fft.CopyShuffle(F.data() + i, fft_line.data(), N.x / 2 + 1, N.y);
			fft.FFT_Radix4_DIT(fft_line.data(), log2(N.y), N.y);

			//pack into output kernel
			for (int j = 0; j < N.y; j++) {

				kernel[i + j * (N.x / 2 + 1)] = fft_line[j];
			}
		}
	};

	//-------------- CALCULATE DIAGONAL TENSOR ELEMENTS THEN TRANSFORM INTO KERNEL

	//no need to pass the actual cellsize values, just normalized values will do

	if (!dtf.CalcDiagTens2D_Shifted_Irregular(D, n, N, kernels[index]->h_src / h_max, kernels[index]->h_dst / h_max, kernels[index]->shift / h_max)) return error(BERROR_OUTOFMEMORY_NCRIT);

	tensor_to_kernel(D, kernels[index]->Kdiag_cmpl);

	//-------------- CALCULATE OFF-DIAGONAL TENSOR ELEMENTS THEN TRANSFORM INTO KERNEL

	//important to zero D before calculating new tensor elements
	D.set(DBL3());

	if (!dtf.CalcOffDiagTens2D_Shifted_Irregular(D, n, N, kernels[index]->h_src / h_max, kernels[index]->h_dst / h_max, kernels[index]->shift / h_max)) return error(BERROR_OUTOFMEMORY_NCRIT);

	tensor_to_kernel(D, kernels[index]->Kodiag_cmpl);

	//Done
	return error;
}

//3D real kernels (Kdiag_real, and Kodiag_real, with full use of kernel symmetries)
BError DemagKernelCollection::Calculate_Demag_Kernels_3D_Self(int index)
{
	BError error(__FUNCTION__);

	//-------------- DEMAG TENSOR

	//Demag tensor components
	//
	// D11 D12 D13
	// D12 D22 D23
	// D13 D23 D33

	//D11, D22, D33 are the diagonal tensor elements
	//D12, D13, D23 are the off-diagonal tensor elements
	VEC<DBL3> D;

	if (!D.resize(N)) return error(BERROR_OUTOFMEMORY_NCRIT);

	//object used to compute tensor elements
	DemagTFunc dtf;

	//-------------- FFT SETUP

	//setup fft object with fft computation lines
	FFTMethods_Cpp<double> fft;

	size_t maxN = maximum(N.x / 2 + 1, N.y / 2 + 1, N.z / 2 + 1);

	vector<ReIm3> fft_line(maxN);
	vector<ReIm3> fft_line2(maxN);

	//lambda used to transform an input tensor into an output kernel
	auto tensor_to_kernel = [&](VEC<DBL3>& tensor, VEC<DBL3>& kernel, bool off_diagonal) -> void {

		//-------------- FFT REAL TENSOR

		//NOTE : don't use parallel for loops as it will mess up the packing in the D tensor
		//If you want parallel loops you'll need to allocate additional temporary spaces, so not worth it for initialization
		//rather have slightly slower initialization than fail due to running out of memory for large problem sizes

		//FFT into Kernel forms ready for convolution multiplication - diagonal components
		for (int k = 0; k < N.z; k++) {
			for (int j = 0; j < N.y; j++) {

				fft.CopyRealShuffle(tensor.data() + j * N.x + k * N.x*N.y, fft_line.data(), N.x / 2);
				fft.FFT_Radix4_DIT(fft_line.data(), log2(N.x) - 1, N.x / 2);
				fft.RealfromComplexFFT(fft_line.data(), fft_line2.data(), N.x / 2);

				//pack into lower half of tensor row for next step (keep same row and plane strides)
				for (int i = 0; i < N.x / 2 + 1; i++) {

					if (!off_diagonal) {

						//even w.r.t. to x so output is purely real
						tensor[i + j * (N.x / 2 + 1) + k * (N.x / 2 + 1) * N.y] = DBL3(fft_line2[i].x.Re, fft_line2[i].y.Re, fft_line2[i].z.Re);
					}
					else {

						//Dxy : odd x, Dxz : odd x, Dyz : even x
						tensor[i + j * (N.x / 2 + 1) + k * (N.x / 2 + 1) * N.y] = DBL3(fft_line2[i].x.Im, fft_line2[i].y.Im, fft_line2[i].z.Re);
					}
				}
			}
		}

		for (int k = 0; k < N.z; k++) {
			for (int i = 0; i < N.x / 2 + 1; i++) {

				fft.CopyRealShuffle(tensor.data() + i + k * (N.x / 2 + 1)*N.y, fft_line.data(), N.x / 2 + 1, N.y / 2);
				fft.FFT_Radix4_DIT(fft_line.data(), log2(N.y) - 1, N.y / 2);
				fft.RealfromComplexFFT(fft_line.data(), fft_line2.data(), N.y / 2);

				//pack into lower half of tensor column for next step (keep same row and plane strides)
				for (int j = 0; j < N.y / 2 + 1; j++) {

					if (!off_diagonal) {

						//even w.r.t. to y so output is purely real
						tensor[i + j * (N.x / 2 + 1) + k * (N.x / 2 + 1) * N.y] = DBL3(fft_line2[j].x.Re, fft_line2[j].y.Re, fft_line2[j].z.Re);
					}
					else {

						//Dxy : odd y, Dxz : even y, Dyz : odd y
						tensor[i + j * (N.x / 2 + 1) + k * (N.x / 2 + 1) * N.y] = DBL3(fft_line2[j].x.Im, fft_line2[j].y.Re, fft_line2[j].z.Im);
					}
				}
			}
		}

		for (int j = 0; j < N.y / 2 + 1; j++) {
			for (int i = 0; i < N.x / 2 + 1; i++) {

				fft.CopyRealShuffle(tensor.data() + i + j * (N.x / 2 + 1), fft_line.data(), (N.x / 2 + 1)*N.y, N.z / 2);
				fft.FFT_Radix4_DIT(fft_line.data(), log2(N.z) - 1, N.z / 2);
				fft.RealfromComplexFFT(fft_line.data(), fft_line2.data(), N.z / 2);

				//pack into output kernels with reduced strides
				for (int k = 0; k < N.z / 2 + 1; k++) {

					if (!off_diagonal) {

						//even w.r.t. to z so output is purely real
						kernel[i + j * (N.x / 2 + 1) + k * (N.x / 2 + 1) * (N.y / 2 + 1)] = DBL3(fft_line2[k].x.Re, fft_line2[k].y.Re, fft_line2[k].z.Re);
					}
					else {

						//Dxy : even z, Dxz : odd z, Dyz : odd z
						//Also multiply by -1 since all off-diagonal tensor elements have been odd twice
						//The final output is thus purely real but we always treated the input as purely real even when it should have been purely imaginary
						//This means we need to account for i * i = -1 at the end
						kernel[i + j * (N.x / 2 + 1) + k * (N.x / 2 + 1) * (N.y / 2 + 1)] = DBL3(-fft_line2[k].x.Re, -fft_line2[k].y.Im, -fft_line2[k].z.Im);
					}
				}
			}
		}
	};

	//-------------- CALCULATE DIAGONAL TENSOR ELEMENTS THEN TRANSFORM INTO KERNEL

	//no need to pass the actual cellsize values, just normalized values will do
	if (!dtf.CalcDiagTens3D(D, n, N, h / h_max)) return error(BERROR_OUTOFMEMORY_NCRIT);

	tensor_to_kernel(D, kernels[index]->Kdiag_real, false);

	//-------------- CALCULATE OFF-DIAGONAL TENSOR ELEMENTS THEN TRANSFORM INTO KERNEL

	//important to zero D before calculating new tensor elements
	D.set(DBL3());

	if (!dtf.CalcOffDiagTens3D(D, n, N, h / h_max)) return error(BERROR_OUTOFMEMORY_NCRIT);

	tensor_to_kernel(D, kernels[index]->Kodiag_real, true);

	//Done
	return error;
}

//3D layers, z shift only : Kernels can be stored with use of kernel symmetries (but still complex).
BError DemagKernelCollection::Calculate_Demag_Kernels_3D_zShifted(int index)
{
	BError error(__FUNCTION__);

	//-------------- DEMAG TENSOR

	//Demag tensor components
	//
	// D11 D12 D13
	// D12 D22 D23
	// D13 D23 D33

	//D11, D22, D33 are the diagonal tensor elements
	//D12, D13, D23 are the off-diagonal tensor elements
	VEC<DBL3> D;

	if (!D.resize(N)) return error(BERROR_OUTOFMEMORY_NCRIT);

	//object used to compute tensor elements
	DemagTFunc dtf;

	//-------------- FFT SETUP

	//setup fft object with fft computation lines
	FFTMethods_Cpp<double> fft;

	size_t maxN = maximum(N.x / 2 + 1, N.y, N.z);

	vector<ReIm3> fft_line(maxN);
	vector<ReIm3> fft_line2(maxN);

	//lambda used to transform an input tensor into an output kernel
	auto tensor_to_kernel = [&](VEC<DBL3>& tensor, VEC<ReIm3>& kernel) -> void {

		//-------------- FFT REAL TENSOR

		//NOTE : don't use parallel for loops as it will mess up the packing in the D tensor
		//If you want parallel loops you'll need to allocate additional temporary spaces, so not worth it for initialization
		//rather have slightly slower initialization than fail due to running out of memory for large problem sizes

		//FFT into Kernel forms ready for convolution multiplication - diagonal components
		for (int k = 0; k < N.z; k++) {
			for (int j = 0; j < N.y; j++) {

				fft.CopyRealShuffle(tensor.data() + j * N.x + k * N.x*N.y, fft_line.data(), N.x / 2);
				fft.FFT_Radix4_DIT(fft_line.data(), log2(N.x) - 1, N.x / 2);
				fft.RealfromComplexFFT(fft_line.data(), fft_line2.data(), N.x / 2);

				//pack into scratch space
				for (int i = 0; i < N.x / 2 + 1; i++) {

					F[i + j * (N.x / 2 + 1) + k * (N.x / 2 + 1) * N.y] = fft_line2[i];
				}
			}
		}

		for (int k = 0; k < N.z; k++) {
			for (int i = 0; i < N.x / 2 + 1; i++) {

				fft.CopyShuffle(F.data() + i + k * (N.x / 2 + 1)*N.y, fft_line.data(), N.x / 2 + 1, N.y);
				fft.FFT_Radix4_DIT(fft_line.data(), log2(N.y), N.y);

				//pack into scratch space
				for (int j = 0; j < N.y; j++) {

					F2[i + j * (N.x / 2 + 1) + k * (N.x / 2 + 1) * N.y] = fft_line[j];
				}
			}
		}

		for (int j = 0; j < N.y / 2 + 1; j++) {
			for (int i = 0; i < N.x / 2 + 1; i++) {

				fft.CopyShuffle(F2.data() + i + j * (N.x / 2 + 1), fft_line.data(), (N.x / 2 + 1)*N.y, N.z);
				fft.FFT_Radix4_DIT(fft_line.data(), log2(N.z), N.z);

				//pack into output kernel with reduced strides
				for (int k = 0; k < N.z / 2 + 1; k++) {

					kernel[i + j * (N.x / 2 + 1) + k * (N.x / 2 + 1) * (N.y / 2 + 1)] = fft_line[k];
				}
			}
		}
	};

	//-------------- CALCULATE DIAGONAL TENSOR ELEMENTS THEN TRANSFORM INTO KERNEL

	//no need to pass the actual cellsize values, just normalized values will do
	if (!dtf.CalcDiagTens3D_Shifted(D, n, N, h / h_max, kernels[index]->shift / h_max)) return error(BERROR_OUTOFMEMORY_NCRIT);

	tensor_to_kernel(D, kernels[index]->Kdiag_cmpl);

	//-------------- CALCULATE OFF-DIAGONAL TENSOR ELEMENTS THEN TRANSFORM INTO KERNEL

	//important to zero D before calculating new tensor elements
	D.set(DBL3());

	if (!dtf.CalcOffDiagTens3D_Shifted(D, n, N, h / h_max, kernels[index]->shift / h_max)) return error(BERROR_OUTOFMEMORY_NCRIT);

	tensor_to_kernel(D, kernels[index]->Kodiag_cmpl);

	//Done
	return error;
}

//3D complex kernels (Kdiag_cmpl, and Kodiag_cmpl, without any kernel symmetries)
BError DemagKernelCollection::Calculate_Demag_Kernels_3D_Complex_Full(int index)
{
	BError error(__FUNCTION__);

	//-------------- DEMAG TENSOR

	//Demag tensor components
	//
	// D11 D12 D13
	// D12 D22 D23
	// D13 D23 D33

	//D11, D22, D33 are the diagonal tensor elements
	//D12, D13, D23 are the off-diagonal tensor elements
	VEC<DBL3> D;

	if (!D.resize(N)) return error(BERROR_OUTOFMEMORY_NCRIT);

	//object used to compute tensor elements
	DemagTFunc dtf;

	//-------------- FFT SETUP

	//setup fft object with fft computation lines
	FFTMethods_Cpp<double> fft;

	size_t maxN = maximum(N.x / 2 + 1, N.y, N.z);

	vector<ReIm3> fft_line(maxN);
	vector<ReIm3> fft_line2(maxN);

	//lambda used to transform an input tensor into an output kernel
	auto tensor_to_kernel = [&](VEC<DBL3>& tensor, VEC<ReIm3>& kernel) -> void {

		//-------------- FFT REAL TENSOR

		//NOTE : don't use parallel for loops as it will mess up the packing in the D tensor
		//If you want parallel loops you'll need to allocate additional temporary spaces, so not worth it for initialization
		//rather have slightly slower initialization than fail due to running out of memory for large problem sizes

		//FFT into Kernel forms ready for convolution multiplication - diagonal components
		for (int k = 0; k < N.z; k++) {
			for (int j = 0; j < N.y; j++) {

				fft.CopyRealShuffle(tensor.data() + j * N.x + k * N.x*N.y, fft_line.data(), N.x / 2);
				fft.FFT_Radix4_DIT(fft_line.data(), log2(N.x) - 1, N.x / 2);
				fft.RealfromComplexFFT(fft_line.data(), fft_line2.data(), N.x / 2);

				//pack into scratch space
				for (int i = 0; i < N.x / 2 + 1; i++) {

					F[i + j * (N.x / 2 + 1) + k * (N.x / 2 + 1) * N.y] = fft_line2[i];
				}
			}
		}

		for (int k = 0; k < N.z; k++) {
			for (int i = 0; i < N.x / 2 + 1; i++) {

				fft.CopyShuffle(F.data() + i + k * (N.x / 2 + 1)*N.y, fft_line.data(), N.x / 2 + 1, N.y);
				fft.FFT_Radix4_DIT(fft_line.data(), log2(N.y), N.y);

				//pack into scratch space
				for (int j = 0; j < N.y; j++) {

					F2[i + j * (N.x / 2 + 1) + k * (N.x / 2 + 1) * N.y] = fft_line[j];
				}
			}
		}

		for (int j = 0; j < N.y; j++) {
			for (int i = 0; i < N.x / 2 + 1; i++) {

				fft.CopyShuffle(F2.data() + i + j * (N.x / 2 + 1), fft_line.data(), (N.x / 2 + 1)*N.y, N.z);
				fft.FFT_Radix4_DIT(fft_line.data(), log2(N.z), N.z);

				//pack into output kernel
				for (int k = 0; k < N.z; k++) {

					kernel[i + j * (N.x / 2 + 1) + k * (N.x / 2 + 1) * N.y] = fft_line[k];
				}
			}
		}
	};

	//-------------- CALCULATE DIAGONAL TENSOR ELEMENTS THEN TRANSFORM INTO KERNEL

	//no need to pass the actual cellsize values, just normalized values will do
	if (!dtf.CalcDiagTens3D_Shifted(D, n, N, h / h_max, kernels[index]->shift / h_max)) return error(BERROR_OUTOFMEMORY_NCRIT);

	tensor_to_kernel(D, kernels[index]->Kdiag_cmpl);

	//-------------- CALCULATE OFF-DIAGONAL TENSOR ELEMENTS THEN TRANSFORM INTO KERNEL

	//important to zero D before calculating new tensor elements
	D.set(DBL3());

	if (!dtf.CalcOffDiagTens3D_Shifted(D, n, N, h / h_max, kernels[index]->shift / h_max)) return error(BERROR_OUTOFMEMORY_NCRIT);

	tensor_to_kernel(D, kernels[index]->Kodiag_cmpl);

	//Done
	return error;
}

#endif