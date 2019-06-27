#include "DemagKernelCUDA.h"

#if COMPILECUDA == 1

#if defined MODULE_DEMAG || defined MODULE_SDEMAG

#include <cuda_runtime.h>


//-------------------------- CONVOLUTION PRODUCT CUDA KERNELS

//N = (N.x/2 + 1, N.y, 1)
__global__ void cu_Demag_ConvProd_2D(cuVEC<cuReal3>& Kdiag, cuVEC<cuReal>& K2D_odiag, cuComplex* cuSx, cuComplex* cuSy, cuComplex* cuSz, cuSZ3& N)
{
	//above N.y/2 use kernel symmetries to recover kernel values
	//diagonal components are even about the N.y/2 point
	//off-diagonal values are odd about the N.y/2 point

	int idx = blockDim.x * blockIdx.x + threadIdx.x;

	if (idx < (N.x / 2 + 1) * N.y) {

		int j = (idx / (N.x / 2 + 1)) % N.y;

		if (j <= N.y / 2) {

			cuReIm FMx = cuSx[idx];
			cuReIm FMy = cuSy[idx];
			cuReIm FMz = cuSz[idx];

			cuSx[idx] = (Kdiag[idx].x  * FMx) + (K2D_odiag[idx] * FMy);
			cuSy[idx] = (K2D_odiag[idx] * FMx) + (Kdiag[idx].y  * FMy);
			cuSz[idx] = (Kdiag[idx].z  * FMz);
		}
		else {

			int i = idx % (N.x / 2 + 1);

			int ker_idx = i + (N.y - j) * (N.x / 2 + 1);

			cuReIm FMx = cuSx[idx];
			cuReIm FMy = cuSy[idx];
			cuReIm FMz = cuSz[idx];

			cuSx[idx] = (Kdiag[ker_idx].x  * FMx) + (-K2D_odiag[ker_idx] * FMy);
			cuSy[idx] = (-K2D_odiag[ker_idx] * FMx) + (Kdiag[ker_idx].y  * FMy);
			cuSz[idx] = (Kdiag[ker_idx].z  * FMz);
		}
	}
}

__global__ void cu_Demag_ConvProd_2D_transpose_xy(cuVEC<cuReal3>& Kdiag, cuVEC<cuReal>& K2D_odiag, cuComplex* cuSx, cuComplex* cuSy, cuComplex* cuSz, cuSZ3& N)
{
	//above N.y/2 use kernel symmetries to recover kernel values
	//diagonal components are even about the N.y/2 point
	//off-diagonal values are odd about the N.y/2 point

	int idx = blockDim.x * blockIdx.x + threadIdx.x;

	if (idx < (N.x / 2 + 1) * N.y) {

		int i = idx % N.y;
		int j = (idx / N.y) % (N.x / 2 + 1);

		if (i <= N.y / 2) {

			cuReIm FMx = cuSx[idx];
			cuReIm FMy = cuSy[idx];
			cuReIm FMz = cuSz[idx];

			int ker_idx = i + j * (N.y / 2 + 1);

			cuSx[idx] = (Kdiag[ker_idx].x  * FMx) + (K2D_odiag[ker_idx] * FMy);
			cuSy[idx] = (K2D_odiag[ker_idx] * FMx) + (Kdiag[ker_idx].y  * FMy);
			cuSz[idx] = (Kdiag[ker_idx].z  * FMz);
		}
		else {

			int ker_idx = (N.y - i) + j * (N.y / 2 + 1);

			cuReIm FMx = cuSx[idx];
			cuReIm FMy = cuSy[idx];
			cuReIm FMz = cuSz[idx];

			cuSx[idx] = (Kdiag[ker_idx].x  * FMx) + (-K2D_odiag[ker_idx] * FMy);
			cuSy[idx] = (-K2D_odiag[ker_idx] * FMx) + (Kdiag[ker_idx].y  * FMy);
			cuSz[idx] = (Kdiag[ker_idx].z  * FMz);
		}
	}
}

//N = (N.x/2 + 1, N.y, N.z)
__global__ void cu_Demag_ConvProd_3D_transpose_xy(cuVEC<cuReal3>& Kdiag, cuVEC<cuReal3>& Kodiag, cuComplex* cuSx, cuComplex* cuSy, cuComplex* cuSz, cuSZ3& N)
{
	//above N.z/2 and N.y/2 use kernel symmetries to recover kernel values
	//diagonal components are even about the N.z/2 and N.y/2 points
	//Kxy is even about N.z/2 and odd about N.y/2
	//Kxz is odd about N.z/2 and even about N.y/2
	//Kyz is odd about N.z/2 and odd about N.y/2

	int idx = blockDim.x * blockIdx.x + threadIdx.x;

	if (idx < (N.x / 2 + 1) * N.y * N.z) {

		int i = idx % N.y;
		int j = (idx / N.y) % (N.x / 2 + 1);
		int k = idx / ((N.x / 2 + 1) * N.y);

		if (k <= N.z / 2) {

			if (i <= N.y / 2) {

				cuReIm FMx = cuSx[idx];
				cuReIm FMy = cuSy[idx];
				cuReIm FMz = cuSz[idx];

				int ker_idx = i + j * (N.y / 2 + 1) + k * (N.x / 2 + 1) * (N.y / 2 + 1);

				cuSx[idx] = (Kdiag[ker_idx].x * FMx) + (Kodiag[ker_idx].x * FMy) + (Kodiag[ker_idx].y * FMz);
				cuSy[idx] = (Kodiag[ker_idx].x * FMx) + (Kdiag[ker_idx].y * FMy) + (Kodiag[ker_idx].z * FMz);
				cuSz[idx] = (Kodiag[ker_idx].y * FMx) + (Kodiag[ker_idx].z * FMy) + (Kdiag[ker_idx].z * FMz);
			}
			else {

				cuReIm FMx = cuSx[idx];
				cuReIm FMy = cuSy[idx];
				cuReIm FMz = cuSz[idx];

				int ker_idx = (N.y - i) + j * (N.y / 2 + 1) + k * (N.x / 2 + 1) * (N.y / 2 + 1);

				cuSx[idx] = (Kdiag[ker_idx].x * FMx) + (-Kodiag[ker_idx].x * FMy) + (Kodiag[ker_idx].y * FMz);
				cuSy[idx] = (-Kodiag[ker_idx].x * FMx) + (Kdiag[ker_idx].y * FMy) + (-Kodiag[ker_idx].z * FMz);
				cuSz[idx] = (Kodiag[ker_idx].y * FMx) + (-Kodiag[ker_idx].z * FMy) + (Kdiag[ker_idx].z * FMz);
			}
		}
		else {

			if (i <= N.y / 2) {

				cuReIm FMx = cuSx[idx];
				cuReIm FMy = cuSy[idx];
				cuReIm FMz = cuSz[idx];

				int ker_idx = i + j * (N.y / 2 + 1) + (N.z - k) * (N.x / 2 + 1) * (N.y / 2 + 1);

				cuSx[idx] = (Kdiag[ker_idx].x * FMx) + (Kodiag[ker_idx].x * FMy) + (-Kodiag[ker_idx].y * FMz);
				cuSy[idx] = (Kodiag[ker_idx].x * FMx) + (Kdiag[ker_idx].y * FMy) + (-Kodiag[ker_idx].z * FMz);
				cuSz[idx] = (-Kodiag[ker_idx].y * FMx) + (-Kodiag[ker_idx].z * FMy) + (Kdiag[ker_idx].z * FMz);
			}
			else {

				cuReIm FMx = cuSx[idx];
				cuReIm FMy = cuSy[idx];
				cuReIm FMz = cuSz[idx];

				int ker_idx = (N.y - i) + j * (N.y / 2 + 1) + (N.z - k) * (N.x / 2 + 1) * (N.y / 2 + 1);

				cuSx[idx] = (Kdiag[ker_idx].x * FMx) + (-Kodiag[ker_idx].x * FMy) + (-Kodiag[ker_idx].y * FMz);
				cuSy[idx] = (-Kodiag[ker_idx].x * FMx) + (Kdiag[ker_idx].y * FMy) + (Kodiag[ker_idx].z * FMz);
				cuSz[idx] = (-Kodiag[ker_idx].y * FMx) + (Kodiag[ker_idx].z * FMy) + (Kdiag[ker_idx].z * FMz);
			}
		}
	}
}

//N = (N.x/2 + 1, N.y, 4)
//xy is transposed
__global__ void cu_Demag_ConvProd_q2D_4_transpose_xy(cuVEC<cuReal3>& Kdiag, cuVEC<cuReal3>& Kodiag, cuComplex* cuSx, cuComplex* cuSy, cuComplex* cuSz, cuSZ3& N)
{
	//above N.z/2 and N.y/2 use kernel symmetries to recover kernel values
	//diagonal components are even about the N.z/2 and N.y/2 points
	//Kxy is even about N.z/2 and odd about N.y/2
	//Kxz is odd about N.z/2 and even about N.y/2
	//Kyz is odd about N.z/2 and odd about N.y/2

	int idx = blockDim.x * blockIdx.x + threadIdx.x;

	//N.z = 4, and this kernel was called with (N.x/2 + 1) * N.y points: handle all z points in one go
	int planecount = (N.x / 2 + 1) * N.y;

	//kernels packed into planes of (N.y / 2 + 1) * (N.x / 2 + 1) size
	int kerplanecount = (N.x / 2 + 1) * (N.y / 2 + 1);

	if (idx < planecount) {

		//the z-axis points (the others are zero)
		cuReIm3 a = cuReIm3(cuSx[idx], cuSy[idx], cuSz[idx]);
		cuReIm3 b = cuReIm3(cuSx[idx + planecount], cuSy[idx + planecount], cuSz[idx + planecount]);

		//forward z-axis fft
		//NOTE: cuda fft uses -i for the forward fft and +i for the inverse fft.
		//The kernels are purely real so you would get the same result by taking +i for the forward and -i for the inverse, but better to keep it consistent : use the cuda fft convention here.
		cuReIm3 X0 = a + b;
		cuReIm3 X1 = a - !b;
		cuReIm3 X2 = a - b;
		cuReIm3 X3 = a + !b;

		//kernel multiplication
		cuReIm3 F0, F1, F2, F3;

		int i = idx % N.y;
		int j = (idx / N.y) % (N.x / 2 + 1);

		if (i <= N.y / 2) {

			int ker_baseidx = i + j * (N.y / 2 + 1);

			F0.x = (Kdiag[ker_baseidx].x * X0.x) + (Kodiag[ker_baseidx].x * X0.y) + (Kodiag[ker_baseidx].y * X0.z);
			F0.y = (Kodiag[ker_baseidx].x * X0.x) + (Kdiag[ker_baseidx].y * X0.y) + (Kodiag[ker_baseidx].z * X0.z);
			F0.z = (Kodiag[ker_baseidx].y * X0.x) + (Kodiag[ker_baseidx].z * X0.y) + (Kdiag[ker_baseidx].z * X0.z);

			F1.x = (Kdiag[ker_baseidx + kerplanecount].x * X1.x) + (Kodiag[ker_baseidx + kerplanecount].x * X1.y) + (Kodiag[ker_baseidx + kerplanecount].y * X1.z);
			F1.y = (Kodiag[ker_baseidx + kerplanecount].x * X1.x) + (Kdiag[ker_baseidx + kerplanecount].y * X1.y) + (Kodiag[ker_baseidx + kerplanecount].z * X1.z);
			F1.z = (Kodiag[ker_baseidx + kerplanecount].y * X1.x) + (Kodiag[ker_baseidx + kerplanecount].z * X1.y) + (Kdiag[ker_baseidx + kerplanecount].z * X1.z);

			F2.x = (Kdiag[ker_baseidx + 2 * kerplanecount].x * X2.x) + (Kodiag[ker_baseidx + 2 * kerplanecount].x * X2.y) + (Kodiag[ker_baseidx + 2 * kerplanecount].y * X2.z);
			F2.y = (Kodiag[ker_baseidx + 2 * kerplanecount].x * X2.x) + (Kdiag[ker_baseidx + 2 * kerplanecount].y * X2.y) + (Kodiag[ker_baseidx + 2 * kerplanecount].z * X2.z);
			F2.z = (Kodiag[ker_baseidx + 2 * kerplanecount].y * X2.x) + (Kodiag[ker_baseidx + 2 * kerplanecount].z * X2.y) + (Kdiag[ker_baseidx + 2 * kerplanecount].z * X2.z);

			F3.x = (Kdiag[ker_baseidx + kerplanecount].x * X3.x) + (Kodiag[ker_baseidx + kerplanecount].x * X3.y) + (-Kodiag[ker_baseidx + kerplanecount].y * X3.z);
			F3.y = (Kodiag[ker_baseidx + kerplanecount].x * X3.x) + (Kdiag[ker_baseidx + kerplanecount].y * X3.y) + (-Kodiag[ker_baseidx + kerplanecount].z * X3.z);
			F3.z = (-Kodiag[ker_baseidx + kerplanecount].y * X3.x) + (-Kodiag[ker_baseidx + kerplanecount].z * X3.y) + (Kdiag[ker_baseidx + kerplanecount].z * X3.z);
		}
		else {

			int ker_baseidx = (N.y - i) + j * (N.y / 2 + 1);

			F0.x = (Kdiag[ker_baseidx].x * X0.x) + (-Kodiag[ker_baseidx].x * X0.y) + (Kodiag[ker_baseidx].y * X0.z);
			F0.y = (-Kodiag[ker_baseidx].x * X0.x) + (Kdiag[ker_baseidx].y * X0.y) + (-Kodiag[ker_baseidx].z * X0.z);
			F0.z = (Kodiag[ker_baseidx].y * X0.x) + (-Kodiag[ker_baseidx].z * X0.y) + (Kdiag[ker_baseidx].z * X0.z);

			F1.x = (Kdiag[ker_baseidx + kerplanecount].x * X1.x) + (-Kodiag[ker_baseidx + kerplanecount].x * X1.y) + (Kodiag[ker_baseidx + kerplanecount].y * X1.z);
			F1.y = (-Kodiag[ker_baseidx + kerplanecount].x * X1.x) + (Kdiag[ker_baseidx + kerplanecount].y * X1.y) + (-Kodiag[ker_baseidx + kerplanecount].z * X1.z);
			F1.z = (Kodiag[ker_baseidx + kerplanecount].y * X1.x) + (-Kodiag[ker_baseidx + kerplanecount].z * X1.y) + (Kdiag[ker_baseidx + kerplanecount].z * X1.z);

			F2.x = (Kdiag[ker_baseidx + 2 * kerplanecount].x * X2.x) + (-Kodiag[ker_baseidx + 2 * kerplanecount].x * X2.y) + (Kodiag[ker_baseidx + 2 * kerplanecount].y * X2.z);
			F2.y = (-Kodiag[ker_baseidx + 2 * kerplanecount].x * X2.x) + (Kdiag[ker_baseidx + 2 * kerplanecount].y * X2.y) + (-Kodiag[ker_baseidx + 2 * kerplanecount].z * X2.z);
			F2.z = (Kodiag[ker_baseidx + 2 * kerplanecount].y * X2.x) + (-Kodiag[ker_baseidx + 2 * kerplanecount].z * X2.y) + (Kdiag[ker_baseidx + 2 * kerplanecount].z * X2.z);

			F3.x = (Kdiag[ker_baseidx + kerplanecount].x * X3.x) + (-Kodiag[ker_baseidx + kerplanecount].x * X3.y) + (-Kodiag[ker_baseidx + kerplanecount].y * X3.z);
			F3.y = (-Kodiag[ker_baseidx + kerplanecount].x * X3.x) + (Kdiag[ker_baseidx + kerplanecount].y * X3.y) + (Kodiag[ker_baseidx + kerplanecount].z * X3.z);
			F3.z = (-Kodiag[ker_baseidx + kerplanecount].y * X3.x) + (Kodiag[ker_baseidx + kerplanecount].z * X3.y) + (Kdiag[ker_baseidx + kerplanecount].z * X3.z);
		}

		//inverse z-axis fft (but without division by 4). Also only keep first 2 points

		cuSx[idx] = F0.x + F1.x + F2.x + F3.x;
		cuSy[idx] = F0.y + F1.y + F2.y + F3.y;
		cuSz[idx] = F0.z + F1.z + F2.z + F3.z;

		cuReIm3 F1c = !F1;
		cuReIm3 F3c = !F3;

		cuSx[idx + planecount] = F0.x + F1c.x + F2.x - F3c.x;
		cuSy[idx + planecount] = F0.y + F1c.y + F2.y - F3c.y;
		cuSz[idx + planecount] = F0.z + F1c.z + F2.z - F3c.z;
	}
}

//N = (N.x/2 + 1, N.y, 8)
//xy is transposed
__global__ void cu_Demag_ConvProd_q2D_8_transpose_xy(cuVEC<cuReal3>& Kdiag, cuVEC<cuReal3>& Kodiag, cuComplex* cuSx, cuComplex* cuSy, cuComplex* cuSz, cuSZ3& N)
{
	//above N.z/2 and N.y/2 use kernel symmetries to recover kernel values
	//diagonal components are even about the N.z/2 and N.y/2 points
	//Kxy is even about N.z/2 and odd about N.y/2
	//Kxz is odd about N.z/2 and even about N.y/2
	//Kyz is odd about N.z/2 and odd about N.y/2

	int idx = blockDim.x * blockIdx.x + threadIdx.x;

	//N.z = 8, and this kernel was called with (N.x/2 + 1) * N.y points: handle all z points in one go
	int planecount = (N.x / 2 + 1) * N.y;

	//kernels packed into planes of (N.y / 2 + 1) * (N.x / 2 + 1) size
	int kerplanecount = (N.x / 2 + 1) * (N.y / 2 + 1);

	if (idx < planecount) {

#define a (cuReal)0.7071067811865

		//the z-axis points (the others are zero)
		cuReIm3 x0 = cuReIm3(cuSx[idx], cuSy[idx], cuSz[idx]);
		cuReIm3 x1 = cuReIm3(cuSx[idx + planecount], cuSy[idx + planecount], cuSz[idx + planecount]);
		cuReIm3 x2 = cuReIm3(cuSx[idx + 2 * planecount], cuSy[idx + 2 * planecount], cuSz[idx + 2 * planecount]);
		cuReIm3 x3 = cuReIm3(cuSx[idx + 3 * planecount], cuSy[idx + 3 * planecount], cuSz[idx + 3 * planecount]);

		//Radix-4 step
		cuReIm3 X0 = x0 + x2;
		cuReIm3 X2 = x0 - x2;
		cuReIm3 X4 = x0 - !x2;
		cuReIm3 X6 = x0 + !x2;

		cuReIm3 X1 = x1 + x3;
		cuReIm3 X3 = !(x3 - x1);
		cuReIm3 X5 = (x1 - !x3) * cuReIm(a, -a);
		cuReIm3 X7 = (x1 + !x3) * cuReIm(-a, -a);

		//Radix-2 step
		cuReIm3 temp = X0 - X1;
		X0 = X0 + X1;
		X1 = temp;

		temp = X2 - X3;
		X2 = X2 + X3;
		X3 = temp;

		temp = X4 - X5;
		X4 = X4 + X5;
		X5 = temp;

		temp = X6 - X7;
		X6 = X6 + X7;
		X7 = temp;

		//data set in shuffled order:
		//X0, X4, X2, X6, X1, X5, X3, X7

		cuReIm3 F0, F1, F2, F3, F4, F5, F6, F7;

		int i = idx % N.y;
		int j = (idx / N.y) % (N.x / 2 + 1);

		if (i <= N.y / 2) {

			int ker_baseidx = i + j * (N.y / 2 + 1);

			F0.x = (Kdiag[ker_baseidx].x * X0.x) + (Kodiag[ker_baseidx].x * X0.y) + (Kodiag[ker_baseidx].y * X0.z);
			F0.y = (Kodiag[ker_baseidx].x * X0.x) + (Kdiag[ker_baseidx].y * X0.y) + (Kodiag[ker_baseidx].z * X0.z);
			F0.z = (Kodiag[ker_baseidx].y * X0.x) + (Kodiag[ker_baseidx].z * X0.y) + (Kdiag[ker_baseidx].z * X0.z);

			F4.x = (Kdiag[ker_baseidx + kerplanecount].x * X4.x) + (Kodiag[ker_baseidx + kerplanecount].x * X4.y) + (Kodiag[ker_baseidx + kerplanecount].y * X4.z);
			F4.y = (Kodiag[ker_baseidx + kerplanecount].x * X4.x) + (Kdiag[ker_baseidx + kerplanecount].y * X4.y) + (Kodiag[ker_baseidx + kerplanecount].z * X4.z);
			F4.z = (Kodiag[ker_baseidx + kerplanecount].y * X4.x) + (Kodiag[ker_baseidx + kerplanecount].z * X4.y) + (Kdiag[ker_baseidx + kerplanecount].z * X4.z);

			F2.x = (Kdiag[ker_baseidx + 2 * kerplanecount].x * X2.x) + (Kodiag[ker_baseidx + 2 * kerplanecount].x * X2.y) + (Kodiag[ker_baseidx + 2 * kerplanecount].y * X2.z);
			F2.y = (Kodiag[ker_baseidx + 2 * kerplanecount].x * X2.x) + (Kdiag[ker_baseidx + 2 * kerplanecount].y * X2.y) + (Kodiag[ker_baseidx + 2 * kerplanecount].z * X2.z);
			F2.z = (Kodiag[ker_baseidx + 2 * kerplanecount].y * X2.x) + (Kodiag[ker_baseidx + 2 * kerplanecount].z * X2.y) + (Kdiag[ker_baseidx + 2 * kerplanecount].z * X2.z);

			F6.x = (Kdiag[ker_baseidx + 3 * kerplanecount].x * X6.x) + (Kodiag[ker_baseidx + 3 * kerplanecount].x * X6.y) + (Kodiag[ker_baseidx + 3 * kerplanecount].y * X6.z);
			F6.y = (Kodiag[ker_baseidx + 3 * kerplanecount].x * X6.x) + (Kdiag[ker_baseidx + 3 * kerplanecount].y * X6.y) + (Kodiag[ker_baseidx + 3 * kerplanecount].z * X6.z);
			F6.z = (Kodiag[ker_baseidx + 3 * kerplanecount].y * X6.x) + (Kodiag[ker_baseidx + 3 * kerplanecount].z * X6.y) + (Kdiag[ker_baseidx + 3 * kerplanecount].z * X6.z);

			F1.x = (Kdiag[ker_baseidx + 4 * kerplanecount].x * X1.x) + (Kodiag[ker_baseidx + 4 * kerplanecount].x * X1.y) + (Kodiag[ker_baseidx + 4 * kerplanecount].y * X1.z);
			F1.y = (Kodiag[ker_baseidx + 4 * kerplanecount].x * X1.x) + (Kdiag[ker_baseidx + 4 * kerplanecount].y * X1.y) + (Kodiag[ker_baseidx + 4 * kerplanecount].z * X1.z);
			F1.z = (Kodiag[ker_baseidx + 4 * kerplanecount].y * X1.x) + (Kodiag[ker_baseidx + 4 * kerplanecount].z * X1.y) + (Kdiag[ker_baseidx + 4 * kerplanecount].z * X1.z);

			F5.x = (Kdiag[ker_baseidx + 3 * kerplanecount].x * X5.x) + (Kodiag[ker_baseidx + 3 * kerplanecount].x * X5.y) + (-Kodiag[ker_baseidx + 3 * kerplanecount].y * X5.z);
			F5.y = (Kodiag[ker_baseidx + 3 * kerplanecount].x * X5.x) + (Kdiag[ker_baseidx + 3 * kerplanecount].y * X5.y) + (-Kodiag[ker_baseidx + 3 * kerplanecount].z * X5.z);
			F5.z = (-Kodiag[ker_baseidx + 3 * kerplanecount].y * X5.x) + (-Kodiag[ker_baseidx + 3 * kerplanecount].z * X5.y) + (Kdiag[ker_baseidx + 3 * kerplanecount].z * X5.z);

			F3.x = (Kdiag[ker_baseidx + 2 * kerplanecount].x * X3.x) + (Kodiag[ker_baseidx + 2 * kerplanecount].x * X3.y) + (-Kodiag[ker_baseidx + 2 * kerplanecount].y * X3.z);
			F3.y = (Kodiag[ker_baseidx + 2 * kerplanecount].x * X3.x) + (Kdiag[ker_baseidx + 2 * kerplanecount].y * X3.y) + (-Kodiag[ker_baseidx + 2 * kerplanecount].z * X3.z);
			F3.z = (-Kodiag[ker_baseidx + 2 * kerplanecount].y * X3.x) + (-Kodiag[ker_baseidx + 2 * kerplanecount].z * X3.y) + (Kdiag[ker_baseidx + 2 * kerplanecount].z * X3.z);

			F7.x = (Kdiag[ker_baseidx + kerplanecount].x * X7.x) + (Kodiag[ker_baseidx + kerplanecount].x * X7.y) + (-Kodiag[ker_baseidx + kerplanecount].y * X7.z);
			F7.y = (Kodiag[ker_baseidx + kerplanecount].x * X7.x) + (Kdiag[ker_baseidx + kerplanecount].y * X7.y) + (-Kodiag[ker_baseidx + kerplanecount].z * X7.z);
			F7.z = (-Kodiag[ker_baseidx + kerplanecount].y * X7.x) + (-Kodiag[ker_baseidx + kerplanecount].z * X7.y) + (Kdiag[ker_baseidx + kerplanecount].z * X7.z);
		}
		else {

			int ker_baseidx = (N.y - i) + j * (N.y / 2 + 1);

			F0.x = (Kdiag[ker_baseidx].x * X0.x) + (-Kodiag[ker_baseidx].x * X0.y) + (Kodiag[ker_baseidx].y * X0.z);
			F0.y = (-Kodiag[ker_baseidx].x * X0.x) + (Kdiag[ker_baseidx].y * X0.y) + (-Kodiag[ker_baseidx].z * X0.z);
			F0.z = (Kodiag[ker_baseidx].y * X0.x) + (-Kodiag[ker_baseidx].z * X0.y) + (Kdiag[ker_baseidx].z * X0.z);

			F4.x = (Kdiag[ker_baseidx + kerplanecount].x * X4.x) + (-Kodiag[ker_baseidx + kerplanecount].x * X4.y) + (Kodiag[ker_baseidx + kerplanecount].y * X4.z);
			F4.y = (-Kodiag[ker_baseidx + kerplanecount].x * X4.x) + (Kdiag[ker_baseidx + kerplanecount].y * X4.y) + (-Kodiag[ker_baseidx + kerplanecount].z * X4.z);
			F4.z = (Kodiag[ker_baseidx + kerplanecount].y * X4.x) + (-Kodiag[ker_baseidx + kerplanecount].z * X4.y) + (Kdiag[ker_baseidx + kerplanecount].z * X4.z);

			F2.x = (Kdiag[ker_baseidx + 2 * kerplanecount].x * X2.x) + (-Kodiag[ker_baseidx + 2 * kerplanecount].x * X2.y) + (Kodiag[ker_baseidx + 2 * kerplanecount].y * X2.z);
			F2.y = (-Kodiag[ker_baseidx + 2 * kerplanecount].x * X2.x) + (Kdiag[ker_baseidx + 2 * kerplanecount].y * X2.y) + (-Kodiag[ker_baseidx + 2 * kerplanecount].z * X2.z);
			F2.z = (Kodiag[ker_baseidx + 2 * kerplanecount].y * X2.x) + (-Kodiag[ker_baseidx + 2 * kerplanecount].z * X2.y) + (Kdiag[ker_baseidx + 2 * kerplanecount].z * X2.z);

			F6.x = (Kdiag[ker_baseidx + 3 * kerplanecount].x * X6.x) + (-Kodiag[ker_baseidx + 3 * kerplanecount].x * X6.y) + (Kodiag[ker_baseidx + 3 * kerplanecount].y * X6.z);
			F6.y = (-Kodiag[ker_baseidx + 3 * kerplanecount].x * X6.x) + (Kdiag[ker_baseidx + 3 * kerplanecount].y * X6.y) + (-Kodiag[ker_baseidx + 3 * kerplanecount].z * X6.z);
			F6.z = (Kodiag[ker_baseidx + 3 * kerplanecount].y * X6.x) + (-Kodiag[ker_baseidx + 3 * kerplanecount].z * X6.y) + (Kdiag[ker_baseidx + 3 * kerplanecount].z * X6.z);

			F1.x = (Kdiag[ker_baseidx + 4 * kerplanecount].x * X1.x) + (-Kodiag[ker_baseidx + 4 * kerplanecount].x * X1.y) + (Kodiag[ker_baseidx + 4 * kerplanecount].y * X1.z);
			F1.y = (-Kodiag[ker_baseidx + 4 * kerplanecount].x * X1.x) + (Kdiag[ker_baseidx + 4 * kerplanecount].y * X1.y) + (-Kodiag[ker_baseidx + 4 * kerplanecount].z * X1.z);
			F1.z = (Kodiag[ker_baseidx + 4 * kerplanecount].y * X1.x) + (-Kodiag[ker_baseidx + 4 * kerplanecount].z * X1.y) + (Kdiag[ker_baseidx + 4 * kerplanecount].z * X1.z);

			F5.x = (Kdiag[ker_baseidx + 3 * kerplanecount].x * X5.x) + (-Kodiag[ker_baseidx + 3 * kerplanecount].x * X5.y) + (-Kodiag[ker_baseidx + 3 * kerplanecount].y * X5.z);
			F5.y = (-Kodiag[ker_baseidx + 3 * kerplanecount].x * X5.x) + (Kdiag[ker_baseidx + 3 * kerplanecount].y * X5.y) + (Kodiag[ker_baseidx + 3 * kerplanecount].z * X5.z);
			F5.z = (-Kodiag[ker_baseidx + 3 * kerplanecount].y * X5.x) + (Kodiag[ker_baseidx + 3 * kerplanecount].z * X5.y) + (Kdiag[ker_baseidx + 3 * kerplanecount].z * X5.z);

			F3.x = (Kdiag[ker_baseidx + 2 * kerplanecount].x * X3.x) + (-Kodiag[ker_baseidx + 2 * kerplanecount].x * X3.y) + (-Kodiag[ker_baseidx + 2 * kerplanecount].y * X3.z);
			F3.y = (-Kodiag[ker_baseidx + 2 * kerplanecount].x * X3.x) + (Kdiag[ker_baseidx + 2 * kerplanecount].y * X3.y) + (Kodiag[ker_baseidx + 2 * kerplanecount].z * X3.z);
			F3.z = (-Kodiag[ker_baseidx + 2 * kerplanecount].y * X3.x) + (Kodiag[ker_baseidx + 2 * kerplanecount].z * X3.y) + (Kdiag[ker_baseidx + 2 * kerplanecount].z * X3.z);

			F7.x = (Kdiag[ker_baseidx + kerplanecount].x * X7.x) + (-Kodiag[ker_baseidx + kerplanecount].x * X7.y) + (-Kodiag[ker_baseidx + kerplanecount].y * X7.z);
			F7.y = (-Kodiag[ker_baseidx + kerplanecount].x * X7.x) + (Kdiag[ker_baseidx + kerplanecount].y * X7.y) + (Kodiag[ker_baseidx + kerplanecount].z * X7.z);
			F7.z = (-Kodiag[ker_baseidx + kerplanecount].y * X7.x) + (Kodiag[ker_baseidx + kerplanecount].z * X7.y) + (Kdiag[ker_baseidx + kerplanecount].z * X7.z);
		}

		//inverse z-axis fft (but without division by 8). Also only keep first 4 points.

		//Radix-2 step
		X0 = F0 + F1;
		X1 = F0 - F1;

		X2 = F2 + F3;
		X3 = F2 - F3;

		X4 = F4 + F5;
		X5 = F4 - F5;

		X6 = F6 + F7;
		X7 = F6 - F7;

		//Radix-4 step
		cuReIm3 t0 = X0 + X2;
		cuReIm3 t1 = X0 - X2;
		cuReIm3 t2 = X4 + X6;
		cuReIm3 t3 = !(X6 - X4);

		X0 = (t0 + t2);
		X2 = (t1 - t3);

		t0 = X1 + !X3;
		t1 = X1 - !X3;
		t2 = X5 * cuReIm(a, a) + X7 * cuReIm(-a, a);
		t3 = X7 * cuReIm(-a, -a) - X5 * cuReIm(-a, a);

		X1 = (t0 + t2);
		X3 = (t1 - t3);

		cuSx[idx] = X0.x;
		cuSy[idx] = X0.y;
		cuSz[idx] = X0.z;

		cuSx[idx + planecount] = X1.x;
		cuSy[idx + planecount] = X1.y;
		cuSz[idx + planecount] = X1.z;
		
		cuSx[idx + 2*planecount] = X2.x;
		cuSy[idx + 2*planecount] = X2.y;
		cuSz[idx + 2*planecount] = X2.z;

		cuSx[idx + 3*planecount] = X3.x;
		cuSy[idx + 3*planecount] = X3.y;
		cuSz[idx + 3*planecount] = X3.z;

#undef a
	}
}

//N = (N.x/2 + 1, N.y, 16)
//xy is transposed
__global__ void cu_Demag_ConvProd_q2D_16_transpose_xy(cuVEC<cuReal3>& Kdiag, cuVEC<cuReal3>& Kodiag, cuComplex* cuSx, cuComplex* cuSy, cuComplex* cuSz, cuSZ3& N)
{
	//above N.z/2 and N.y/2 use kernel symmetries to recover kernel values
	//diagonal components are even about the N.z/2 and N.y/2 points
	//Kxy is even about N.z/2 and odd about N.y/2
	//Kxz is odd about N.z/2 and even about N.y/2
	//Kyz is odd about N.z/2 and odd about N.y/2

	int idx = blockDim.x * blockIdx.x + threadIdx.x;

	//N.z = 16, and this kernel was called with (N.x/2 + 1) * N.y points: handle all z points in one go
	int planecount = (N.x / 2 + 1) * N.y;

	//kernels packed into planes of (N.y / 2 + 1) * (N.x / 2 + 1) size
	int kerplanecount = (N.x / 2 + 1) * (N.y / 2 + 1);

	if (idx < planecount) {

		//the z-axis points (the others are zero)
		cuReIm3 x0 = cuReIm3(cuSx[idx], cuSy[idx], cuSz[idx]);
		cuReIm3 x1 = cuReIm3(cuSx[idx + planecount], cuSy[idx + planecount], cuSz[idx + planecount]);
		cuReIm3 x2 = cuReIm3(cuSx[idx + 2 * planecount], cuSy[idx + 2 * planecount], cuSz[idx + 2 * planecount]);
		cuReIm3 x3 = cuReIm3(cuSx[idx + 3 * planecount], cuSy[idx + 3 * planecount], cuSz[idx + 3 * planecount]);
		cuReIm3 x4 = cuReIm3(cuSx[idx + 4 * planecount], cuSy[idx + 4 * planecount], cuSz[idx + 4 * planecount]);
		cuReIm3 x5 = cuReIm3(cuSx[idx + 5 * planecount], cuSy[idx + 5 * planecount], cuSz[idx + 5 * planecount]);
		cuReIm3 x6 = cuReIm3(cuSx[idx + 6 * planecount], cuSy[idx + 6 * planecount], cuSz[idx + 6 * planecount]);
		cuReIm3 x7 = cuReIm3(cuSx[idx + 7 * planecount], cuSy[idx + 7 * planecount], cuSz[idx + 7 * planecount]);

#define a	(cuReal)9.238795325113E-01
#define b	(cuReal)3.826834323651E-01
#define c	(cuReal)7.071067811865E-01

		//First stage
		cuReIm3 X0 = x0 + x4;
		cuReIm3 X4 = x0 - x4;
		cuReIm3 X8 = x0 - !x4;
		cuReIm3 X12 = x0 + !x4;

		cuReIm3 X1 = x1 + x5;
		cuReIm3 X5 = (x1 - x5) * cuReIm(c, -c);
		cuReIm3 X9 = (x1 - !x5) * cuReIm(a, -b);
		cuReIm3 X13 = (x1 + !x5) * cuReIm(b, -a);

		cuReIm3 X2 = x2 + x6;
		cuReIm3 X6 = !(x6 - x2);
		cuReIm3 X10 = (x2 - !x6) * cuReIm(c, -c);
		cuReIm3 X14 = (x2 + !x6) * cuReIm(-c, -c);

		cuReIm3 X3 = x3 + x7;
		cuReIm3 X7 = (x3 - x7) * cuReIm(-c, -c);
		cuReIm3 X11 = (x3 - !x7) * cuReIm(b, -a);
		cuReIm3 X15 = (x3 + !x7) * cuReIm(-a, b);

		//Second stage
		cuReIm3 t0 = X0 + X2;
		cuReIm3 t1 = X0 - X2;
		cuReIm3 t2 = X1 + X3;
		cuReIm3 t3 = !(X3 - X1);

		X0 = t0 + t2;
		X1 = t0 - t2;
		X2 = t1 + t3;
		X3 = t1 - t3;

		t0 = X4 + X6;
		t1 = X4 - X6;
		t2 = X5 + X7;
		t3 = !(X7 - X5);

		X4 = t0 + t2;
		X5 = t0 - t2;
		X6 = t1 + t3;
		X7 = t1 - t3;

		t0 = X8 + X10;
		t1 = X8 - X10;
		t2 = X9 + X11;
		t3 = !(X11 - X9);

		X8 = t0 + t2;
		X9 = t0 - t2;
		X10 = t1 + t3;
		X11 = t1 - t3;

		t0 = X12 + X14;
		t1 = X12 - X14;
		t2 = X13 + X15;
		t3 = !(X15 - X13);

		X12 = t0 + t2;
		X13 = t0 - t2;
		X14 = t1 + t3;
		X15 = t1 - t3;

		//output is shuffled now, i.e. it is ordered as:
		//X0, X8, X4, X12, X2, X10, X6, X14, X1, X9, X5, X13, X3, X11, X7, X15

		cuReIm3 F0, F1, F2, F3, F4, F5, F6, F7, F8, F9, F10, F11, F12, F13, F14, F15;

		int i = idx % N.y;
		int j = (idx / N.y) % (N.x / 2 + 1);

		if (i <= N.y / 2) {

			int ker_baseidx = i + j * (N.y / 2 + 1);

			F0.x = (Kdiag[ker_baseidx].x * X0.x) + (Kodiag[ker_baseidx].x * X0.y) + (Kodiag[ker_baseidx].y * X0.z);
			F0.y = (Kodiag[ker_baseidx].x * X0.x) + (Kdiag[ker_baseidx].y * X0.y) + (Kodiag[ker_baseidx].z * X0.z);
			F0.z = (Kodiag[ker_baseidx].y * X0.x) + (Kodiag[ker_baseidx].z * X0.y) + (Kdiag[ker_baseidx].z * X0.z);

			F8.x = (Kdiag[ker_baseidx + kerplanecount].x * X8.x) + (Kodiag[ker_baseidx + kerplanecount].x * X8.y) + (Kodiag[ker_baseidx + kerplanecount].y * X8.z);
			F8.y = (Kodiag[ker_baseidx + kerplanecount].x * X8.x) + (Kdiag[ker_baseidx + kerplanecount].y * X8.y) + (Kodiag[ker_baseidx + kerplanecount].z * X8.z);
			F8.z = (Kodiag[ker_baseidx + kerplanecount].y * X8.x) + (Kodiag[ker_baseidx + kerplanecount].z * X8.y) + (Kdiag[ker_baseidx + kerplanecount].z * X8.z);

			F4.x = (Kdiag[ker_baseidx + 2 * kerplanecount].x * X4.x) + (Kodiag[ker_baseidx + 2 * kerplanecount].x * X4.y) + (Kodiag[ker_baseidx + 2 * kerplanecount].y * X4.z);
			F4.y = (Kodiag[ker_baseidx + 2 * kerplanecount].x * X4.x) + (Kdiag[ker_baseidx + 2 * kerplanecount].y * X4.y) + (Kodiag[ker_baseidx + 2 * kerplanecount].z * X4.z);
			F4.z = (Kodiag[ker_baseidx + 2 * kerplanecount].y * X4.x) + (Kodiag[ker_baseidx + 2 * kerplanecount].z * X4.y) + (Kdiag[ker_baseidx + 2 * kerplanecount].z * X4.z);

			F12.x = (Kdiag[ker_baseidx + 3 * kerplanecount].x * X12.x) + (Kodiag[ker_baseidx + 3 * kerplanecount].x * X12.y) + (Kodiag[ker_baseidx + 3 * kerplanecount].y * X12.z);
			F12.y = (Kodiag[ker_baseidx + 3 * kerplanecount].x * X12.x) + (Kdiag[ker_baseidx + 3 * kerplanecount].y * X12.y) + (Kodiag[ker_baseidx + 3 * kerplanecount].z * X12.z);
			F12.z = (Kodiag[ker_baseidx + 3 * kerplanecount].y * X12.x) + (Kodiag[ker_baseidx + 3 * kerplanecount].z * X12.y) + (Kdiag[ker_baseidx + 3 * kerplanecount].z * X12.z);

			F2.x = (Kdiag[ker_baseidx + 4 * kerplanecount].x * X2.x) + (Kodiag[ker_baseidx + 4 * kerplanecount].x * X2.y) + (Kodiag[ker_baseidx + 4 * kerplanecount].y * X2.z);
			F2.y = (Kodiag[ker_baseidx + 4 * kerplanecount].x * X2.x) + (Kdiag[ker_baseidx + 4 * kerplanecount].y * X2.y) + (Kodiag[ker_baseidx + 4 * kerplanecount].z * X2.z);
			F2.z = (Kodiag[ker_baseidx + 4 * kerplanecount].y * X2.x) + (Kodiag[ker_baseidx + 4 * kerplanecount].z * X2.y) + (Kdiag[ker_baseidx + 4 * kerplanecount].z * X2.z);

			F10.x = (Kdiag[ker_baseidx + 5 * kerplanecount].x * X10.x) + (Kodiag[ker_baseidx + 5 * kerplanecount].x * X10.y) + (Kodiag[ker_baseidx + 5 * kerplanecount].y * X10.z);
			F10.y = (Kodiag[ker_baseidx + 5 * kerplanecount].x * X10.x) + (Kdiag[ker_baseidx + 5 * kerplanecount].y * X10.y) + (Kodiag[ker_baseidx + 5 * kerplanecount].z * X10.z);
			F10.z = (Kodiag[ker_baseidx + 5 * kerplanecount].y * X10.x) + (Kodiag[ker_baseidx + 5 * kerplanecount].z * X10.y) + (Kdiag[ker_baseidx + 5 * kerplanecount].z * X10.z);

			F6.x = (Kdiag[ker_baseidx + 6 * kerplanecount].x * X6.x) + (Kodiag[ker_baseidx + 6 * kerplanecount].x * X6.y) + (Kodiag[ker_baseidx + 6 * kerplanecount].y * X6.z);
			F6.y = (Kodiag[ker_baseidx + 6 * kerplanecount].x * X6.x) + (Kdiag[ker_baseidx + 6 * kerplanecount].y * X6.y) + (Kodiag[ker_baseidx + 6 * kerplanecount].z * X6.z);
			F6.z = (Kodiag[ker_baseidx + 6 * kerplanecount].y * X6.x) + (Kodiag[ker_baseidx + 6 * kerplanecount].z * X6.y) + (Kdiag[ker_baseidx + 6 * kerplanecount].z * X6.z);

			F14.x = (Kdiag[ker_baseidx + 7 * kerplanecount].x * X14.x) + (Kodiag[ker_baseidx + 7 * kerplanecount].x * X14.y) + (Kodiag[ker_baseidx + 7 * kerplanecount].y * X14.z);
			F14.y = (Kodiag[ker_baseidx + 7 * kerplanecount].x * X14.x) + (Kdiag[ker_baseidx + 7 * kerplanecount].y * X14.y) + (Kodiag[ker_baseidx + 7 * kerplanecount].z * X14.z);
			F14.z = (Kodiag[ker_baseidx + 7 * kerplanecount].y * X14.x) + (Kodiag[ker_baseidx + 7 * kerplanecount].z * X14.y) + (Kdiag[ker_baseidx + 7 * kerplanecount].z * X14.z);

			F1.x = (Kdiag[ker_baseidx + 8 * kerplanecount].x * X1.x) + (Kodiag[ker_baseidx + 8 * kerplanecount].x * X1.y) + (Kodiag[ker_baseidx + 8 * kerplanecount].y * X1.z);
			F1.y = (Kodiag[ker_baseidx + 8 * kerplanecount].x * X1.x) + (Kdiag[ker_baseidx + 8 * kerplanecount].y * X1.y) + (Kodiag[ker_baseidx + 8 * kerplanecount].z * X1.z);
			F1.z = (Kodiag[ker_baseidx + 8 * kerplanecount].y * X1.x) + (Kodiag[ker_baseidx + 8 * kerplanecount].z * X1.y) + (Kdiag[ker_baseidx + 8 * kerplanecount].z * X1.z);

			F9.x = (Kdiag[ker_baseidx + 7 * kerplanecount].x * X9.x) + (Kodiag[ker_baseidx + 7 * kerplanecount].x * X9.y) + (-Kodiag[ker_baseidx + 7 * kerplanecount].y * X9.z);
			F9.y = (Kodiag[ker_baseidx + 7 * kerplanecount].x * X9.x) + (Kdiag[ker_baseidx + 7 * kerplanecount].y * X9.y) + (-Kodiag[ker_baseidx + 7 * kerplanecount].z * X9.z);
			F9.z = (-Kodiag[ker_baseidx + 7 * kerplanecount].y * X9.x) + (-Kodiag[ker_baseidx + 7 * kerplanecount].z * X9.y) + (Kdiag[ker_baseidx + 7 * kerplanecount].z * X9.z);

			F5.x = (Kdiag[ker_baseidx + 6 * kerplanecount].x * X5.x) + (Kodiag[ker_baseidx + 6 * kerplanecount].x * X5.y) + (-Kodiag[ker_baseidx + 6 * kerplanecount].y * X5.z);
			F5.y = (Kodiag[ker_baseidx + 6 * kerplanecount].x * X5.x) + (Kdiag[ker_baseidx + 6 * kerplanecount].y * X5.y) + (-Kodiag[ker_baseidx + 6 * kerplanecount].z * X5.z);
			F5.z = (-Kodiag[ker_baseidx + 6 * kerplanecount].y * X5.x) + (-Kodiag[ker_baseidx + 6 * kerplanecount].z * X5.y) + (Kdiag[ker_baseidx + 6 * kerplanecount].z * X5.z);

			F13.x = (Kdiag[ker_baseidx + 5 * kerplanecount].x * X13.x) + (Kodiag[ker_baseidx + 5 * kerplanecount].x * X13.y) + (-Kodiag[ker_baseidx + 5 * kerplanecount].y * X13.z);
			F13.y = (Kodiag[ker_baseidx + 5 * kerplanecount].x * X13.x) + (Kdiag[ker_baseidx + 5 * kerplanecount].y * X13.y) + (-Kodiag[ker_baseidx + 5 * kerplanecount].z * X13.z);
			F13.z = (-Kodiag[ker_baseidx + 5 * kerplanecount].y * X13.x) + (-Kodiag[ker_baseidx + 5 * kerplanecount].z * X13.y) + (Kdiag[ker_baseidx + 5 * kerplanecount].z * X13.z);

			F3.x = (Kdiag[ker_baseidx + 4 * kerplanecount].x * X3.x) + (Kodiag[ker_baseidx + 4 * kerplanecount].x * X3.y) + (-Kodiag[ker_baseidx + 4 * kerplanecount].y * X3.z);
			F3.y = (Kodiag[ker_baseidx + 4 * kerplanecount].x * X3.x) + (Kdiag[ker_baseidx + 4 * kerplanecount].y * X3.y) + (-Kodiag[ker_baseidx + 4 * kerplanecount].z * X3.z);
			F3.z = (-Kodiag[ker_baseidx + 4 * kerplanecount].y * X3.x) + (-Kodiag[ker_baseidx + 4 * kerplanecount].z * X3.y) + (Kdiag[ker_baseidx + 4 * kerplanecount].z * X3.z);

			F11.x = (Kdiag[ker_baseidx + 3 * kerplanecount].x * X11.x) + (Kodiag[ker_baseidx + 3 * kerplanecount].x * X11.y) + (-Kodiag[ker_baseidx + 3 * kerplanecount].y * X11.z);
			F11.y = (Kodiag[ker_baseidx + 3 * kerplanecount].x * X11.x) + (Kdiag[ker_baseidx + 3 * kerplanecount].y * X11.y) + (-Kodiag[ker_baseidx + 3 * kerplanecount].z * X11.z);
			F11.z = (-Kodiag[ker_baseidx + 3 * kerplanecount].y * X11.x) + (-Kodiag[ker_baseidx + 3 * kerplanecount].z * X11.y) + (Kdiag[ker_baseidx + 3 * kerplanecount].z * X11.z);

			F7.x = (Kdiag[ker_baseidx + 2 * kerplanecount].x * X7.x) + (Kodiag[ker_baseidx + 2 * kerplanecount].x * X7.y) + (-Kodiag[ker_baseidx + 2 * kerplanecount].y * X7.z);
			F7.y = (Kodiag[ker_baseidx + 2 * kerplanecount].x * X7.x) + (Kdiag[ker_baseidx + 2 * kerplanecount].y * X7.y) + (-Kodiag[ker_baseidx + 2 * kerplanecount].z * X7.z);
			F7.z = (-Kodiag[ker_baseidx + 2 * kerplanecount].y * X7.x) + (-Kodiag[ker_baseidx + 2 * kerplanecount].z * X7.y) + (Kdiag[ker_baseidx + 2 * kerplanecount].z * X7.z);

			F15.x = (Kdiag[ker_baseidx + kerplanecount].x * X15.x) + (Kodiag[ker_baseidx + kerplanecount].x * X15.y) + (-Kodiag[ker_baseidx + kerplanecount].y * X15.z);
			F15.y = (Kodiag[ker_baseidx + kerplanecount].x * X15.x) + (Kdiag[ker_baseidx + kerplanecount].y * X15.y) + (-Kodiag[ker_baseidx + kerplanecount].z * X15.z);
			F15.z = (-Kodiag[ker_baseidx + kerplanecount].y * X15.x) + (-Kodiag[ker_baseidx + kerplanecount].z * X15.y) + (Kdiag[ker_baseidx + kerplanecount].z * X15.z);
		}
		else {

			int ker_baseidx = (N.y - i) + j * (N.y / 2 + 1);

			F0.x = (Kdiag[ker_baseidx].x * X0.x) + (-Kodiag[ker_baseidx].x * X0.y) + (Kodiag[ker_baseidx].y * X0.z);
			F0.y = (-Kodiag[ker_baseidx].x * X0.x) + (Kdiag[ker_baseidx].y * X0.y) + (-Kodiag[ker_baseidx].z * X0.z);
			F0.z = (Kodiag[ker_baseidx].y * X0.x) + (-Kodiag[ker_baseidx].z * X0.y) + (Kdiag[ker_baseidx].z * X0.z);

			F8.x = (Kdiag[ker_baseidx + kerplanecount].x * X8.x) + (-Kodiag[ker_baseidx + kerplanecount].x * X8.y) + (Kodiag[ker_baseidx + kerplanecount].y * X8.z);
			F8.y = (-Kodiag[ker_baseidx + kerplanecount].x * X8.x) + (Kdiag[ker_baseidx + kerplanecount].y * X8.y) + (-Kodiag[ker_baseidx + kerplanecount].z * X8.z);
			F8.z = (Kodiag[ker_baseidx + kerplanecount].y * X8.x) + (-Kodiag[ker_baseidx + kerplanecount].z * X8.y) + (Kdiag[ker_baseidx + kerplanecount].z * X8.z);

			F4.x = (Kdiag[ker_baseidx + 2 * kerplanecount].x * X4.x) + (-Kodiag[ker_baseidx + 2 * kerplanecount].x * X4.y) + (Kodiag[ker_baseidx + 2 * kerplanecount].y * X4.z);
			F4.y = (-Kodiag[ker_baseidx + 2 * kerplanecount].x * X4.x) + (Kdiag[ker_baseidx + 2 * kerplanecount].y * X4.y) + (-Kodiag[ker_baseidx + 2 * kerplanecount].z * X4.z);
			F4.z = (Kodiag[ker_baseidx + 2 * kerplanecount].y * X4.x) + (-Kodiag[ker_baseidx + 2 * kerplanecount].z * X4.y) + (Kdiag[ker_baseidx + 2 * kerplanecount].z * X4.z);

			F12.x = (Kdiag[ker_baseidx + 3 * kerplanecount].x * X12.x) + (-Kodiag[ker_baseidx + 3 * kerplanecount].x * X12.y) + (Kodiag[ker_baseidx + 3 * kerplanecount].y * X12.z);
			F12.y = (-Kodiag[ker_baseidx + 3 * kerplanecount].x * X12.x) + (Kdiag[ker_baseidx + 3 * kerplanecount].y * X12.y) + (-Kodiag[ker_baseidx + 3 * kerplanecount].z * X12.z);
			F12.z = (Kodiag[ker_baseidx + 3 * kerplanecount].y * X12.x) + (-Kodiag[ker_baseidx + 3 * kerplanecount].z * X12.y) + (Kdiag[ker_baseidx + 3 * kerplanecount].z * X12.z);

			F2.x = (Kdiag[ker_baseidx + 4 * kerplanecount].x * X2.x) + (-Kodiag[ker_baseidx + 4 * kerplanecount].x * X2.y) + (Kodiag[ker_baseidx + 4 * kerplanecount].y * X2.z);
			F2.y = (-Kodiag[ker_baseidx + 4 * kerplanecount].x * X2.x) + (Kdiag[ker_baseidx + 4 * kerplanecount].y * X2.y) + (-Kodiag[ker_baseidx + 4 * kerplanecount].z * X2.z);
			F2.z = (Kodiag[ker_baseidx + 4 * kerplanecount].y * X2.x) + (-Kodiag[ker_baseidx + 4 * kerplanecount].z * X2.y) + (Kdiag[ker_baseidx + 4 * kerplanecount].z * X2.z);

			F10.x = (Kdiag[ker_baseidx + 5 * kerplanecount].x * X10.x) + (-Kodiag[ker_baseidx + 5 * kerplanecount].x * X10.y) + (Kodiag[ker_baseidx + 5 * kerplanecount].y * X10.z);
			F10.y = (-Kodiag[ker_baseidx + 5 * kerplanecount].x * X10.x) + (Kdiag[ker_baseidx + 5 * kerplanecount].y * X10.y) + (-Kodiag[ker_baseidx + 5 * kerplanecount].z * X10.z);
			F10.z = (Kodiag[ker_baseidx + 5 * kerplanecount].y * X10.x) + (-Kodiag[ker_baseidx + 5 * kerplanecount].z * X10.y) + (Kdiag[ker_baseidx + 5 * kerplanecount].z * X10.z);

			F6.x = (Kdiag[ker_baseidx + 6 * kerplanecount].x * X6.x) + (-Kodiag[ker_baseidx + 6 * kerplanecount].x * X6.y) + (Kodiag[ker_baseidx + 6 * kerplanecount].y * X6.z);
			F6.y = (-Kodiag[ker_baseidx + 6 * kerplanecount].x * X6.x) + (Kdiag[ker_baseidx + 6 * kerplanecount].y * X6.y) + (-Kodiag[ker_baseidx + 6 * kerplanecount].z * X6.z);
			F6.z = (Kodiag[ker_baseidx + 6 * kerplanecount].y * X6.x) + (-Kodiag[ker_baseidx + 6 * kerplanecount].z * X6.y) + (Kdiag[ker_baseidx + 6 * kerplanecount].z * X6.z);

			F14.x = (Kdiag[ker_baseidx + 7 * kerplanecount].x * X14.x) + (-Kodiag[ker_baseidx + 7 * kerplanecount].x * X14.y) + (Kodiag[ker_baseidx + 7 * kerplanecount].y * X14.z);
			F14.y = (-Kodiag[ker_baseidx + 7 * kerplanecount].x * X14.x) + (Kdiag[ker_baseidx + 7 * kerplanecount].y * X14.y) + (-Kodiag[ker_baseidx + 7 * kerplanecount].z * X14.z);
			F14.z = (Kodiag[ker_baseidx + 7 * kerplanecount].y * X14.x) + (-Kodiag[ker_baseidx + 7 * kerplanecount].z * X14.y) + (Kdiag[ker_baseidx + 7 * kerplanecount].z * X14.z);

			F1.x = (Kdiag[ker_baseidx + 8 * kerplanecount].x * X1.x) + (-Kodiag[ker_baseidx + 8 * kerplanecount].x * X1.y) + (Kodiag[ker_baseidx + 8 * kerplanecount].y * X1.z);
			F1.y = (-Kodiag[ker_baseidx + 8 * kerplanecount].x * X1.x) + (Kdiag[ker_baseidx + 8 * kerplanecount].y * X1.y) + (-Kodiag[ker_baseidx + 8 * kerplanecount].z * X1.z);
			F1.z = (Kodiag[ker_baseidx + 8 * kerplanecount].y * X1.x) + (-Kodiag[ker_baseidx + 8 * kerplanecount].z * X1.y) + (Kdiag[ker_baseidx + 8 * kerplanecount].z * X1.z);

			F9.x = (Kdiag[ker_baseidx + 7 * kerplanecount].x * X9.x) + (-Kodiag[ker_baseidx + 7 * kerplanecount].x * X9.y) + (-Kodiag[ker_baseidx + 7 * kerplanecount].y * X9.z);
			F9.y = (-Kodiag[ker_baseidx + 7 * kerplanecount].x * X9.x) + (Kdiag[ker_baseidx + 7 * kerplanecount].y * X9.y) + (Kodiag[ker_baseidx + 7 * kerplanecount].z * X9.z);
			F9.z = (-Kodiag[ker_baseidx + 7 * kerplanecount].y * X9.x) + (Kodiag[ker_baseidx + 7 * kerplanecount].z * X9.y) + (Kdiag[ker_baseidx + 7 * kerplanecount].z * X9.z);

			F5.x = (Kdiag[ker_baseidx + 6 * kerplanecount].x * X5.x) + (-Kodiag[ker_baseidx + 6 * kerplanecount].x * X5.y) + (-Kodiag[ker_baseidx + 6 * kerplanecount].y * X5.z);
			F5.y = (-Kodiag[ker_baseidx + 6 * kerplanecount].x * X5.x) + (Kdiag[ker_baseidx + 6 * kerplanecount].y * X5.y) + (Kodiag[ker_baseidx + 6 * kerplanecount].z * X5.z);
			F5.z = (-Kodiag[ker_baseidx + 6 * kerplanecount].y * X5.x) + (Kodiag[ker_baseidx + 6 * kerplanecount].z * X5.y) + (Kdiag[ker_baseidx + 6 * kerplanecount].z * X5.z);

			F13.x = (Kdiag[ker_baseidx + 5 * kerplanecount].x * X13.x) + (-Kodiag[ker_baseidx + 5 * kerplanecount].x * X13.y) + (-Kodiag[ker_baseidx + 5 * kerplanecount].y * X13.z);
			F13.y = (-Kodiag[ker_baseidx + 5 * kerplanecount].x * X13.x) + (Kdiag[ker_baseidx + 5 * kerplanecount].y * X13.y) + (Kodiag[ker_baseidx + 5 * kerplanecount].z * X13.z);
			F13.z = (-Kodiag[ker_baseidx + 5 * kerplanecount].y * X13.x) + (Kodiag[ker_baseidx + 5 * kerplanecount].z * X13.y) + (Kdiag[ker_baseidx + 5 * kerplanecount].z * X13.z);

			F3.x = (Kdiag[ker_baseidx + 4 * kerplanecount].x * X3.x) + (-Kodiag[ker_baseidx + 4 * kerplanecount].x * X3.y) + (-Kodiag[ker_baseidx + 4 * kerplanecount].y * X3.z);
			F3.y = (-Kodiag[ker_baseidx + 4 * kerplanecount].x * X3.x) + (Kdiag[ker_baseidx + 4 * kerplanecount].y * X3.y) + (Kodiag[ker_baseidx + 4 * kerplanecount].z * X3.z);
			F3.z = (-Kodiag[ker_baseidx + 4 * kerplanecount].y * X3.x) + (Kodiag[ker_baseidx + 4 * kerplanecount].z * X3.y) + (Kdiag[ker_baseidx + 4 * kerplanecount].z * X3.z);

			F11.x = (Kdiag[ker_baseidx + 3 * kerplanecount].x * X11.x) + (-Kodiag[ker_baseidx + 3 * kerplanecount].x * X11.y) + (-Kodiag[ker_baseidx + 3 * kerplanecount].y * X11.z);
			F11.y = (-Kodiag[ker_baseidx + 3 * kerplanecount].x * X11.x) + (Kdiag[ker_baseidx + 3 * kerplanecount].y * X11.y) + (Kodiag[ker_baseidx + 3 * kerplanecount].z * X11.z);
			F11.z = (-Kodiag[ker_baseidx + 3 * kerplanecount].y * X11.x) + (Kodiag[ker_baseidx + 3 * kerplanecount].z * X11.y) + (Kdiag[ker_baseidx + 3 * kerplanecount].z * X11.z);

			F7.x = (Kdiag[ker_baseidx + 2 * kerplanecount].x * X7.x) + (-Kodiag[ker_baseidx + 2 * kerplanecount].x * X7.y) + (-Kodiag[ker_baseidx + 2 * kerplanecount].y * X7.z);
			F7.y = (-Kodiag[ker_baseidx + 2 * kerplanecount].x * X7.x) + (Kdiag[ker_baseidx + 2 * kerplanecount].y * X7.y) + (Kodiag[ker_baseidx + 2 * kerplanecount].z * X7.z);
			F7.z = (-Kodiag[ker_baseidx + 2 * kerplanecount].y * X7.x) + (Kodiag[ker_baseidx + 2 * kerplanecount].z * X7.y) + (Kdiag[ker_baseidx + 2 * kerplanecount].z * X7.z);

			F15.x = (Kdiag[ker_baseidx + kerplanecount].x * X15.x) + (-Kodiag[ker_baseidx + kerplanecount].x * X15.y) + (-Kodiag[ker_baseidx + kerplanecount].y * X15.z);
			F15.y = (-Kodiag[ker_baseidx + kerplanecount].x * X15.x) + (Kdiag[ker_baseidx + kerplanecount].y * X15.y) + (Kodiag[ker_baseidx + kerplanecount].z * X15.z);
			F15.z = (-Kodiag[ker_baseidx + kerplanecount].y * X15.x) + (Kodiag[ker_baseidx + kerplanecount].z * X15.y) + (Kdiag[ker_baseidx + kerplanecount].z * X15.z);
		}

		//inverse z-axis fft (but without division by 16). Also only keep first 8 points.

		//First stage
		t0 = F0 + F1;
		t1 = F0 - F1;
		t2 = F2 + F3;
		t3 = !(F3 - F2);

		X0 = t0 + t2;
		X1 = t1 - t3;
		X2 = t0 - t2;
		X3 = t1 + t3;

		t0 = F4 + F5;
		t1 = F4 - F5;
		t2 = F6 + F7;
		t3 = !(F7 - F6);

		X4 = t0 + t2;
		X5 = t1 - t3;
		X6 = t0 - t2;
		X7 = t1 + t3;

		t0 = F8 + F9;
		t1 = F8 - F9;
		t2 = F10 + F11;
		t3 = !(F11 - F10);

		X8 = t0 + t2;
		X9 = t1 - t3;
		X10 = t0 - t2;
		X11 = t1 + t3;

		t0 = F12 + F13;
		t1 = F12 - F13;
		t2 = F14 + F15;
		t3 = !(F15 - F14);

		X12 = t0 + t2;
		X13 = t1 - t3;
		X14 = t0 - t2;
		X15 = t1 + t3;

		//Second stage

		t0 = X0 + X4;
		t1 = X0 - X4;
		t2 = X8 + X12;
		t3 = !(X12 - X8);

		X0 = t0 + t2;
		X4 = t1 - t3;

		t0 = X1 + X5 * cuReIm(c, c);
		t1 = X1 - X5 * cuReIm(c, c);
		t2 = X9 * cuReIm(a, b) + X13 * cuReIm(b, a);
		t3 = (X13 * cuReIm(-a, b) - X9 * cuReIm(-b, a));

		X1 = t0 + t2;
		X5 = t1 - t3;

		t0 = X2 + !X6;
		t1 = X2 - !X6;
		t2 = X10 * cuReIm(c, c) + X14 * cuReIm(-c, c);
		t3 = (X14 * cuReIm(-c, -c) - X10 * cuReIm(-c, c));

		X2 = t0 + t2;
		X6 = t1 - t3;

		t0 = X3 + X7 * cuReIm(-c, c);
		t1 = X3 - X7 * cuReIm(-c, c);
		t2 = X11 * cuReIm(b, a) + X15 * cuReIm(-a, -b);
		t3 = (X15 * cuReIm(b, -a) - X11 * cuReIm(-a, b));

		X3 = t0 + t2;
		X7 = t1 - t3;
		
		cuSx[idx] = X0.x;
		cuSy[idx] = X0.y;
		cuSz[idx] = X0.z;
		cuSx[idx + 4 * planecount] = X4.x;
		cuSy[idx + 4 * planecount] = X4.y;
		cuSz[idx + 4 * planecount] = X4.z;

		cuSx[idx + 1 * planecount] = X1.x;
		cuSy[idx + 1 * planecount] = X1.y;
		cuSz[idx + 1 * planecount] = X1.z;
		cuSx[idx + 5 * planecount] = X5.x;
		cuSy[idx + 5 * planecount] = X5.y;
		cuSz[idx + 5 * planecount] = X5.z;

		cuSx[idx + 2 * planecount] = X2.x;
		cuSy[idx + 2 * planecount] = X2.y;
		cuSz[idx + 2 * planecount] = X2.z;
		cuSx[idx + 6 * planecount] = X6.x;
		cuSy[idx + 6 * planecount] = X6.y;
		cuSz[idx + 6 * planecount] = X6.z;

		cuSx[idx + 3 * planecount] = X3.x;
		cuSy[idx + 3 * planecount] = X3.y;
		cuSz[idx + 3 * planecount] = X3.z;
		cuSx[idx + 7 * planecount] = X7.x;
		cuSy[idx + 7 * planecount] = X7.y;
		cuSz[idx + 7 * planecount] = X7.z;

#undef a
#undef b
#undef c
	}
}

//N = (N.x/2 + 1, N.y, 32)
//xy is transposed
__global__ void cu_Demag_ConvProd_q2D_32_transpose_xy(cuVEC<cuReal3>& Kdiag, cuVEC<cuReal3>& Kodiag, cuComplex* cuSx, cuComplex* cuSy, cuComplex* cuSz, cuSZ3& N)
{
	//above N.z/2 and N.y/2 use kernel symmetries to recover kernel values
	//diagonal components are even about the N.z/2 and N.y/2 points
	//Kxy is even about N.z/2 and odd about N.y/2
	//Kxz is odd about N.z/2 and even about N.y/2
	//Kyz is odd about N.z/2 and odd about N.y/2

	int idx = blockDim.x * blockIdx.x + threadIdx.x;

	//N.z = 32, and this kernel was called with (N.x/2 + 1) * N.y points: handle all z points in one go
	int planecount = (N.x / 2 + 1) * N.y;

	//kernels packed into planes of (N.y / 2 + 1) * (N.x / 2 + 1) size
	int kerplanecount = (N.x / 2 + 1) * (N.y / 2 + 1);

	if (idx < planecount) {

		//input data
#define x(n)	(cuReIm3(cuSx[idx + (n) * planecount], cuSy[idx + (n) * planecount], cuSz[idx + (n) * planecount]))

		//no performance gain to be had from setting these as X0, X1, ... etc.
		//unrolling loops does make a slight difference though - probably last case for which you want to unroll loops
		cuReIm3 X[32];

		cuReIm3 t0, t1, t2, t3;

		//input stage

#define a	(cuReal)0.980785280403230
#define b	(cuReal)0.195090322016128
#define c	(cuReal)0.923879532511287
#define d	(cuReal)0.382683432365090
#define e	(cuReal)0.831469612302545
#define f	(cuReal)0.555570233019602
#define g	(cuReal)0.707106781186548

		//j = 0
		X[0] = (x(0) + x(8));
		X[8] = (x(0) - x(8));
		X[16] = (x(0) - !x(8));
		X[24] = (x(0) + !x(8));

		//j = 1
		X[1] = (x(1) + x(9));
		X[9] = (x(1) - x(9)) * cuReIm(c, -d);
		X[17] = (x(1) - !x(9)) * cuReIm(a, -b);
		X[25] = (x(1) + !x(9)) * cuReIm(e, -f);

		//j = 2
		X[2] = (x(2) + x(10));
		X[10] = (x(2) - x(10)) * cuReIm(g, -g);
		X[18] = (x(2) - !x(10)) * cuReIm(c, -d);
		X[26] = (x(2) + !x(10)) * cuReIm(d, -c);

		//j = 3
		X[3] = (x(3) + x(11));
		X[11] = (x(3) - x(11)) * cuReIm(d, -c);
		X[19] = (x(3) - !x(11)) * cuReIm(e, -f);
		X[27] = (x(3) + !x(11)) * cuReIm(-b, -a);

		//j = 4
		X[4] = (x(4) + x(12));
		X[12] = !(x(12) - x(4));
		X[20] = (x(4) - !x(12)) * cuReIm(g, -g);
		X[28] = (x(4) + !x(12)) * cuReIm(-g, -g);

		//j = 5
		X[5] = (x(5) + x(13));
		X[13] = (x(5) - x(13)) * cuReIm(-d, -c);
		X[21] = (x(5) - !x(13)) * cuReIm(f, -e);
		X[29] = (x(5) + !x(13)) * cuReIm(-a, -b);

		//j = 6
		X[6] = (x(6) + x(14));
		X[14] = (x(6) - x(14)) * cuReIm(-g, -g);
		X[22] = (x(6) - !x(14)) * cuReIm(d, -c);
		X[30] = (x(6) + !x(14)) * cuReIm(-c, d);

		//j = 7
		X[7] = (x(7) + x(15));
		X[15] = (x(7) - x(15)) * cuReIm(-c, -d);
		X[23] = (x(7) - !x(15)) * cuReIm(b, -a);
		X[31] = (x(7) + !x(15)) * cuReIm(-f, e);

#undef x

		//final radix4 stage

		//j = 0
		t0 = (X[0] + X[4]);
		t1 = (X[0] - X[4]);
		t2 = (X[2] + X[6]);
		t3 = !(X[6] - X[2]);

		X[0] = (t0 + t2);
		X[2] = (t0 - t2);
		X[4] = (t1 + t3);
		X[6] = (t1 - t3);

		t0 = (X[8] + X[12]);
		t1 = (X[8] - X[12]);
		t2 = (X[10] + X[14]);
		t3 = !(X[14] - X[10]);

		X[8] = (t0 + t2);
		X[10] = (t0 - t2);
		X[12] = (t1 + t3);
		X[14] = (t1 - t3);

		t0 = (X[16] + X[20]);
		t1 = (X[16] - X[20]);
		t2 = (X[18] + X[22]);
		t3 = !(X[22] - X[18]);

		X[16] = (t0 + t2);
		X[18] = (t0 - t2);
		X[20] = (t1 + t3);
		X[22] = (t1 - t3);

		t0 = (X[24] + X[28]);
		t1 = (X[24] - X[28]);
		t2 = (X[26] + X[30]);
		t3 = !(X[30] - X[26]);

		X[24] = (t0 + t2);
		X[26] = (t0 - t2);
		X[28] = (t1 + t3);
		X[30] = (t1 - t3);

		//j = 1
		t0 = (X[1] + X[5]);
		t1 = (X[1] - X[5]);
		t2 = (X[3] + X[7]);
		t3 = !(X[7] - X[3]);

		X[1] = (t0 + t2);
		X[3] = !(t2 - t0);
		X[5] = (t1 + t3) * cuReIm(g, -g);
		X[7] = (t1 - t3) * cuReIm(-g, -g);

		t0 = (X[9] + X[13]);
		t1 = (X[9] - X[13]);
		t2 = (X[11] + X[15]);
		t3 = !(X[15] - X[11]);

		X[9] = (t0 + t2);
		X[11] = !(t2 - t0);
		X[13] = (t1 + t3) * cuReIm(g, -g);
		X[15] = (t1 - t3) * cuReIm(-g, -g);

		t0 = (X[17] + X[21]);
		t1 = (X[17] - X[21]);
		t2 = (X[19] + X[23]);
		t3 = !(X[23] - X[19]);

		X[17] = (t0 + t2);
		X[19] = !(t2 - t0);
		X[21] = (t1 + t3) * cuReIm(g, -g);
		X[23] = (t1 - t3) * cuReIm(-g, -g);

		t0 = (X[25] + X[29]);
		t1 = (X[25] - X[29]);
		t2 = (X[27] + X[31]);
		t3 = !(X[31] - X[27]);

		X[25] = (t0 + t2);
		X[27] = !(t2 - t0);
		X[29] = (t1 + t3) * cuReIm(g, -g);
		X[31] = (t1 - t3) * cuReIm(-g, -g);

		//radix-2 step to finish
		t0 = X[0] - X[1];
		X[0] = X[0] + X[1];
		X[1] = t0;

		t0 = X[2] - X[3];
		X[2] = X[2] + X[3];
		X[3] = t0;

		t0 = X[4] - X[5];
		X[4] = X[4] + X[5];
		X[5] = t0;

		t0 = X[6] - X[7];
		X[6] = X[6] + X[7];
		X[7] = t0;

		t0 = X[8] - X[9];
		X[8] = X[8] + X[9];
		X[9] = t0;

		t0 = X[10] - X[11];
		X[10] = X[10] + X[11];
		X[11] = t0;

		t0 = X[12] - X[13];
		X[12] = X[12] + X[13];
		X[13] = t0;

		t0 = X[14] - X[15];
		X[14] = X[14] + X[15];
		X[15] = t0;

		t0 = X[16] - X[17];
		X[16] = X[16] + X[17];
		X[17] = t0;

		t0 = X[18] - X[19];
		X[18] = X[18] + X[19];
		X[19] = t0;

		t0 = X[20] - X[21];
		X[20] = X[20] + X[21];
		X[21] = t0;

		t0 = X[22] - X[23];
		X[22] = X[22] + X[23];
		X[23] = t0;

		t0 = X[24] - X[25];
		X[24] = X[24] + X[25];
		X[25] = t0;

		t0 = X[26] - X[27];
		X[26] = X[26] + X[27];
		X[27] = t0;

		t0 = X[28] - X[29];
		X[28] = X[28] + X[29];
		X[29] = t0;

		t0 = X[30] - X[31];
		X[30] = X[30] + X[31];
		X[31] = t0;

		//output is shuffled now, i.e. it is ordered as:
		//0, 16, 8, 24, 4, 20, 12, 28, 2, 18, 10, 26, 6, 22, 14, 30, 1, 17, 9, 25, 5, 21, 13, 29, 3, 19, 11, 27, 7, 23, 15, 31

		int i = idx % N.y;
		int j = (idx / N.y) % (N.x / 2 + 1);

		cuReIm3 F[32];
		
		if (i <= N.y / 2) {

			int ker_baseidx = i + j * (N.y / 2 + 1);

			F[0].x = (Kdiag[ker_baseidx].x * X[0].x) + (Kodiag[ker_baseidx].x * X[0].y) + (Kodiag[ker_baseidx].y * X[0].z);
			F[0].y = (Kodiag[ker_baseidx].x * X[0].x) + (Kdiag[ker_baseidx].y * X[0].y) + (Kodiag[ker_baseidx].z * X[0].z);
			F[0].z = (Kodiag[ker_baseidx].y * X[0].x) + (Kodiag[ker_baseidx].z * X[0].y) + (Kdiag[ker_baseidx].z * X[0].z);

			F[16].x = (Kdiag[ker_baseidx + 1 * kerplanecount].x * X[16].x) + (Kodiag[ker_baseidx + 1 * kerplanecount].x * X[16].y) + (Kodiag[ker_baseidx + 1 * kerplanecount].y * X[16].z);
			F[16].y = (Kodiag[ker_baseidx + 1 * kerplanecount].x * X[16].x) + (Kdiag[ker_baseidx + 1 * kerplanecount].y * X[16].y) + (Kodiag[ker_baseidx + 1 * kerplanecount].z * X[16].z);
			F[16].z = (Kodiag[ker_baseidx + 1 * kerplanecount].y * X[16].x) + (Kodiag[ker_baseidx + 1 * kerplanecount].z * X[16].y) + (Kdiag[ker_baseidx + 1 * kerplanecount].z * X[16].z);

			F[8].x = (Kdiag[ker_baseidx + 2 * kerplanecount].x * X[8].x) + (Kodiag[ker_baseidx + 2 * kerplanecount].x * X[8].y) + (Kodiag[ker_baseidx + 2 * kerplanecount].y * X[8].z);
			F[8].y = (Kodiag[ker_baseidx + 2 * kerplanecount].x * X[8].x) + (Kdiag[ker_baseidx + 2 * kerplanecount].y * X[8].y) + (Kodiag[ker_baseidx + 2 * kerplanecount].z * X[8].z);
			F[8].z = (Kodiag[ker_baseidx + 2 * kerplanecount].y * X[8].x) + (Kodiag[ker_baseidx + 2 * kerplanecount].z * X[8].y) + (Kdiag[ker_baseidx + 2 * kerplanecount].z * X[8].z);

			F[24].x = (Kdiag[ker_baseidx + 3 * kerplanecount].x * X[24].x) + (Kodiag[ker_baseidx + 3 * kerplanecount].x * X[24].y) + (Kodiag[ker_baseidx + 3 * kerplanecount].y * X[24].z);
			F[24].y = (Kodiag[ker_baseidx + 3 * kerplanecount].x * X[24].x) + (Kdiag[ker_baseidx + 3 * kerplanecount].y * X[24].y) + (Kodiag[ker_baseidx + 3 * kerplanecount].z * X[24].z);
			F[24].z = (Kodiag[ker_baseidx + 3 * kerplanecount].y * X[24].x) + (Kodiag[ker_baseidx + 3 * kerplanecount].z * X[24].y) + (Kdiag[ker_baseidx + 3 * kerplanecount].z * X[24].z);

			F[4].x = (Kdiag[ker_baseidx + 4 * kerplanecount].x * X[4].x) + (Kodiag[ker_baseidx + 4 * kerplanecount].x * X[4].y) + (Kodiag[ker_baseidx + 4 * kerplanecount].y * X[4].z);
			F[4].y = (Kodiag[ker_baseidx + 4 * kerplanecount].x * X[4].x) + (Kdiag[ker_baseidx + 4 * kerplanecount].y * X[4].y) + (Kodiag[ker_baseidx + 4 * kerplanecount].z * X[4].z);
			F[4].z = (Kodiag[ker_baseidx + 4 * kerplanecount].y * X[4].x) + (Kodiag[ker_baseidx + 4 * kerplanecount].z * X[4].y) + (Kdiag[ker_baseidx + 4 * kerplanecount].z * X[4].z);

			F[20].x = (Kdiag[ker_baseidx + 5 * kerplanecount].x * X[20].x) + (Kodiag[ker_baseidx + 5 * kerplanecount].x * X[20].y) + (Kodiag[ker_baseidx + 5 * kerplanecount].y * X[20].z);
			F[20].y = (Kodiag[ker_baseidx + 5 * kerplanecount].x * X[20].x) + (Kdiag[ker_baseidx + 5 * kerplanecount].y * X[20].y) + (Kodiag[ker_baseidx + 5 * kerplanecount].z * X[20].z);
			F[20].z = (Kodiag[ker_baseidx + 5 * kerplanecount].y * X[20].x) + (Kodiag[ker_baseidx + 5 * kerplanecount].z * X[20].y) + (Kdiag[ker_baseidx + 5 * kerplanecount].z * X[20].z);

			F[12].x = (Kdiag[ker_baseidx + 6 * kerplanecount].x * X[12].x) + (Kodiag[ker_baseidx + 6 * kerplanecount].x * X[12].y) + (Kodiag[ker_baseidx + 6 * kerplanecount].y * X[12].z);
			F[12].y = (Kodiag[ker_baseidx + 6 * kerplanecount].x * X[12].x) + (Kdiag[ker_baseidx + 6 * kerplanecount].y * X[12].y) + (Kodiag[ker_baseidx + 6 * kerplanecount].z * X[12].z);
			F[12].z = (Kodiag[ker_baseidx + 6 * kerplanecount].y * X[12].x) + (Kodiag[ker_baseidx + 6 * kerplanecount].z * X[12].y) + (Kdiag[ker_baseidx + 6 * kerplanecount].z * X[12].z);

			F[28].x = (Kdiag[ker_baseidx + 7 * kerplanecount].x * X[28].x) + (Kodiag[ker_baseidx + 7 * kerplanecount].x * X[28].y) + (Kodiag[ker_baseidx + 7 * kerplanecount].y * X[28].z);
			F[28].y = (Kodiag[ker_baseidx + 7 * kerplanecount].x * X[28].x) + (Kdiag[ker_baseidx + 7 * kerplanecount].y * X[28].y) + (Kodiag[ker_baseidx + 7 * kerplanecount].z * X[28].z);
			F[28].z = (Kodiag[ker_baseidx + 7 * kerplanecount].y * X[28].x) + (Kodiag[ker_baseidx + 7 * kerplanecount].z * X[28].y) + (Kdiag[ker_baseidx + 7 * kerplanecount].z * X[28].z);

			F[2].x = (Kdiag[ker_baseidx + 8 * kerplanecount].x * X[2].x) + (Kodiag[ker_baseidx + 8 * kerplanecount].x * X[2].y) + (Kodiag[ker_baseidx + 8 * kerplanecount].y * X[2].z);
			F[2].y = (Kodiag[ker_baseidx + 8 * kerplanecount].x * X[2].x) + (Kdiag[ker_baseidx + 8 * kerplanecount].y * X[2].y) + (Kodiag[ker_baseidx + 8 * kerplanecount].z * X[2].z);
			F[2].z = (Kodiag[ker_baseidx + 8 * kerplanecount].y * X[2].x) + (Kodiag[ker_baseidx + 8 * kerplanecount].z * X[2].y) + (Kdiag[ker_baseidx + 8 * kerplanecount].z * X[2].z);

			F[18].x = (Kdiag[ker_baseidx + 9 * kerplanecount].x * X[18].x) + (Kodiag[ker_baseidx + 9 * kerplanecount].x * X[18].y) + (Kodiag[ker_baseidx + 9 * kerplanecount].y * X[18].z);
			F[18].y = (Kodiag[ker_baseidx + 9 * kerplanecount].x * X[18].x) + (Kdiag[ker_baseidx + 9 * kerplanecount].y * X[18].y) + (Kodiag[ker_baseidx + 9 * kerplanecount].z * X[18].z);
			F[18].z = (Kodiag[ker_baseidx + 9 * kerplanecount].y * X[18].x) + (Kodiag[ker_baseidx + 9 * kerplanecount].z * X[18].y) + (Kdiag[ker_baseidx + 9 * kerplanecount].z * X[18].z);

			F[10].x = (Kdiag[ker_baseidx + 10 * kerplanecount].x * X[10].x) + (Kodiag[ker_baseidx + 10 * kerplanecount].x * X[10].y) + (Kodiag[ker_baseidx + 10 * kerplanecount].y * X[10].z);
			F[10].y = (Kodiag[ker_baseidx + 10 * kerplanecount].x * X[10].x) + (Kdiag[ker_baseidx + 10 * kerplanecount].y * X[10].y) + (Kodiag[ker_baseidx + 10 * kerplanecount].z * X[10].z);
			F[10].z = (Kodiag[ker_baseidx + 10 * kerplanecount].y * X[10].x) + (Kodiag[ker_baseidx + 10 * kerplanecount].z * X[10].y) + (Kdiag[ker_baseidx + 10 * kerplanecount].z * X[10].z);
			
			F[26].x = (Kdiag[ker_baseidx + 11 * kerplanecount].x * X[26].x) + (Kodiag[ker_baseidx + 11 * kerplanecount].x * X[26].y) + (Kodiag[ker_baseidx + 11 * kerplanecount].y * X[26].z);
			F[26].y = (Kodiag[ker_baseidx + 11 * kerplanecount].x * X[26].x) + (Kdiag[ker_baseidx + 11 * kerplanecount].y * X[26].y) + (Kodiag[ker_baseidx + 11 * kerplanecount].z * X[26].z);
			F[26].z = (Kodiag[ker_baseidx + 11 * kerplanecount].y * X[26].x) + (Kodiag[ker_baseidx + 11 * kerplanecount].z * X[26].y) + (Kdiag[ker_baseidx + 11 * kerplanecount].z * X[26].z);

			F[6].x = (Kdiag[ker_baseidx + 12 * kerplanecount].x * X[6].x) + (Kodiag[ker_baseidx + 12 * kerplanecount].x * X[6].y) + (Kodiag[ker_baseidx + 12 * kerplanecount].y * X[6].z);
			F[6].y = (Kodiag[ker_baseidx + 12 * kerplanecount].x * X[6].x) + (Kdiag[ker_baseidx + 12 * kerplanecount].y * X[6].y) + (Kodiag[ker_baseidx + 12 * kerplanecount].z * X[6].z);
			F[6].z = (Kodiag[ker_baseidx + 12 * kerplanecount].y * X[6].x) + (Kodiag[ker_baseidx + 12 * kerplanecount].z * X[6].y) + (Kdiag[ker_baseidx + 12 * kerplanecount].z * X[6].z);

			F[22].x = (Kdiag[ker_baseidx + 13 * kerplanecount].x * X[22].x) + (Kodiag[ker_baseidx + 13 * kerplanecount].x * X[22].y) + (Kodiag[ker_baseidx + 13 * kerplanecount].y * X[22].z);
			F[22].y = (Kodiag[ker_baseidx + 13 * kerplanecount].x * X[22].x) + (Kdiag[ker_baseidx + 13 * kerplanecount].y * X[22].y) + (Kodiag[ker_baseidx + 13 * kerplanecount].z * X[22].z);
			F[22].z = (Kodiag[ker_baseidx + 13 * kerplanecount].y * X[22].x) + (Kodiag[ker_baseidx + 13 * kerplanecount].z * X[22].y) + (Kdiag[ker_baseidx + 13 * kerplanecount].z * X[22].z);

			F[14].x = (Kdiag[ker_baseidx + 14 * kerplanecount].x * X[14].x) + (Kodiag[ker_baseidx + 14 * kerplanecount].x * X[14].y) + (Kodiag[ker_baseidx + 14 * kerplanecount].y * X[14].z);
			F[14].y = (Kodiag[ker_baseidx + 14 * kerplanecount].x * X[14].x) + (Kdiag[ker_baseidx + 14 * kerplanecount].y * X[14].y) + (Kodiag[ker_baseidx + 14 * kerplanecount].z * X[14].z);
			F[14].z = (Kodiag[ker_baseidx + 14 * kerplanecount].y * X[14].x) + (Kodiag[ker_baseidx + 14 * kerplanecount].z * X[14].y) + (Kdiag[ker_baseidx + 14 * kerplanecount].z * X[14].z);

			F[30].x = (Kdiag[ker_baseidx + 15 * kerplanecount].x * X[30].x) + (Kodiag[ker_baseidx + 15 * kerplanecount].x * X[30].y) + (Kodiag[ker_baseidx + 15 * kerplanecount].y * X[30].z);
			F[30].y = (Kodiag[ker_baseidx + 15 * kerplanecount].x * X[30].x) + (Kdiag[ker_baseidx + 15 * kerplanecount].y * X[30].y) + (Kodiag[ker_baseidx + 15 * kerplanecount].z * X[30].z);
			F[30].z = (Kodiag[ker_baseidx + 15 * kerplanecount].y * X[30].x) + (Kodiag[ker_baseidx + 15 * kerplanecount].z * X[30].y) + (Kdiag[ker_baseidx + 15 * kerplanecount].z * X[30].z);

			F[1].x = (Kdiag[ker_baseidx + 16 * kerplanecount].x * X[1].x) + (Kodiag[ker_baseidx + 16 * kerplanecount].x * X[1].y) + (Kodiag[ker_baseidx + 16 * kerplanecount].y * X[1].z);
			F[1].y = (Kodiag[ker_baseidx + 16 * kerplanecount].x * X[1].x) + (Kdiag[ker_baseidx + 16 * kerplanecount].y * X[1].y) + (Kodiag[ker_baseidx + 16 * kerplanecount].z * X[1].z);
			F[1].z = (Kodiag[ker_baseidx + 16 * kerplanecount].y * X[1].x) + (Kodiag[ker_baseidx + 16 * kerplanecount].z * X[1].y) + (Kdiag[ker_baseidx + 16 * kerplanecount].z * X[1].z);

			F[17].x = (Kdiag[ker_baseidx + 15 * kerplanecount].x * X[17].x) + (Kodiag[ker_baseidx + 15 * kerplanecount].x * X[17].y) + (-Kodiag[ker_baseidx + 15 * kerplanecount].y * X[17].z);
			F[17].y = (Kodiag[ker_baseidx + 15 * kerplanecount].x * X[17].x) + (Kdiag[ker_baseidx + 15 * kerplanecount].y * X[17].y) + (-Kodiag[ker_baseidx + 15 * kerplanecount].z * X[17].z);
			F[17].z = (-Kodiag[ker_baseidx + 15 * kerplanecount].y * X[17].x) + (-Kodiag[ker_baseidx + 15 * kerplanecount].z * X[17].y) + (Kdiag[ker_baseidx + 15 * kerplanecount].z * X[17].z);
			
			F[9].x = (Kdiag[ker_baseidx + 14 * kerplanecount].x * X[9].x) + (Kodiag[ker_baseidx + 14 * kerplanecount].x * X[9].y) + (-Kodiag[ker_baseidx + 14 * kerplanecount].y * X[9].z);
			F[9].y = (Kodiag[ker_baseidx + 14 * kerplanecount].x * X[9].x) + (Kdiag[ker_baseidx + 14 * kerplanecount].y * X[9].y) + (-Kodiag[ker_baseidx + 14 * kerplanecount].z * X[9].z);
			F[9].z = (-Kodiag[ker_baseidx + 14 * kerplanecount].y * X[9].x) + (-Kodiag[ker_baseidx + 14 * kerplanecount].z * X[9].y) + (Kdiag[ker_baseidx + 14 * kerplanecount].z * X[9].z);
			
			F[25].x = (Kdiag[ker_baseidx + 13 * kerplanecount].x * X[25].x) + (Kodiag[ker_baseidx + 13 * kerplanecount].x * X[25].y) + (-Kodiag[ker_baseidx + 13 * kerplanecount].y * X[25].z);
			F[25].y = (Kodiag[ker_baseidx + 13 * kerplanecount].x * X[25].x) + (Kdiag[ker_baseidx + 13 * kerplanecount].y * X[25].y) + (-Kodiag[ker_baseidx + 13 * kerplanecount].z * X[25].z);
			F[25].z = (-Kodiag[ker_baseidx + 13 * kerplanecount].y * X[25].x) + (-Kodiag[ker_baseidx + 13 * kerplanecount].z * X[25].y) + (Kdiag[ker_baseidx + 13 * kerplanecount].z * X[25].z);

			F[5].x = (Kdiag[ker_baseidx + 12 * kerplanecount].x * X[5].x) + (Kodiag[ker_baseidx + 12 * kerplanecount].x * X[5].y) + (-Kodiag[ker_baseidx + 12 * kerplanecount].y * X[5].z);
			F[5].y = (Kodiag[ker_baseidx + 12 * kerplanecount].x * X[5].x) + (Kdiag[ker_baseidx + 12 * kerplanecount].y * X[5].y) + (-Kodiag[ker_baseidx + 12 * kerplanecount].z * X[5].z);
			F[5].z = (-Kodiag[ker_baseidx + 12 * kerplanecount].y * X[5].x) + (-Kodiag[ker_baseidx + 12 * kerplanecount].z * X[5].y) + (Kdiag[ker_baseidx + 12 * kerplanecount].z * X[5].z);

			F[21].x = (Kdiag[ker_baseidx + 11 * kerplanecount].x * X[21].x) + (Kodiag[ker_baseidx + 11 * kerplanecount].x * X[21].y) + (-Kodiag[ker_baseidx + 11 * kerplanecount].y * X[21].z);
			F[21].y = (Kodiag[ker_baseidx + 11 * kerplanecount].x * X[21].x) + (Kdiag[ker_baseidx + 11 * kerplanecount].y * X[21].y) + (-Kodiag[ker_baseidx + 11 * kerplanecount].z * X[21].z);
			F[21].z = (-Kodiag[ker_baseidx + 11 * kerplanecount].y * X[21].x) + (-Kodiag[ker_baseidx + 11 * kerplanecount].z * X[21].y) + (Kdiag[ker_baseidx + 11 * kerplanecount].z * X[21].z);

			F[13].x = (Kdiag[ker_baseidx + 10 * kerplanecount].x * X[13].x) + (Kodiag[ker_baseidx + 10 * kerplanecount].x * X[13].y) + (-Kodiag[ker_baseidx + 10 * kerplanecount].y * X[13].z);
			F[13].y = (Kodiag[ker_baseidx + 10 * kerplanecount].x * X[13].x) + (Kdiag[ker_baseidx + 10 * kerplanecount].y * X[13].y) + (-Kodiag[ker_baseidx + 10 * kerplanecount].z * X[13].z);
			F[13].z = (-Kodiag[ker_baseidx + 10 * kerplanecount].y * X[13].x) + (-Kodiag[ker_baseidx + 10 * kerplanecount].z * X[13].y) + (Kdiag[ker_baseidx + 10 * kerplanecount].z * X[13].z);

			F[29].x = (Kdiag[ker_baseidx + 9 * kerplanecount].x * X[29].x) + (Kodiag[ker_baseidx + 9 * kerplanecount].x * X[29].y) + (-Kodiag[ker_baseidx + 9 * kerplanecount].y * X[29].z);
			F[29].y = (Kodiag[ker_baseidx + 9 * kerplanecount].x * X[29].x) + (Kdiag[ker_baseidx + 9 * kerplanecount].y * X[29].y) + (-Kodiag[ker_baseidx + 9 * kerplanecount].z * X[29].z);
			F[29].z = (-Kodiag[ker_baseidx + 9 * kerplanecount].y * X[29].x) + (-Kodiag[ker_baseidx + 9 * kerplanecount].z * X[29].y) + (Kdiag[ker_baseidx + 9 * kerplanecount].z * X[29].z);

			F[3].x = (Kdiag[ker_baseidx + 8 * kerplanecount].x * X[3].x) + (Kodiag[ker_baseidx + 8 * kerplanecount].x * X[3].y) + (-Kodiag[ker_baseidx + 8 * kerplanecount].y * X[3].z);
			F[3].y = (Kodiag[ker_baseidx + 8 * kerplanecount].x * X[3].x) + (Kdiag[ker_baseidx + 8 * kerplanecount].y * X[3].y) + (-Kodiag[ker_baseidx + 8 * kerplanecount].z * X[3].z);
			F[3].z = (-Kodiag[ker_baseidx + 8 * kerplanecount].y * X[3].x) + (-Kodiag[ker_baseidx + 8 * kerplanecount].z * X[3].y) + (Kdiag[ker_baseidx + 8 * kerplanecount].z * X[3].z);

			F[19].x = (Kdiag[ker_baseidx + 7 * kerplanecount].x * X[19].x) + (Kodiag[ker_baseidx + 7 * kerplanecount].x * X[19].y) + (-Kodiag[ker_baseidx + 7 * kerplanecount].y * X[19].z);
			F[19].y = (Kodiag[ker_baseidx + 7 * kerplanecount].x * X[19].x) + (Kdiag[ker_baseidx + 7 * kerplanecount].y * X[19].y) + (-Kodiag[ker_baseidx + 7 * kerplanecount].z * X[19].z);
			F[19].z = (-Kodiag[ker_baseidx + 7 * kerplanecount].y * X[19].x) + (-Kodiag[ker_baseidx + 7 * kerplanecount].z * X[19].y) + (Kdiag[ker_baseidx + 7 * kerplanecount].z * X[19].z);

			F[11].x = (Kdiag[ker_baseidx + 6 * kerplanecount].x * X[11].x) + (Kodiag[ker_baseidx + 6 * kerplanecount].x * X[11].y) + (-Kodiag[ker_baseidx + 6 * kerplanecount].y * X[11].z);
			F[11].y = (Kodiag[ker_baseidx + 6 * kerplanecount].x * X[11].x) + (Kdiag[ker_baseidx + 6 * kerplanecount].y * X[11].y) + (-Kodiag[ker_baseidx + 6 * kerplanecount].z * X[11].z);
			F[11].z = (-Kodiag[ker_baseidx + 6 * kerplanecount].y * X[11].x) + (-Kodiag[ker_baseidx + 6 * kerplanecount].z * X[11].y) + (Kdiag[ker_baseidx + 6 * kerplanecount].z * X[11].z);

			F[27].x = (Kdiag[ker_baseidx + 5 * kerplanecount].x * X[27].x) + (Kodiag[ker_baseidx + 5 * kerplanecount].x * X[27].y) + (-Kodiag[ker_baseidx + 5 * kerplanecount].y * X[27].z);
			F[27].y = (Kodiag[ker_baseidx + 5 * kerplanecount].x * X[27].x) + (Kdiag[ker_baseidx + 5 * kerplanecount].y * X[27].y) + (-Kodiag[ker_baseidx + 5 * kerplanecount].z * X[27].z);
			F[27].z = (-Kodiag[ker_baseidx + 5 * kerplanecount].y * X[27].x) + (-Kodiag[ker_baseidx + 5 * kerplanecount].z * X[27].y) + (Kdiag[ker_baseidx + 5 * kerplanecount].z * X[27].z);

			F[7].x = (Kdiag[ker_baseidx + 4 * kerplanecount].x * X[7].x) + (Kodiag[ker_baseidx + 4 * kerplanecount].x * X[7].y) + (-Kodiag[ker_baseidx + 4 * kerplanecount].y * X[7].z);
			F[7].y = (Kodiag[ker_baseidx + 4 * kerplanecount].x * X[7].x) + (Kdiag[ker_baseidx + 4 * kerplanecount].y * X[7].y) + (-Kodiag[ker_baseidx + 4 * kerplanecount].z * X[7].z);
			F[7].z = (-Kodiag[ker_baseidx + 4 * kerplanecount].y * X[7].x) + (-Kodiag[ker_baseidx + 4 * kerplanecount].z * X[7].y) + (Kdiag[ker_baseidx + 4 * kerplanecount].z * X[7].z);

			F[23].x = (Kdiag[ker_baseidx + 3 * kerplanecount].x * X[23].x) + (Kodiag[ker_baseidx + 3 * kerplanecount].x * X[23].y) + (-Kodiag[ker_baseidx + 3 * kerplanecount].y * X[23].z);
			F[23].y = (Kodiag[ker_baseidx + 3 * kerplanecount].x * X[23].x) + (Kdiag[ker_baseidx + 3 * kerplanecount].y * X[23].y) + (-Kodiag[ker_baseidx + 3 * kerplanecount].z * X[23].z);
			F[23].z = (-Kodiag[ker_baseidx + 3 * kerplanecount].y * X[23].x) + (-Kodiag[ker_baseidx + 3 * kerplanecount].z * X[23].y) + (Kdiag[ker_baseidx + 3 * kerplanecount].z * X[23].z);

			F[15].x = (Kdiag[ker_baseidx + 2 * kerplanecount].x * X[15].x) + (Kodiag[ker_baseidx + 2 * kerplanecount].x * X[15].y) + (-Kodiag[ker_baseidx + 2 * kerplanecount].y * X[15].z);
			F[15].y = (Kodiag[ker_baseidx + 2 * kerplanecount].x * X[15].x) + (Kdiag[ker_baseidx + 2 * kerplanecount].y * X[15].y) + (-Kodiag[ker_baseidx + 2 * kerplanecount].z * X[15].z);
			F[15].z = (-Kodiag[ker_baseidx + 2 * kerplanecount].y * X[15].x) + (-Kodiag[ker_baseidx + 2 * kerplanecount].z * X[15].y) + (Kdiag[ker_baseidx + 2 * kerplanecount].z * X[15].z);

			F[31].x = (Kdiag[ker_baseidx + 1 * kerplanecount].x * X[31].x) + (Kodiag[ker_baseidx + 1 * kerplanecount].x * X[31].y) + (-Kodiag[ker_baseidx + 1 * kerplanecount].y * X[31].z);
			F[31].y = (Kodiag[ker_baseidx + 1 * kerplanecount].x * X[31].x) + (Kdiag[ker_baseidx + 1 * kerplanecount].y * X[31].y) + (-Kodiag[ker_baseidx + 1 * kerplanecount].z * X[31].z);
			F[31].z = (-Kodiag[ker_baseidx + 1 * kerplanecount].y * X[31].x) + (-Kodiag[ker_baseidx + 1 * kerplanecount].z * X[31].y) + (Kdiag[ker_baseidx + 1 * kerplanecount].z * X[31].z);
		}
		else {

			int ker_baseidx = (N.y - i) + j * (N.y / 2 + 1);

			F[0].x = (Kdiag[ker_baseidx].x * X[0].x) + (-Kodiag[ker_baseidx].x * X[0].y) + (Kodiag[ker_baseidx].y * X[0].z);
			F[0].y = (-Kodiag[ker_baseidx].x * X[0].x) + (Kdiag[ker_baseidx].y * X[0].y) + (-Kodiag[ker_baseidx].z * X[0].z);
			F[0].z = (Kodiag[ker_baseidx].y * X[0].x) + (-Kodiag[ker_baseidx].z * X[0].y) + (Kdiag[ker_baseidx].z * X[0].z);

			F[16].x = (Kdiag[ker_baseidx + 1 * kerplanecount].x * X[16].x) + (-Kodiag[ker_baseidx + 1 * kerplanecount].x * X[16].y) + (Kodiag[ker_baseidx + 1 * kerplanecount].y * X[16].z);
			F[16].y = (-Kodiag[ker_baseidx + 1 * kerplanecount].x * X[16].x) + (Kdiag[ker_baseidx + 1 * kerplanecount].y * X[16].y) + (-Kodiag[ker_baseidx + 1 * kerplanecount].z * X[16].z);
			F[16].z = (Kodiag[ker_baseidx + 1 * kerplanecount].y * X[16].x) + (-Kodiag[ker_baseidx + 1 * kerplanecount].z * X[16].y) + (Kdiag[ker_baseidx + 1 * kerplanecount].z * X[16].z);

			F[8].x = (Kdiag[ker_baseidx + 2 * kerplanecount].x * X[8].x) + (-Kodiag[ker_baseidx + 2 * kerplanecount].x * X[8].y) + (Kodiag[ker_baseidx + 2 * kerplanecount].y * X[8].z);
			F[8].y = (-Kodiag[ker_baseidx + 2 * kerplanecount].x * X[8].x) + (Kdiag[ker_baseidx + 2 * kerplanecount].y * X[8].y) + (-Kodiag[ker_baseidx + 2 * kerplanecount].z * X[8].z);
			F[8].z = (Kodiag[ker_baseidx + 2 * kerplanecount].y * X[8].x) + (-Kodiag[ker_baseidx + 2 * kerplanecount].z * X[8].y) + (Kdiag[ker_baseidx + 2 * kerplanecount].z * X[8].z);

			F[24].x = (Kdiag[ker_baseidx + 3 * kerplanecount].x * X[24].x) + (-Kodiag[ker_baseidx + 3 * kerplanecount].x * X[24].y) + (Kodiag[ker_baseidx + 3 * kerplanecount].y * X[24].z);
			F[24].y = (-Kodiag[ker_baseidx + 3 * kerplanecount].x * X[24].x) + (Kdiag[ker_baseidx + 3 * kerplanecount].y * X[24].y) + (-Kodiag[ker_baseidx + 3 * kerplanecount].z * X[24].z);
			F[24].z = (Kodiag[ker_baseidx + 3 * kerplanecount].y * X[24].x) + (-Kodiag[ker_baseidx + 3 * kerplanecount].z * X[24].y) + (Kdiag[ker_baseidx + 3 * kerplanecount].z * X[24].z);

			F[4].x = (Kdiag[ker_baseidx + 4 * kerplanecount].x * X[4].x) + (-Kodiag[ker_baseidx + 4 * kerplanecount].x * X[4].y) + (Kodiag[ker_baseidx + 4 * kerplanecount].y * X[4].z);
			F[4].y = (-Kodiag[ker_baseidx + 4 * kerplanecount].x * X[4].x) + (Kdiag[ker_baseidx + 4 * kerplanecount].y * X[4].y) + (-Kodiag[ker_baseidx + 4 * kerplanecount].z * X[4].z);
			F[4].z = (Kodiag[ker_baseidx + 4 * kerplanecount].y * X[4].x) + (-Kodiag[ker_baseidx + 4 * kerplanecount].z * X[4].y) + (Kdiag[ker_baseidx + 4 * kerplanecount].z * X[4].z);

			F[20].x = (Kdiag[ker_baseidx + 5 * kerplanecount].x * X[20].x) + (-Kodiag[ker_baseidx + 5 * kerplanecount].x * X[20].y) + (Kodiag[ker_baseidx + 5 * kerplanecount].y * X[20].z);
			F[20].y = (-Kodiag[ker_baseidx + 5 * kerplanecount].x * X[20].x) + (Kdiag[ker_baseidx + 5 * kerplanecount].y * X[20].y) + (-Kodiag[ker_baseidx + 5 * kerplanecount].z * X[20].z);
			F[20].z = (Kodiag[ker_baseidx + 5 * kerplanecount].y * X[20].x) + (-Kodiag[ker_baseidx + 5 * kerplanecount].z * X[20].y) + (Kdiag[ker_baseidx + 5 * kerplanecount].z * X[20].z);

			F[12].x = (Kdiag[ker_baseidx + 6 * kerplanecount].x * X[12].x) + (-Kodiag[ker_baseidx + 6 * kerplanecount].x * X[12].y) + (Kodiag[ker_baseidx + 6 * kerplanecount].y * X[12].z);
			F[12].y = (-Kodiag[ker_baseidx + 6 * kerplanecount].x * X[12].x) + (Kdiag[ker_baseidx + 6 * kerplanecount].y * X[12].y) + (-Kodiag[ker_baseidx + 6 * kerplanecount].z * X[12].z);
			F[12].z = (Kodiag[ker_baseidx + 6 * kerplanecount].y * X[12].x) + (-Kodiag[ker_baseidx + 6 * kerplanecount].z * X[12].y) + (Kdiag[ker_baseidx + 6 * kerplanecount].z * X[12].z);

			F[28].x = (Kdiag[ker_baseidx + 7 * kerplanecount].x * X[28].x) + (-Kodiag[ker_baseidx + 7 * kerplanecount].x * X[28].y) + (Kodiag[ker_baseidx + 7 * kerplanecount].y * X[28].z);
			F[28].y = (-Kodiag[ker_baseidx + 7 * kerplanecount].x * X[28].x) + (Kdiag[ker_baseidx + 7 * kerplanecount].y * X[28].y) + (-Kodiag[ker_baseidx + 7 * kerplanecount].z * X[28].z);
			F[28].z = (Kodiag[ker_baseidx + 7 * kerplanecount].y * X[28].x) + (-Kodiag[ker_baseidx + 7 * kerplanecount].z * X[28].y) + (Kdiag[ker_baseidx + 7 * kerplanecount].z * X[28].z);

			F[2].x = (Kdiag[ker_baseidx + 8 * kerplanecount].x * X[2].x) + (-Kodiag[ker_baseidx + 8 * kerplanecount].x * X[2].y) + (Kodiag[ker_baseidx + 8 * kerplanecount].y * X[2].z);
			F[2].y = (-Kodiag[ker_baseidx + 8 * kerplanecount].x * X[2].x) + (Kdiag[ker_baseidx + 8 * kerplanecount].y * X[2].y) + (-Kodiag[ker_baseidx + 8 * kerplanecount].z * X[2].z);
			F[2].z = (Kodiag[ker_baseidx + 8 * kerplanecount].y * X[2].x) + (-Kodiag[ker_baseidx + 8 * kerplanecount].z * X[2].y) + (Kdiag[ker_baseidx + 8 * kerplanecount].z * X[2].z);

			F[18].x = (Kdiag[ker_baseidx + 9 * kerplanecount].x * X[18].x) + (-Kodiag[ker_baseidx + 9 * kerplanecount].x * X[18].y) + (Kodiag[ker_baseidx + 9 * kerplanecount].y * X[18].z);
			F[18].y = (-Kodiag[ker_baseidx + 9 * kerplanecount].x * X[18].x) + (Kdiag[ker_baseidx + 9 * kerplanecount].y * X[18].y) + (-Kodiag[ker_baseidx + 9 * kerplanecount].z * X[18].z);
			F[18].z = (Kodiag[ker_baseidx + 9 * kerplanecount].y * X[18].x) + (-Kodiag[ker_baseidx + 9 * kerplanecount].z * X[18].y) + (Kdiag[ker_baseidx + 9 * kerplanecount].z * X[18].z);

			F[10].x = (Kdiag[ker_baseidx + 10 * kerplanecount].x * X[10].x) + (-Kodiag[ker_baseidx + 10 * kerplanecount].x * X[10].y) + (Kodiag[ker_baseidx + 10 * kerplanecount].y * X[10].z);
			F[10].y = (-Kodiag[ker_baseidx + 10 * kerplanecount].x * X[10].x) + (Kdiag[ker_baseidx + 10 * kerplanecount].y * X[10].y) + (-Kodiag[ker_baseidx + 10 * kerplanecount].z * X[10].z);
			F[10].z = (Kodiag[ker_baseidx + 10 * kerplanecount].y * X[10].x) + (-Kodiag[ker_baseidx + 10 * kerplanecount].z * X[10].y) + (Kdiag[ker_baseidx + 10 * kerplanecount].z * X[10].z);

			F[26].x = (Kdiag[ker_baseidx + 11 * kerplanecount].x * X[26].x) + (-Kodiag[ker_baseidx + 11 * kerplanecount].x * X[26].y) + (Kodiag[ker_baseidx + 11 * kerplanecount].y * X[26].z);
			F[26].y = (-Kodiag[ker_baseidx + 11 * kerplanecount].x * X[26].x) + (Kdiag[ker_baseidx + 11 * kerplanecount].y * X[26].y) + (-Kodiag[ker_baseidx + 11 * kerplanecount].z * X[26].z);
			F[26].z = (Kodiag[ker_baseidx + 11 * kerplanecount].y * X[26].x) + (-Kodiag[ker_baseidx + 11 * kerplanecount].z * X[26].y) + (Kdiag[ker_baseidx + 11 * kerplanecount].z * X[26].z);

			F[6].x = (Kdiag[ker_baseidx + 12 * kerplanecount].x * X[6].x) + (-Kodiag[ker_baseidx + 12 * kerplanecount].x * X[6].y) + (Kodiag[ker_baseidx + 12 * kerplanecount].y * X[6].z);
			F[6].y = (-Kodiag[ker_baseidx + 12 * kerplanecount].x * X[6].x) + (Kdiag[ker_baseidx + 12 * kerplanecount].y * X[6].y) + (-Kodiag[ker_baseidx + 12 * kerplanecount].z * X[6].z);
			F[6].z = (Kodiag[ker_baseidx + 12 * kerplanecount].y * X[6].x) + (-Kodiag[ker_baseidx + 12 * kerplanecount].z * X[6].y) + (Kdiag[ker_baseidx + 12 * kerplanecount].z * X[6].z);

			F[22].x = (Kdiag[ker_baseidx + 13 * kerplanecount].x * X[22].x) + (-Kodiag[ker_baseidx + 13 * kerplanecount].x * X[22].y) + (Kodiag[ker_baseidx + 13 * kerplanecount].y * X[22].z);
			F[22].y = (-Kodiag[ker_baseidx + 13 * kerplanecount].x * X[22].x) + (Kdiag[ker_baseidx + 13 * kerplanecount].y * X[22].y) + (-Kodiag[ker_baseidx + 13 * kerplanecount].z * X[22].z);
			F[22].z = (Kodiag[ker_baseidx + 13 * kerplanecount].y * X[22].x) + (-Kodiag[ker_baseidx + 13 * kerplanecount].z * X[22].y) + (Kdiag[ker_baseidx + 13 * kerplanecount].z * X[22].z);

			F[14].x = (Kdiag[ker_baseidx + 14 * kerplanecount].x * X[14].x) + (-Kodiag[ker_baseidx + 14 * kerplanecount].x * X[14].y) + (Kodiag[ker_baseidx + 14 * kerplanecount].y * X[14].z);
			F[14].y = (-Kodiag[ker_baseidx + 14 * kerplanecount].x * X[14].x) + (Kdiag[ker_baseidx + 14 * kerplanecount].y * X[14].y) + (-Kodiag[ker_baseidx + 14 * kerplanecount].z * X[14].z);
			F[14].z = (Kodiag[ker_baseidx + 14 * kerplanecount].y * X[14].x) + (-Kodiag[ker_baseidx + 14 * kerplanecount].z * X[14].y) + (Kdiag[ker_baseidx + 14 * kerplanecount].z * X[14].z);

			F[30].x = (Kdiag[ker_baseidx + 15 * kerplanecount].x * X[30].x) + (-Kodiag[ker_baseidx + 15 * kerplanecount].x * X[30].y) + (Kodiag[ker_baseidx + 15 * kerplanecount].y * X[30].z);
			F[30].y = (-Kodiag[ker_baseidx + 15 * kerplanecount].x * X[30].x) + (Kdiag[ker_baseidx + 15 * kerplanecount].y * X[30].y) + (-Kodiag[ker_baseidx + 15 * kerplanecount].z * X[30].z);
			F[30].z = (Kodiag[ker_baseidx + 15 * kerplanecount].y * X[30].x) + (-Kodiag[ker_baseidx + 15 * kerplanecount].z * X[30].y) + (Kdiag[ker_baseidx + 15 * kerplanecount].z * X[30].z);

			F[1].x = (Kdiag[ker_baseidx + 16 * kerplanecount].x * X[1].x) + (-Kodiag[ker_baseidx + 16 * kerplanecount].x * X[1].y) + (Kodiag[ker_baseidx + 16 * kerplanecount].y * X[1].z);
			F[1].y = (-Kodiag[ker_baseidx + 16 * kerplanecount].x * X[1].x) + (Kdiag[ker_baseidx + 16 * kerplanecount].y * X[1].y) + (-Kodiag[ker_baseidx + 16 * kerplanecount].z * X[1].z);
			F[1].z = (Kodiag[ker_baseidx + 16 * kerplanecount].y * X[1].x) + (-Kodiag[ker_baseidx + 16 * kerplanecount].z * X[1].y) + (Kdiag[ker_baseidx + 16 * kerplanecount].z * X[1].z);

			F[17].x = (Kdiag[ker_baseidx + 15 * kerplanecount].x * X[17].x) + (-Kodiag[ker_baseidx + 15 * kerplanecount].x * X[17].y) + (-Kodiag[ker_baseidx + 15 * kerplanecount].y * X[17].z);
			F[17].y = (-Kodiag[ker_baseidx + 15 * kerplanecount].x * X[17].x) + (Kdiag[ker_baseidx + 15 * kerplanecount].y * X[17].y) + (Kodiag[ker_baseidx + 15 * kerplanecount].z * X[17].z);
			F[17].z = (-Kodiag[ker_baseidx + 15 * kerplanecount].y * X[17].x) + (Kodiag[ker_baseidx + 15 * kerplanecount].z * X[17].y) + (Kdiag[ker_baseidx + 15 * kerplanecount].z * X[17].z);

			F[9].x = (Kdiag[ker_baseidx + 14 * kerplanecount].x * X[9].x) + (-Kodiag[ker_baseidx + 14 * kerplanecount].x * X[9].y) + (-Kodiag[ker_baseidx + 14 * kerplanecount].y * X[9].z);
			F[9].y = (-Kodiag[ker_baseidx + 14 * kerplanecount].x * X[9].x) + (Kdiag[ker_baseidx + 14 * kerplanecount].y * X[9].y) + (Kodiag[ker_baseidx + 14 * kerplanecount].z * X[9].z);
			F[9].z = (-Kodiag[ker_baseidx + 14 * kerplanecount].y * X[9].x) + (Kodiag[ker_baseidx + 14 * kerplanecount].z * X[9].y) + (Kdiag[ker_baseidx + 14 * kerplanecount].z * X[9].z);

			F[25].x = (Kdiag[ker_baseidx + 13 * kerplanecount].x * X[25].x) + (-Kodiag[ker_baseidx + 13 * kerplanecount].x * X[25].y) + (-Kodiag[ker_baseidx + 13 * kerplanecount].y * X[25].z);
			F[25].y = (-Kodiag[ker_baseidx + 13 * kerplanecount].x * X[25].x) + (Kdiag[ker_baseidx + 13 * kerplanecount].y * X[25].y) + (Kodiag[ker_baseidx + 13 * kerplanecount].z * X[25].z);
			F[25].z = (-Kodiag[ker_baseidx + 13 * kerplanecount].y * X[25].x) + (Kodiag[ker_baseidx + 13 * kerplanecount].z * X[25].y) + (Kdiag[ker_baseidx + 13 * kerplanecount].z * X[25].z);

			F[5].x = (Kdiag[ker_baseidx + 12 * kerplanecount].x * X[5].x) + (-Kodiag[ker_baseidx + 12 * kerplanecount].x * X[5].y) + (-Kodiag[ker_baseidx + 12 * kerplanecount].y * X[5].z);
			F[5].y = (-Kodiag[ker_baseidx + 12 * kerplanecount].x * X[5].x) + (Kdiag[ker_baseidx + 12 * kerplanecount].y * X[5].y) + (Kodiag[ker_baseidx + 12 * kerplanecount].z * X[5].z);
			F[5].z = (-Kodiag[ker_baseidx + 12 * kerplanecount].y * X[5].x) + (Kodiag[ker_baseidx + 12 * kerplanecount].z * X[5].y) + (Kdiag[ker_baseidx + 12 * kerplanecount].z * X[5].z);

			F[21].x = (Kdiag[ker_baseidx + 11 * kerplanecount].x * X[21].x) + (-Kodiag[ker_baseidx + 11 * kerplanecount].x * X[21].y) + (-Kodiag[ker_baseidx + 11 * kerplanecount].y * X[21].z);
			F[21].y = (-Kodiag[ker_baseidx + 11 * kerplanecount].x * X[21].x) + (Kdiag[ker_baseidx + 11 * kerplanecount].y * X[21].y) + (Kodiag[ker_baseidx + 11 * kerplanecount].z * X[21].z);
			F[21].z = (-Kodiag[ker_baseidx + 11 * kerplanecount].y * X[21].x) + (Kodiag[ker_baseidx + 11 * kerplanecount].z * X[21].y) + (Kdiag[ker_baseidx + 11 * kerplanecount].z * X[21].z);

			F[13].x = (Kdiag[ker_baseidx + 10 * kerplanecount].x * X[13].x) + (-Kodiag[ker_baseidx + 10 * kerplanecount].x * X[13].y) + (-Kodiag[ker_baseidx + 10 * kerplanecount].y * X[13].z);
			F[13].y = (-Kodiag[ker_baseidx + 10 * kerplanecount].x * X[13].x) + (Kdiag[ker_baseidx + 10 * kerplanecount].y * X[13].y) + (Kodiag[ker_baseidx + 10 * kerplanecount].z * X[13].z);
			F[13].z = (-Kodiag[ker_baseidx + 10 * kerplanecount].y * X[13].x) + (Kodiag[ker_baseidx + 10 * kerplanecount].z * X[13].y) + (Kdiag[ker_baseidx + 10 * kerplanecount].z * X[13].z);

			F[29].x = (Kdiag[ker_baseidx + 9 * kerplanecount].x * X[29].x) + (-Kodiag[ker_baseidx + 9 * kerplanecount].x * X[29].y) + (-Kodiag[ker_baseidx + 9 * kerplanecount].y * X[29].z);
			F[29].y = (-Kodiag[ker_baseidx + 9 * kerplanecount].x * X[29].x) + (Kdiag[ker_baseidx + 9 * kerplanecount].y * X[29].y) + (Kodiag[ker_baseidx + 9 * kerplanecount].z * X[29].z);
			F[29].z = (-Kodiag[ker_baseidx + 9 * kerplanecount].y * X[29].x) + (Kodiag[ker_baseidx + 9 * kerplanecount].z * X[29].y) + (Kdiag[ker_baseidx + 9 * kerplanecount].z * X[29].z);

			F[3].x = (Kdiag[ker_baseidx + 8 * kerplanecount].x * X[3].x) + (-Kodiag[ker_baseidx + 8 * kerplanecount].x * X[3].y) + (-Kodiag[ker_baseidx + 8 * kerplanecount].y * X[3].z);
			F[3].y = (-Kodiag[ker_baseidx + 8 * kerplanecount].x * X[3].x) + (Kdiag[ker_baseidx + 8 * kerplanecount].y * X[3].y) + (Kodiag[ker_baseidx + 8 * kerplanecount].z * X[3].z);
			F[3].z = (-Kodiag[ker_baseidx + 8 * kerplanecount].y * X[3].x) + (Kodiag[ker_baseidx + 8 * kerplanecount].z * X[3].y) + (Kdiag[ker_baseidx + 8 * kerplanecount].z * X[3].z);

			F[19].x = (Kdiag[ker_baseidx + 7 * kerplanecount].x * X[19].x) + (-Kodiag[ker_baseidx + 7 * kerplanecount].x * X[19].y) + (-Kodiag[ker_baseidx + 7 * kerplanecount].y * X[19].z);
			F[19].y = (-Kodiag[ker_baseidx + 7 * kerplanecount].x * X[19].x) + (Kdiag[ker_baseidx + 7 * kerplanecount].y * X[19].y) + (Kodiag[ker_baseidx + 7 * kerplanecount].z * X[19].z);
			F[19].z = (-Kodiag[ker_baseidx + 7 * kerplanecount].y * X[19].x) + (Kodiag[ker_baseidx + 7 * kerplanecount].z * X[19].y) + (Kdiag[ker_baseidx + 7 * kerplanecount].z * X[19].z);

			F[11].x = (Kdiag[ker_baseidx + 6 * kerplanecount].x * X[11].x) + (-Kodiag[ker_baseidx + 6 * kerplanecount].x * X[11].y) + (-Kodiag[ker_baseidx + 6 * kerplanecount].y * X[11].z);
			F[11].y = (-Kodiag[ker_baseidx + 6 * kerplanecount].x * X[11].x) + (Kdiag[ker_baseidx + 6 * kerplanecount].y * X[11].y) + (Kodiag[ker_baseidx + 6 * kerplanecount].z * X[11].z);
			F[11].z = (-Kodiag[ker_baseidx + 6 * kerplanecount].y * X[11].x) + (Kodiag[ker_baseidx + 6 * kerplanecount].z * X[11].y) + (Kdiag[ker_baseidx + 6 * kerplanecount].z * X[11].z);

			F[27].x = (Kdiag[ker_baseidx + 5 * kerplanecount].x * X[27].x) + (-Kodiag[ker_baseidx + 5 * kerplanecount].x * X[27].y) + (-Kodiag[ker_baseidx + 5 * kerplanecount].y * X[27].z);
			F[27].y = (-Kodiag[ker_baseidx + 5 * kerplanecount].x * X[27].x) + (Kdiag[ker_baseidx + 5 * kerplanecount].y * X[27].y) + (Kodiag[ker_baseidx + 5 * kerplanecount].z * X[27].z);
			F[27].z = (-Kodiag[ker_baseidx + 5 * kerplanecount].y * X[27].x) + (Kodiag[ker_baseidx + 5 * kerplanecount].z * X[27].y) + (Kdiag[ker_baseidx + 5 * kerplanecount].z * X[27].z);

			F[7].x = (Kdiag[ker_baseidx + 4 * kerplanecount].x * X[7].x) + (-Kodiag[ker_baseidx + 4 * kerplanecount].x * X[7].y) + (-Kodiag[ker_baseidx + 4 * kerplanecount].y * X[7].z);
			F[7].y = (-Kodiag[ker_baseidx + 4 * kerplanecount].x * X[7].x) + (Kdiag[ker_baseidx + 4 * kerplanecount].y * X[7].y) + (Kodiag[ker_baseidx + 4 * kerplanecount].z * X[7].z);
			F[7].z = (-Kodiag[ker_baseidx + 4 * kerplanecount].y * X[7].x) + (Kodiag[ker_baseidx + 4 * kerplanecount].z * X[7].y) + (Kdiag[ker_baseidx + 4 * kerplanecount].z * X[7].z);

			F[23].x = (Kdiag[ker_baseidx + 3 * kerplanecount].x * X[23].x) + (-Kodiag[ker_baseidx + 3 * kerplanecount].x * X[23].y) + (-Kodiag[ker_baseidx + 3 * kerplanecount].y * X[23].z);
			F[23].y = (-Kodiag[ker_baseidx + 3 * kerplanecount].x * X[23].x) + (Kdiag[ker_baseidx + 3 * kerplanecount].y * X[23].y) + (Kodiag[ker_baseidx + 3 * kerplanecount].z * X[23].z);
			F[23].z = (-Kodiag[ker_baseidx + 3 * kerplanecount].y * X[23].x) + (Kodiag[ker_baseidx + 3 * kerplanecount].z * X[23].y) + (Kdiag[ker_baseidx + 3 * kerplanecount].z * X[23].z);

			F[15].x = (Kdiag[ker_baseidx + 2 * kerplanecount].x * X[15].x) + (-Kodiag[ker_baseidx + 2 * kerplanecount].x * X[15].y) + (-Kodiag[ker_baseidx + 2 * kerplanecount].y * X[15].z);
			F[15].y = (-Kodiag[ker_baseidx + 2 * kerplanecount].x * X[15].x) + (Kdiag[ker_baseidx + 2 * kerplanecount].y * X[15].y) + (Kodiag[ker_baseidx + 2 * kerplanecount].z * X[15].z);
			F[15].z = (-Kodiag[ker_baseidx + 2 * kerplanecount].y * X[15].x) + (Kodiag[ker_baseidx + 2 * kerplanecount].z * X[15].y) + (Kdiag[ker_baseidx + 2 * kerplanecount].z * X[15].z);

			F[31].x = (Kdiag[ker_baseidx + 1 * kerplanecount].x * X[31].x) + (-Kodiag[ker_baseidx + 1 * kerplanecount].x * X[31].y) + (-Kodiag[ker_baseidx + 1 * kerplanecount].y * X[31].z);
			F[31].y = (-Kodiag[ker_baseidx + 1 * kerplanecount].x * X[31].x) + (Kdiag[ker_baseidx + 1 * kerplanecount].y * X[31].y) + (Kodiag[ker_baseidx + 1 * kerplanecount].z * X[31].z);
			F[31].z = (-Kodiag[ker_baseidx + 1 * kerplanecount].y * X[31].x) + (Kodiag[ker_baseidx + 1 * kerplanecount].z * X[31].y) + (Kdiag[ker_baseidx + 1 * kerplanecount].z * X[31].z);
		}
		
		//inverse z-axis fft (but without division by 32). Also only keep first 16 points.
		
		//radix-2 stage to start
		X[0] = F[0] + F[1];
		X[1] = F[0] - F[1];

		X[2] = F[2] + F[3];
		X[3] = F[2] - F[3];

		X[4] = F[4] + F[5];
		X[5] = F[4] - F[5];

		X[6] = F[6] + F[7];
		X[7] = F[6] - F[7];

		X[8] = F[8] + F[9];
		X[9] = F[8] - F[9];

		X[10] = F[10] + F[11];
		X[11] = F[10] - F[11];

		X[12] = F[12] + F[13];
		X[13] = F[12] - F[13];

		X[14] = F[14] + F[15];
		X[15] = F[14] - F[15];

		X[16] = F[16] + F[17];
		X[17] = F[16] - F[17];

		X[18] = F[18] + F[19];
		X[19] = F[18] - F[19];

		X[20] = F[20] + F[21];
		X[21] = F[20] - F[21];

		X[22] = F[22] + F[23];
		X[23] = F[22] - F[23];

		X[24] = F[24] + F[25];
		X[25] = F[24] - F[25];

		X[26] = F[26] + F[27];
		X[27] = F[26] - F[27];

		X[28] = F[28] + F[29];
		X[29] = F[28] - F[29];

		X[30] = F[30] + F[31];
		X[31] = F[30] - F[31];
		
		//First radix-4 stage

		//j = 0 (no multiplications)
		t0 = (X[0] + X[2]);
		t1 = (X[0] - X[2]);
		t2 = (X[4] + X[6]);
		t3 = !(X[6] - X[4]);

		X[0] = t0 + t2;
		X[2] = t1 - t3;
		X[4] = t0 - t2;
		X[6] = t1 + t3;

		t0 = (X[8] + X[10]);
		t1 = (X[8] - X[10]);
		t2 = (X[12] + X[14]);
		t3 = !(X[14] - X[12]);

		X[8] = t0 + t2;
		X[10] = t1 - t3;
		X[12] = t0 - t2;
		X[14] = t1 + t3;

		t0 = (X[16] + X[18]);
		t1 = (X[16] - X[18]);
		t2 = (X[20] + X[22]);
		t3 = !(X[22] - X[20]);

		X[16] = t0 + t2;
		X[18] = t1 - t3;
		X[20] = t0 - t2;
		X[22] = t1 + t3;

		t0 = (X[24] + X[26]);
		t1 = (X[24] - X[26]);
		t2 = (X[28] + X[30]);
		t3 = !(X[30] - X[28]);

		X[24] = t0 + t2;
		X[26] = t1 - t3;
		X[28] = t0 - t2;
		X[30] = t1 + t3;
		
		//j = 1
		t0 = (X[1] + !X[3]);
		t1 = (X[1] - !X[3]);
		t2 = (X[5] * cuReIm(g, g) + X[7] * cuReIm(-g, g));
		t3 = (X[7] * cuReIm(-g, -g) - X[5] * cuReIm(-g, g));

		X[1] = t0 + t2;
		X[3] = t1 - t3;
		X[5] = t0 - t2;
		X[7] = t1 + t3;

		t0 = (X[9] + !X[11]);
		t1 = (X[9] - !X[11]);
		t2 = (X[13] * cuReIm(g, g) + X[15] * cuReIm(-g, g));
		t3 = (X[15] * cuReIm(-g, -g) - X[13] * cuReIm(-g, g));

		X[9] = t0 + t2;
		X[11] = t1 - t3;
		X[13] = t0 - t2;
		X[15] = t1 + t3;

		t0 = (X[17] + !X[19]);
		t1 = (X[17] - !X[19]);
		t2 = (X[21] * cuReIm(g, g) + X[23] * cuReIm(-g, g));
		t3 = (X[23] * cuReIm(-g, -g) - X[21] * cuReIm(-g, g));

		X[17] = t0 + t2;
		X[19] = t1 - t3;
		X[21] = t0 - t2;
		X[23] = t1 + t3;

		t0 = (X[25] + !X[27]);
		t1 = (X[25] - !X[27]);
		t2 = (X[29] * cuReIm(g, g) + X[31] * cuReIm(-g, g));
		t3 = (X[31] * cuReIm(-g, -g) - X[29] * cuReIm(-g, g));

		X[25] = t0 + t2;
		X[27] = t1 - t3;
		X[29] = t0 - t2;
		X[31] = t1 + t3;

		//Output radix-4 stage (truncated output)
		//j = 0
		t0 = (X[0] + X[8]);
		t1 = (X[0] - X[8]);
		t2 = (X[16] + X[24]);
		t3 = !(X[24] - X[16]);

		cuReIm3 l = t0 + t2;
		cuReIm3 h = t1 - t3;

		cuSx[idx] = l.x;
		cuSy[idx] = l.y;
		cuSz[idx] = l.z;
		cuSx[idx + 8 * planecount] = h.x;
		cuSy[idx + 8 * planecount] = h.y;
		cuSz[idx + 8 * planecount] = h.z;

		//j = 1
		t0 = (X[1] + X[9] * cuReIm(c, d));
		t1 = (X[1] - X[9] * cuReIm(c, d));
		t2 = (X[17] * cuReIm(a, b) + X[25] * cuReIm(e, f));
		t3 = (X[25] * cuReIm(-f, e) - X[17] * cuReIm(-b, a));

		l = t0 + t2;
		h = t1 - t3;

		cuSx[idx + planecount] = l.x;
		cuSy[idx + planecount] = l.y;
		cuSz[idx + planecount] = l.z;
		cuSx[idx + 9 * planecount] = h.x;
		cuSy[idx + 9 * planecount] = h.y;
		cuSz[idx + 9 * planecount] = h.z;

		//j = 2
		t0 = (X[2] + X[10] * cuReIm(g, g));
		t1 = (X[2] - X[10] * cuReIm(g, g));
		t2 = (X[18] * cuReIm(c, d) + X[26] * cuReIm(d, c));
		t3 = (X[26] * cuReIm(-c, d) - X[18] * cuReIm(-d, c));

		l = t0 + t2;
		h = t1 - t3;

		cuSx[idx + 2 * planecount] = l.x;
		cuSy[idx + 2 * planecount] = l.y;
		cuSz[idx + 2 * planecount] = l.z;
		cuSx[idx + 10 * planecount] = h.x;
		cuSy[idx + 10 * planecount] = h.y;
		cuSz[idx + 10 * planecount] = h.z;

		//j = 3
		t0 = (X[3] + X[11] * cuReIm(d, c));
		t1 = (X[3] - X[11] * cuReIm(d, c));
		t2 = (X[19] * cuReIm(e, f) + X[27] * cuReIm(-b, a));
		t3 = (X[27] * cuReIm(-a, -b) - X[19] * cuReIm(-f, e));

		l = t0 + t2;
		h = t1 - t3;

		cuSx[idx + 3 * planecount] = l.x;
		cuSy[idx + 3 * planecount] = l.y;
		cuSz[idx + 3 * planecount] = l.z;
		cuSx[idx + 11 * planecount] = h.x;
		cuSy[idx + 11 * planecount] = h.y;
		cuSz[idx + 11 * planecount] = h.z;

		//j = 4
		t0 = (X[4] + !X[12]);
		t1 = (X[4] - !X[12]);
		t2 = (X[20] * cuReIm(g, g) + X[28] * cuReIm(-g, g));
		t3 = (X[28] * cuReIm(-g, -g) - X[20] * cuReIm(-g, g));

		l = t0 + t2;
		h = t1 - t3;

		cuSx[idx + 4 * planecount] = l.x;
		cuSy[idx + 4 * planecount] = l.y;
		cuSz[idx + 4 * planecount] = l.z;
		cuSx[idx + 12 * planecount] = h.x;
		cuSy[idx + 12 * planecount] = h.y;
		cuSz[idx + 12 * planecount] = h.z;

		//j = 5
		t0 = (X[5] + X[13] * cuReIm(-d, c));
		t1 = (X[5] - X[13] * cuReIm(-d, c));
		t2 = (X[21] * cuReIm(f, e) + X[29] * cuReIm(-a, b));
		t3 = (X[29] * cuReIm(-b, -a) - X[21] * cuReIm(-e, f));

		l = t0 + t2;
		h = t1 - t3;

		cuSx[idx + 5 * planecount] = l.x;
		cuSy[idx + 5 * planecount] = l.y;
		cuSz[idx + 5 * planecount] = l.z;
		cuSx[idx + 13 * planecount] = h.x;
		cuSy[idx + 13 * planecount] = h.y;
		cuSz[idx + 13 * planecount] = h.z;

		//j = 6
		t0 = (X[6] + X[14] * cuReIm(-g, g));
		t1 = (X[6] - X[14] * cuReIm(-g, g));
		t2 = (X[22] * cuReIm(d, c) + X[30] * cuReIm(-c, -d));
		t3 = (X[30] * cuReIm(d, -c) - X[22] * cuReIm(-c, d));

		l = t0 + t2;
		h = t1 - t3;

		cuSx[idx + 6 * planecount] = l.x;
		cuSy[idx + 6 * planecount] = l.y;
		cuSz[idx + 6 * planecount] = l.z;
		cuSx[idx + 14 * planecount] = h.x;
		cuSy[idx + 14 * planecount] = h.y;
		cuSz[idx + 14 * planecount] = h.z;

		//j = 7
		t0 = (X[7] + X[15] * cuReIm(-c, d));
		t1 = (X[7] - X[15] * cuReIm(-c, d));
		t2 = (X[23] * cuReIm(b, a) + X[31] * cuReIm(-f, -e));
		t3 = (X[31] * cuReIm(e, -f) - X[23] * cuReIm(-a, b));

		l = t0 + t2;
		h = t1 - t3;

		cuSx[idx + 7 * planecount] = l.x;
		cuSy[idx + 7 * planecount] = l.y;
		cuSz[idx + 7 * planecount] = l.z;
		cuSx[idx + 15 * planecount] = h.x;
		cuSy[idx + 15 * planecount] = h.y;
		cuSz[idx + 15 * planecount] = h.z;

#undef a
#undef b
#undef c
#undef d
#undef e
#undef f
#undef g
	}
}

//-------------------------- RUN-TIME KERNEL MULTIPLICATION

void DemagKernelCUDA::KernelMultiplication_2D(void)
{
	if (transpose_xy) {
		
		cu_Demag_ConvProd_2D_transpose_xy << < ((N.x / 2 + 1)*N.y + CUDATHREADS) / CUDATHREADS, CUDATHREADS >> > (Kdiag, K2D_odiag, cuS_x, cuS_y, cuS_z, cuN);
	}
	else {

		cu_Demag_ConvProd_2D << < ((N.x / 2 + 1)*N.y + CUDATHREADS) / CUDATHREADS, CUDATHREADS >> > (Kdiag, K2D_odiag, cuS_x, cuS_y, cuS_z, cuN);
	}
}

void DemagKernelCUDA::KernelMultiplication_3D(void)
{
	//transpose_xy always true in 3D
	cu_Demag_ConvProd_3D_transpose_xy << < ((N.x / 2 + 1)*N.y*N.z + CUDATHREADS) / CUDATHREADS, CUDATHREADS >> > (Kdiag, Kodiag, cuS_x, cuS_y, cuS_z, cuN);
}

//Kernel multiplication in quasi-2D mode : z-axis fft / kernel multiplication / z-axis ifft rolled into one (but do not divide by N for the ifft)
void DemagKernelCUDA::KernelMultiplication_q2D(int q2D_level)
{
	//transpose_xy always true in 3D (including q2D)

	switch (q2D_level)
	{
		//N.z = 4, n.z = 2
	case 4:
		cu_Demag_ConvProd_q2D_4_transpose_xy << < ((N.x / 2 + 1)*N.y + CUDATHREADS) / CUDATHREADS, CUDATHREADS >> > (Kdiag, Kodiag, cuS_x, cuS_y, cuS_z, cuN);
		break;

		//N.z = 8, n.z = 3, 4
	case 8:
		cu_Demag_ConvProd_q2D_8_transpose_xy << < ((N.x / 2 + 1)*N.y + CUDATHREADS) / CUDATHREADS, CUDATHREADS >> > (Kdiag, Kodiag, cuS_x, cuS_y, cuS_z, cuN);
		break;

		//N.z = 16, n.z = 5, 6, 7, 8
	case 16:
		cu_Demag_ConvProd_q2D_16_transpose_xy << < ((N.x / 2 + 1)*N.y + CUDATHREADS) / CUDATHREADS, CUDATHREADS >> > (Kdiag, Kodiag, cuS_x, cuS_y, cuS_z, cuN);
		break;

		//N.z = 32, n.z = 9, 10, ..., 16
	case 32:
		cu_Demag_ConvProd_q2D_32_transpose_xy << < ((N.x / 2 + 1)*N.y + CUDATHREADS) / CUDATHREADS, CUDATHREADS >> > (Kdiag, Kodiag, cuS_x, cuS_y, cuS_z, cuN);
		break;

		//higher values not handled in q2D mode as they are slower than full 3D mode
	}
}

#endif

#endif

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
///////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

/*
//NOT IN USE : this is an example of the general case algorithm applied to q2D_level = 32, for testing only.
//This works, tested. You can use half-sized scratch spaces with this particular case.

//you need exp factors and shuffling indexes : see general purpose algorithm comments.

//N = (N.x/2 + 1, N.y, N.z), where N.z > 32
//xy is transposed
__global__ void cu_Demag_ConvProd_q2D_32_transpose_xy(cuVEC<cuReal3>& Kdiag, cuVEC<cuReal3>& Kodiag, cuComplex* cuSx, cuComplex* cuSy, cuComplex* cuSz, cuSZ3& N, cuReIm* econj, cuReIm* cossin, int* shufind)
{
	//above N.z/2 and N.y/2 use kernel symmetries to recover kernel values
	//diagonal components are even about the N.z/2 and N.y/2 points
	//Kxy is even about N.z/2 and odd about N.y/2
	//Kxz is odd about N.z/2 and even about N.y/2
	//Kyz is odd about N.z/2 and odd about N.y/2

	int idx = blockDim.x * blockIdx.x + threadIdx.x;

	//This kernel was called with (N.x/2 + 1) * N.y points: handle all z points in one go
	int planecount = (N.x / 2 + 1) * N.y;

	//kernels packed into planes of (N.y / 2 + 1) * (N.x / 2 + 1) size
	int kerplanecount = (N.x / 2 + 1) * (N.y / 2 + 1);

	if (idx < planecount) {

		int i0, i1, i2, i3, p;
		int N2, N4;

		cuReIm3 t0, t1, t2, t3;

		cuReIm3 X[32];

		int ldn = 5;

		//input data
#define x(n)	(cuReIm3(cuSx[idx + (n) * planecount], cuSy[idx + (n) * planecount], cuSz[idx + (n) * planecount]))

		//input radix-4 stage stage with zero padded input
		N2 = N.z;
		N4 = N.z / 4;

		//j = 0, 1, ..., N / 4 - 1 (r = 0)

		//j = 0 separated (no multiplications)
		X[0] = (x(0) + x(N4));
		X[N4] = (x(0) - x(N4));
		X[2 * N4] = (x(0) - !x(N4));
		X[3 * N4] = (x(0) + !x(N4));

		//Remaining cases from j = 1 upwards
		for (int j = 1; j < N4; j++) {

			X[j] = (x(j) + x(j + N4));
			X[j + N4] = (x(j) - x(j + N4)) * econj[2 * j];
			X[j + 2 * N4] = (x(j) - !x(j + N4)) * econj[j];
			X[j + 3 * N4] = (x(j) + !x(j + N4)) * econj[3 * j];
		}

#undef x

		//remaining radix-4 stages
		for (p = ldn - 2; p >= 2; p -= 2) {

			N2 /= 4;
			N4 = N2 / 4;

			//Special case j = 0 separated from loop : no multiplications.
			for (int r = 0; r < N.z; r += N2) {

				i1 = r + N4;
				i2 = i1 + N4;
				i3 = i2 + N4;

				t0 = (X[r] + X[i2]);
				t1 = (X[r] - X[i2]);
				t2 = (X[i1] + X[i3]);
				t3 = !(X[i3] - X[i1]);

				X[r] = (t0 + t2);
				X[i1] = (t0 - t2);
				X[i2] = (t1 + t3);
				X[i3] = (t1 - t3);
			}

			//Remaining cases from j = 1 upwards
			for (int j = 1; j < N4; j++) {

				for (int r = 0; r < N.z; r += N2) {

					i0 = j + r;
					i1 = i0 + N4;
					i2 = i1 + N4;
					i3 = i2 + N4;

					t0 = (X[i0] + X[i2]);
					t1 = (X[i0] - X[i2]);
					t2 = (X[i1] + X[i3]);
					t3 = !(X[i3] - X[i1]);

					X[i0] = (t0 + t2);
					X[i1] = (t0 - t2) * econj[2 * j * N.z / N2];
					X[i2] = (t1 + t3) * econj[j * N.z / N2];
					X[i3] = (t1 - t3) * econj[3 * j * N.z / N2];
				}
			}
		}

		p = (ldn & 1);

		//if N is not a power of 4, need a radix-2 step
		if (p != 0) {

			for (i0 = 0; i0 < N.z; i0 += 2) {

				t0 = X[i0] - X[i0 + 1];
				X[i0] = X[i0] + X[i0 + 1];
				X[i0 + 1] = t0;
			}
		}

		int i = idx % N.y;
		int j = (idx / N.y) % (N.x / 2 + 1);

		cuReIm3 F[32];

		if (i <= N.y / 2) {

			int ker_baseidx = i + j * (N.y / 2 + 1);

			F[0].x = (Kdiag[ker_baseidx].x * X[0].x) + (Kodiag[ker_baseidx].x * X[0].y) + (Kodiag[ker_baseidx].y * X[0].z);
			F[0].y = (Kodiag[ker_baseidx].x * X[0].x) + (Kdiag[ker_baseidx].y * X[0].y) + (Kodiag[ker_baseidx].z * X[0].z);
			F[0].z = (Kodiag[ker_baseidx].y * X[0].x) + (Kodiag[ker_baseidx].z * X[0].y) + (Kdiag[ker_baseidx].z * X[0].z);

			F[1].x = (Kdiag[ker_baseidx + (N.z / 2) * kerplanecount].x * X[1].x) + (Kodiag[ker_baseidx + (N.z / 2) * kerplanecount].x * X[1].y) + (Kodiag[ker_baseidx + (N.z / 2) * kerplanecount].y * X[1].z);
			F[1].y = (Kodiag[ker_baseidx + (N.z / 2) * kerplanecount].x * X[1].x) + (Kdiag[ker_baseidx + (N.z / 2) * kerplanecount].y * X[1].y) + (Kodiag[ker_baseidx + (N.z / 2) * kerplanecount].z * X[1].z);
			F[1].z = (Kodiag[ker_baseidx + (N.z / 2) * kerplanecount].y * X[1].x) + (Kodiag[ker_baseidx + (N.z / 2) * kerplanecount].z * X[1].y) + (Kdiag[ker_baseidx + (N.z / 2) * kerplanecount].z * X[1].z);

			for (int kidx = 1; kidx < N.z / 2; kidx++) {

				int sidx_l = shufind[kidx];
				int sidx_h = shufind[N.z - kidx];

				F[sidx_l].x = (Kdiag[ker_baseidx + kidx * kerplanecount].x * X[sidx_l].x) + (Kodiag[ker_baseidx + kidx * kerplanecount].x * X[sidx_l].y) + (Kodiag[ker_baseidx + kidx * kerplanecount].y * X[sidx_l].z);
				F[sidx_l].y = (Kodiag[ker_baseidx + kidx * kerplanecount].x * X[sidx_l].x) + (Kdiag[ker_baseidx + kidx * kerplanecount].y * X[sidx_l].y) + (Kodiag[ker_baseidx + kidx * kerplanecount].z * X[sidx_l].z);
				F[sidx_l].z = (Kodiag[ker_baseidx + kidx * kerplanecount].y * X[sidx_l].x) + (Kodiag[ker_baseidx + kidx * kerplanecount].z * X[sidx_l].y) + (Kdiag[ker_baseidx + kidx * kerplanecount].z * X[sidx_l].z);

				F[sidx_h].x = (Kdiag[ker_baseidx + kidx * kerplanecount].x * X[sidx_h].x) + (Kodiag[ker_baseidx + kidx * kerplanecount].x * X[sidx_h].y) + (-Kodiag[ker_baseidx + kidx * kerplanecount].y * X[sidx_h].z);
				F[sidx_h].y = (Kodiag[ker_baseidx + kidx * kerplanecount].x * X[sidx_h].x) + (Kdiag[ker_baseidx + kidx * kerplanecount].y * X[sidx_h].y) + (-Kodiag[ker_baseidx + kidx * kerplanecount].z * X[sidx_h].z);
				F[sidx_h].z = (-Kodiag[ker_baseidx + kidx * kerplanecount].y * X[sidx_h].x) + (-Kodiag[ker_baseidx + kidx * kerplanecount].z * X[sidx_h].y) + (Kdiag[ker_baseidx + kidx * kerplanecount].z * X[sidx_h].z);
			}
		}
		else {

			int ker_baseidx = (N.y - i) + j * (N.y / 2 + 1);

			F[0].x = (Kdiag[ker_baseidx].x * X[0].x) + (-Kodiag[ker_baseidx].x * X[0].y) + (Kodiag[ker_baseidx].y * X[0].z);
			F[0].y = (-Kodiag[ker_baseidx].x * X[0].x) + (Kdiag[ker_baseidx].y * X[0].y) + (-Kodiag[ker_baseidx].z * X[0].z);
			F[0].z = (Kodiag[ker_baseidx].y * X[0].x) + (-Kodiag[ker_baseidx].z * X[0].y) + (Kdiag[ker_baseidx].z * X[0].z);

			F[1].x = (Kdiag[ker_baseidx + (N.z / 2) * kerplanecount].x * X[1].x) + (-Kodiag[ker_baseidx + (N.z / 2) * kerplanecount].x * X[1].y) + (Kodiag[ker_baseidx + (N.z / 2) * kerplanecount].y * X[1].z);
			F[1].y = (-Kodiag[ker_baseidx + (N.z / 2) * kerplanecount].x * X[1].x) + (Kdiag[ker_baseidx + (N.z / 2) * kerplanecount].y * X[1].y) + (-Kodiag[ker_baseidx + (N.z / 2) * kerplanecount].z * X[1].z);
			F[1].z = (Kodiag[ker_baseidx + (N.z / 2) * kerplanecount].y * X[1].x) + (-Kodiag[ker_baseidx + (N.z / 2) * kerplanecount].z * X[1].y) + (Kdiag[ker_baseidx + (N.z / 2) * kerplanecount].z * X[1].z);

			for (int kidx = 1; kidx < N.z / 2; kidx++) {

				int sidx_l = shufind[kidx];
				int sidx_h = shufind[N.z - kidx];

				F[sidx_l].x = (Kdiag[ker_baseidx + kidx * kerplanecount].x * X[sidx_l].x) + (-Kodiag[ker_baseidx + kidx * kerplanecount].x * X[sidx_l].y) + (Kodiag[ker_baseidx + kidx * kerplanecount].y * X[sidx_l].z);
				F[sidx_l].y = (-Kodiag[ker_baseidx + kidx * kerplanecount].x * X[sidx_l].x) + (Kdiag[ker_baseidx + kidx * kerplanecount].y * X[sidx_l].y) + (-Kodiag[ker_baseidx + kidx * kerplanecount].z * X[sidx_l].z);
				F[sidx_l].z = (Kodiag[ker_baseidx + kidx * kerplanecount].y * X[sidx_l].x) + (-Kodiag[ker_baseidx + kidx * kerplanecount].z * X[sidx_l].y) + (Kdiag[ker_baseidx + kidx * kerplanecount].z * X[sidx_l].z);

				F[sidx_h].x = (Kdiag[ker_baseidx + kidx * kerplanecount].x * X[sidx_h].x) + (-Kodiag[ker_baseidx + kidx * kerplanecount].x * X[sidx_h].y) + (-Kodiag[ker_baseidx + kidx * kerplanecount].y * X[sidx_h].z);
				F[sidx_h].y = (-Kodiag[ker_baseidx + kidx * kerplanecount].x * X[sidx_h].x) + (Kdiag[ker_baseidx + kidx * kerplanecount].y * X[sidx_h].y) + (Kodiag[ker_baseidx + kidx * kerplanecount].z * X[sidx_h].z);
				F[sidx_h].z = (-Kodiag[ker_baseidx + kidx * kerplanecount].y * X[sidx_h].x) + (Kodiag[ker_baseidx + kidx * kerplanecount].z * X[sidx_h].y) + (Kdiag[ker_baseidx + kidx * kerplanecount].z * X[sidx_h].z);
			}
		}

		//inverse z-axis fft (but without division by N.z). Also only keep first N.z/2 points.

		p = (ldn & 1);

		// n is not a power of 4, need a radix-2 step
		if (p != 0) {

			for (i0 = 0; i0 < N.z; i0 += 2) {

				t0 = F[i0] - F[i0 + 1];
				F[i0] = F[i0] + F[i0 + 1];
				F[i0 + 1] = t0;
			}
		}

		N2 = (1 << p);

		//radix-4 stages
		for (p = p + 2; p <= ldn - 2; p += 2) {

			N4 = N2;
			N2 *= 4;

			//Special case j = 0 separated from loop : no multiplications.
			for (int r = 0; r < N.z; r += N2) {

				i1 = r + N4;
				i2 = i1 + N4;
				i3 = i2 + N4;

				t0 = (F[r] + F[i1]);
				t1 = (F[r] - F[i1]);
				t2 = (F[i2] + F[i3]);
				t3 = !(F[i3] - F[i2]);

				X[r] = t0 + t2;
				X[i1] = t1 - t3;
				X[i2] = t0 - t2;
				X[i3] = t1 + t3;
			}

			//Remaining cases from j = 1 upwards
			for (int j = 1; j < N4; j++) {

				for (int r = 0; r < N.z; r += N2) {

					i0 = j + r;
					i1 = i0 + N4;
					i2 = i1 + N4;
					i3 = i2 + N4;

					t0 = (F[i0] + F[i1] * cossin[2 * j * N.z / N2]);
					t1 = (F[i0] - F[i1] * cossin[2 * j * N.z / N2]);
					t2 = (F[i2] * cossin[j * N.z / N2] + F[i3] * cossin[3 * j * N.z / N2]);
					t3 = !(F[i3] * cossin[3 * j * N.z / N2] - F[i2] * cossin[j * N.z / N2]);

					X[i0] = t0 + t2;
					X[i1] = t1 - t3;
					X[i2] = t0 - t2;
					X[i3] = t1 + t3;
				}
			}
		}

		//output radix-4 stage

		N4 = N.z / 4;

		//j = 0, 1, ..., N / 4 - 1

		//j = 0 (no multiplications)
		t0 = (X[0] + X[N4]);
		t1 = (X[0] - X[N4]);
		t2 = (X[2 * N4] + X[3 * N4]);
		t3 = !(X[3 * N4] - X[2 * N4]);

		cuReIm3 l = t0 + t2;
		cuReIm3 h = t1 - t3;

		cuSx[idx] = l.x;
		cuSy[idx] = l.y;
		cuSz[idx] = l.z;
		cuSx[idx + N4 * planecount] = h.x;
		cuSy[idx + N4 * planecount] = h.y;
		cuSz[idx + N4 * planecount] = h.z;

		//Remaining cases from j = 1 upwards
		for (int j = 1; j < N4; j++) {

			i0 = j;
			i1 = i0 + N4;
			i2 = i1 + N4;
			i3 = i2 + N4;

			t0 = (X[i0] + X[i1] * cossin[2 * j]);
			t1 = (X[i0] - X[i1] * cossin[2 * j]);
			t2 = (X[i2] * cossin[j] + X[i3] * cossin[3 * j]);
			t3 = !(X[i3] * cossin[3 * j] - X[i2] * cossin[j]);

			cuReIm3 l = t0 + t2;
			cuReIm3 h = t1 - t3;

			cuSx[idx + i0 * planecount] = l.x;
			cuSy[idx + i0 * planecount] = l.y;
			cuSz[idx + i0 * planecount] = l.z;
			cuSx[idx + i1 * planecount] = h.x;
			cuSy[idx + i1 * planecount] = h.y;
			cuSz[idx + i1 * planecount] = h.z;
		}
	}
}
*/

/*
//NOT IN USE : this is an example of how higher fft powers would be handled in one routine.
//Needs full size scratch spaces.

//This doesn't work correctly when applied to q2D_level > 32, there must be a small mistake somewhere, but not going to spend time finding it as it's slower than full 3D method.

//you need exp factors and shuffling indexes. These would be calculated as:

	{
		cu_arr<cuReIm> econj, cossin;
		cu_arr<int> shufind;

		vector<ReIm> econj_cpu(q2D_level), cossin_cpu(q2D_level);
		vector<int> shufind_cpu(q2D_level);

		//calculate exp factors for FFT/IFFT
		for (int idx = 0; idx < q2D_level; idx++) {

			cossin_cpu[idx] = ReIm(cos(2.0 * PI * idx / q2D_level), sin(2.0 * PI * idx / q2D_level));
			econj_cpu[idx] = ~cossin_cpu[idx];
		}

		//Calculate shuffling indexes for bit-reversed order
		auto ShuffleIndex = [](int n, int N) -> int {

			N /= 2;

			int nt = 0, powkm1 = 1;

			if (!n) return 0;

			for (int k = 1; n; k++, N /= 2) {

				int t = n / N;

				if (!t) {

					powkm1 *= 2;
					continue;
				}

				nt += t * powkm1;
				n -= N;
				powkm1 *= 2;
			}

			return nt;
		};

		for (int p = 0; p < q2D_level; p++) {

			shufind_cpu[p] = ShuffleIndex(p, q2D_level);
		}

		econj.resize(q2D_level);
		cossin.resize(q2D_level);
		shufind.resize(q2D_level);

		econj.copy_from_cpuvector(econj_cpu);
		cossin.copy_from_cpuvector(cossin_cpu);
		shufind.copy_from_cpuvector(shufind_cpu);
	}

//N = (N.x/2 + 1, N.y, N.z), where N.z > 32
//xy is transposed
__global__ void cu_Demag_ConvProd_q2D_N_transpose_xy(cuVEC<cuReal3>& Kdiag, cuVEC<cuReal3>& Kodiag, cuComplex* cuSx, cuComplex* cuSy, cuComplex* cuSz, cuSZ3& N, cuReIm* econj, cuReIm* cossin, int* shufind)
{
	//above N.z/2 and N.y/2 use kernel symmetries to recover kernel values
	//diagonal components are even about the N.z/2 and N.y/2 points
	//Kxy is even about N.z/2 and odd about N.y/2
	//Kxz is odd about N.z/2 and even about N.y/2
	//Kyz is odd about N.z/2 and odd about N.y/2

	int idx = blockDim.x * blockIdx.x + threadIdx.x;

	//This kernel was called with (N.x/2 + 1) * N.y points: handle all z points in one go
	int planecount = (N.x / 2 + 1) * N.y;

	//kernels packed into planes of (N.y / 2 + 1) * (N.x / 2 + 1) size
	int kerplanecount = (N.x / 2 + 1) * (N.y / 2 + 1);

	if (idx < planecount) {

		int i0, i1, i2, i3, p;
		int N2, N4;

		cuReIm3 t0, t1, t2, t3;

		int ldn = log2((cuReal)N.z);

		//input data
#define x(n)	(cuReIm3(cuSx[idx + (n) * planecount], cuSy[idx + (n) * planecount], cuSz[idx + (n) * planecount]))

//write val3 to scratch spaces
#define cuS(n, val3) {\
cuSx[idx + (n)* planecount] = (val3).x;\
cuSy[idx + (n)* planecount] = (val3).y;\
cuSz[idx + (n)* planecount] = (val3).z;\
}

		//input radix-4 stage stage with zero padded input
		N2 = N.z;
		N4 = N.z / 4;

		//j = 0, 1, ..., N / 4 - 1 (r = 0)

		//j = 0 separated (no multiplications)
		t0 = x(0);
		t1 = x(N4);
		
		t2 = t0 + t1;
		cuS(0, t2);
		t2 = t0 - t1;
		cuS(N4, t2);
		t2 = t0 - !t1;
		cuS(2 * N4, t2);
		t2 = t0 + !t1;
		cuS(3 * N4, t2);

		//Remaining cases from j = 1 upwards
		for (int j = 1; j < N4; j++) {

			t0 = x(j);
			t1 = x(j + N4);

			cuS(j, t0 + t1);
			cuS(j + N4, (t0 - t1) * econj[2 * j]);
			cuS(j + 2 * N4, (t0 - !t1) * econj[j]);
			cuS(j + 3 * N4, (t0 + !t1) * econj[3 * j]);
		}

		//remaining radix-4 stages
		for (p = ldn - 2; p >= 2; p -= 2) {

			N2 /= 4;
			N4 = N2 / 4;

			//Special case j = 0 separated from loop : no multiplications.
			for (int r = 0; r < N.z; r += N2) {

				i1 = r + N4;
				i2 = i1 + N4;
				i3 = i2 + N4;

				t0 = (x(r) + x(i2));
				t1 = (x(r) - x(i2));
				t2 = (x(i1) + x(i3));
				t3 = !(x(i3) - x(i1));

				cuS(r, t0 + t2);
				cuS(i1, t0 - t2);
				cuS(i2, t1 + t3);
				cuS(i3, t1 - t3);
			}

			//Remaining cases from j = 1 upwards
			for (int j = 1; j < N4; j++) {

				for (int r = 0; r < N.z; r += N2) {

					i0 = j + r;
					i1 = i0 + N4;
					i2 = i1 + N4;
					i3 = i2 + N4;

					t0 = (x(i0) + x(i2));
					t1 = (x(i0) - x(i2));
					t2 = (x(i1) + x(i3));
					t3 = !(x(i3) - x(i1));

					cuS(i0, t0 + t2);
					cuS(i1, (t0 - t2) * econj[2 * j * N.z / N2]);
					cuS(i2, (t1 + t3) * econj[j * N.z / N2]);
					cuS(i3, (t1 - t3) * econj[3 * j * N.z / N2]);
				}
			}
		}

		p = (ldn & 1);

		//if N is not a power of 4, need a radix-2 step
		if (p != 0) {

			for (i0 = 0; i0 < N.z; i0 += 2) {

				t0 = x(i0) - x(i0 + 1);
				t1 = x(i0) + x(i0 + 1);
				cuS(i0, t1);
				cuS(i0 + 1, t0);
			}
		}

		int i = idx % N.y;
		int j = (idx / N.y) % (N.x / 2 + 1);

		if (i <= N.y / 2) {

			int ker_baseidx = i + j * (N.y / 2 + 1);

			t0 = x(0);
			t1 = x(1);

			cuSx[idx] = (Kdiag[ker_baseidx].x * t0.x) + (Kodiag[ker_baseidx].x * t0.y) + (Kodiag[ker_baseidx].y * t0.z);
			cuSy[idx] = (Kodiag[ker_baseidx].x * t0.x) + (Kdiag[ker_baseidx].y * t0.y) + (Kodiag[ker_baseidx].z * t0.z);
			cuSz[idx] = (Kodiag[ker_baseidx].y * t0.x) + (Kodiag[ker_baseidx].z * t0.y) + (Kdiag[ker_baseidx].z * t0.z);

			cuSx[idx + planecount] = (Kdiag[ker_baseidx + (N.z / 2) * kerplanecount].x * t1.x) + (Kodiag[ker_baseidx + (N.z / 2) * kerplanecount].x * t1.y) + (Kodiag[ker_baseidx + (N.z / 2) * kerplanecount].y * t1.z);
			cuSy[idx + planecount] = (Kodiag[ker_baseidx + (N.z / 2) * kerplanecount].x * t1.x) + (Kdiag[ker_baseidx + (N.z / 2) * kerplanecount].y * t1.y) + (Kodiag[ker_baseidx + (N.z / 2) * kerplanecount].z * t1.z);
			cuSz[idx + planecount] = (Kodiag[ker_baseidx + (N.z / 2) * kerplanecount].y * t1.x) + (Kodiag[ker_baseidx + (N.z / 2) * kerplanecount].z * t1.y) + (Kdiag[ker_baseidx + (N.z / 2) * kerplanecount].z * t1.z);

			for (int kidx = 1; kidx < N.z / 2; kidx++) {

				int sidx_l = shufind[kidx];
				int sidx_h = shufind[N.z - kidx];

				t0 = x(sidx_l);
				t1 = x(sidx_h);

				cuSx[idx + sidx_l * planecount] = (Kdiag[ker_baseidx + kidx * kerplanecount].x * t0.x) + (Kodiag[ker_baseidx + kidx * kerplanecount].x * t0.y) + (Kodiag[ker_baseidx + kidx * kerplanecount].y * t0.z);
				cuSy[idx + sidx_l * planecount] = (Kodiag[ker_baseidx + kidx * kerplanecount].x * t0.x) + (Kdiag[ker_baseidx + kidx * kerplanecount].y * t0.y) + (Kodiag[ker_baseidx + kidx * kerplanecount].z * t0.z);
				cuSz[idx + sidx_l * planecount] = (Kodiag[ker_baseidx + kidx * kerplanecount].y * t0.x) + (Kodiag[ker_baseidx + kidx * kerplanecount].z * t0.y) + (Kdiag[ker_baseidx + kidx * kerplanecount].z * t0.z);

				cuSx[idx + sidx_h * planecount] = (Kdiag[ker_baseidx + kidx * kerplanecount].x * t1.x) + (Kodiag[ker_baseidx + kidx * kerplanecount].x * t1.y) + (-Kodiag[ker_baseidx + kidx * kerplanecount].y * t1.z);
				cuSy[idx + sidx_h * planecount] = (Kodiag[ker_baseidx + kidx * kerplanecount].x * t1.x) + (Kdiag[ker_baseidx + kidx * kerplanecount].y * t1.y) + (-Kodiag[ker_baseidx + kidx * kerplanecount].z * t1.z);
				cuSz[idx + sidx_h * planecount] = (-Kodiag[ker_baseidx + kidx * kerplanecount].y * t1.x) + (-Kodiag[ker_baseidx + kidx * kerplanecount].z * t1.y) + (Kdiag[ker_baseidx + kidx * kerplanecount].z * t1.z);
			}
		}
		else {

			int ker_baseidx = (N.y - i) + j * (N.y / 2 + 1);

			t0 = x(0);
			t1 = x(1);

			cuSx[idx] = (Kdiag[ker_baseidx].x * t0.x) + (-Kodiag[ker_baseidx].x * t0.y) + (Kodiag[ker_baseidx].y * t0.z);
			cuSy[idx] = (-Kodiag[ker_baseidx].x * t0.x) + (Kdiag[ker_baseidx].y * t0.y) + (-Kodiag[ker_baseidx].z * t0.z);
			cuSz[idx] = (Kodiag[ker_baseidx].y * t0.x) + (-Kodiag[ker_baseidx].z * t0.y) + (Kdiag[ker_baseidx].z * t0.z);

			cuSx[idx + planecount] = (Kdiag[ker_baseidx + (N.z / 2) * kerplanecount].x * t1.x) + (-Kodiag[ker_baseidx + (N.z / 2) * kerplanecount].x * t1.y) + (Kodiag[ker_baseidx + (N.z / 2) * kerplanecount].y * t1.z);
			cuSy[idx + planecount] = (-Kodiag[ker_baseidx + (N.z / 2) * kerplanecount].x * t1.x) + (Kdiag[ker_baseidx + (N.z / 2) * kerplanecount].y * t1.y) + (-Kodiag[ker_baseidx + (N.z / 2) * kerplanecount].z * t1.z);
			cuSz[idx + planecount] = (Kodiag[ker_baseidx + (N.z / 2) * kerplanecount].y * t1.x) + (-Kodiag[ker_baseidx + (N.z / 2) * kerplanecount].z * t1.y) + (Kdiag[ker_baseidx + (N.z / 2) * kerplanecount].z * t1.z);

			for (int kidx = 1; kidx < N.z / 2; kidx++) {

				int sidx_l = shufind[kidx];
				int sidx_h = shufind[N.z - kidx];

				t0 = x(sidx_l);
				t1 = x(sidx_h);

				cuSx[idx + sidx_l * planecount] = (Kdiag[ker_baseidx + kidx * kerplanecount].x * t0.x) + (-Kodiag[ker_baseidx + kidx * kerplanecount].x * t0.y) + (Kodiag[ker_baseidx + kidx * kerplanecount].y * t0.z);
				cuSy[idx + sidx_l * planecount] = (-Kodiag[ker_baseidx + kidx * kerplanecount].x * t0.x) + (Kdiag[ker_baseidx + kidx * kerplanecount].y * t0.y) + (-Kodiag[ker_baseidx + kidx * kerplanecount].z * t0.z);
				cuSz[idx + sidx_l * planecount] = (Kodiag[ker_baseidx + kidx * kerplanecount].y * t0.x) + (-Kodiag[ker_baseidx + kidx * kerplanecount].z * t0.y) + (Kdiag[ker_baseidx + kidx * kerplanecount].z * t0.z);

				cuSx[idx + sidx_h * planecount] = (Kdiag[ker_baseidx + kidx * kerplanecount].x * t1.x) + (-Kodiag[ker_baseidx + kidx * kerplanecount].x * t1.y) + (-Kodiag[ker_baseidx + kidx * kerplanecount].y * t1.z);
				cuSy[idx + sidx_h * planecount] = (-Kodiag[ker_baseidx + kidx * kerplanecount].x * t1.x) + (Kdiag[ker_baseidx + kidx * kerplanecount].y * t1.y) + (Kodiag[ker_baseidx + kidx * kerplanecount].z * t1.z);
				cuSz[idx + sidx_h * planecount] = (-Kodiag[ker_baseidx + kidx * kerplanecount].y * t1.x) + (Kodiag[ker_baseidx + kidx * kerplanecount].z * t1.y) + (Kdiag[ker_baseidx + kidx * kerplanecount].z * t1.z);
			}
		}

		//inverse z-axis fft (but without division by N.z). Also only keep first N.z/2 points.

		p = (ldn & 1);

		// n is not a power of 4, need a radix-2 step
		if (p != 0) {

			for (i0 = 0; i0 < N.z; i0 += 2) {

				t0 = x(i0) - x(i0 + 1);
				t1 = x(i0) + x(i0 + 1);
				cuS(i0, t1);
				cuS(i0 + 1, t0);
			}
		}

		N2 = (1 << p);

		//radix-4 stages
		for (p = p + 2; p <= ldn - 2; p += 2) {

			N4 = N2;
			N2 *= 4;

			//Special case j = 0 separated from loop : no multiplications.
			for (int r = 0; r < N.z; r += N2) {

				i1 = r + N4;
				i2 = i1 + N4;
				i3 = i2 + N4;

				t0 = (x(r) + x(i1));
				t1 = (x(r) - x(i1));
				t2 = (x(i2) + x(i3));
				t3 = !(x(i3) - x(i2));

				cuS(r, t0 + t2);
				cuS(i1, t1 - t3);
				cuS(i2, t0 - t2);
				cuS(i3, t1 + t3);
			}

			//Remaining cases from j = 1 upwards
			for (int j = 1; j < N4; j++) {

				for (int r = 0; r < N.z; r += N2) {

					i0 = j + r;
					i1 = i0 + N4;
					i2 = i1 + N4;
					i3 = i2 + N4;

					t0 = (x(i0) + x(i1) * cossin[2 * j * N.z / N2]);
					t1 = (x(i0) - x(i1) * cossin[2 * j * N.z / N2]);
					t2 = (x(i2) * cossin[j * N.z / N2] + x(i3) * cossin[3 * j * N.z / N2]);
					t3 = !(x(i3) * cossin[3 * j * N.z / N2] - x(i2) * cossin[j * N.z / N2]);

					cuS(r, t0 + t2);
					cuS(i1, t1 - t3);
					cuS(i2, t0 - t2);
					cuS(i3, t1 + t3);
				}
			}
		}

		//output radix-4 stage

		N4 = N.z / 4;

		//j = 0, 1, ..., N / 4 - 1

		//j = 0 (no multiplications)
		t0 = (x(0) + x(N4));
		t1 = (x(0) - x(N4));
		t2 = (x(2 * N4) + x(3 * N4));
		t3 = !(x(3 * N4) - x(2 * N4));

		cuReIm3 l = t0 + t2;
		cuReIm3 h = t1 - t3;
		cuS(0, l);
		cuS(N4, h);

		//Remaining cases from j = 1 upwards
		for (int j = 1; j < N4; j++) {

			i0 = j;
			i1 = i0 + N4;
			i2 = i1 + N4;
			i3 = i2 + N4;

			t0 = (x(i0) + x(i1) * cossin[2 * j]);
			t1 = (x(i0) - x(i1) * cossin[2 * j]);
			t2 = (x(i2) * cossin[j] + x(i3) * cossin[3 * j]);
			t3 = !(x(i3) * cossin[3 * j] - x(i2) * cossin[j]);

			cuReIm3 l = t0 + t2;
			cuReIm3 h = t1 - t3;
			cuS(i0, l);
			cuS(i1, h);
		}
	}
}
*/