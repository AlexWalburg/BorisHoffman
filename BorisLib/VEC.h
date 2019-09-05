#pragma once

#include <omp.h>
#include <tuple>

#include "Types.h"
#include "Funcs_Aux.h"
#include "Funcs_Math.h"
#include "Funcs_Vectors.h"
#include "OmpReduction.h"

////////////////////////////////////////////////////////////////////////////////////////////////// VEC<VType>
//
// n-component quantity with 3 dimensions

template <typename VType> class Transfer;

template <typename VType> 
class VEC {

	friend Transfer<VType>;

protected:

	//used for min, max and average reduction : stuck with OMP2.0 currently!
	mutable OmpReduction<VType> reduction;

	//the actual mesh quantity
	std::vector<VType> quantity;

	//mesh transfer object : handled using the MESH TRANSFER methods below. Not saved by ProgramState, so needs to be remade if reloading this VEC.
	Transfer<VType> transfer;

public:

	//dimensions along x, y and z of the quantity
	SZ3 n = SZ3(0);

	//cellsize of structured mesh
	DBL3 h = DBL3(0);

	//rectangle, same units as h. VEC has n number of cells, so n * h gives the rect dimensions. All that is really needed is the rect start coordinates
	Rect rect = Rect();

private:

	//--------------------------------------------HELPER METHODS : VEC_mng.h

	void SetMeshRect(void) { rect.e = rect.s + (h & n); }

	//set new size and map mesh values to new dimension, keeping magnitude (so don't use an average). Return outcome; if failed then no changes made.
	bool mapmesh_newdims(const SZ3& new_n);

	//from current rectangle and h value set n. h may also need to be adjusted since n must be an integer. Resize quantity to new n value : return success or fail. If failed then nothing changed.
	bool set_n_adjust_h(void);

protected:

	//from h_ and rect_ calculate what n value results - but do not make any changes
	SZ3 get_n_from_h_and_rect(const DBL3& h_, const Rect& rect_) const;

	//generic Voronoi diagram generators - need average spacing for cell sites, which are generated using a random number generator (prng). Cells will take on a value generated by the value_generator function.

	//2D
	void GenerateVoronoi2D(double spacing, BorisRand& prng, std::function<VType(void)>& value_generator);
	
	//3D
	void GenerateVoronoi3D(double spacing, BorisRand& prng, std::function<VType(void)>& value_generator);

	//2D with values generated just for the boundaries, with all other cells taking on the base value
	void GenerateVoronoiBoundary2D(double spacing, VType base_value, BorisRand& prng, std::function<VType(void)>& value_generator);

	//3D with values generated just for the boundaries, with all other cells taking on the base value
	void GenerateVoronoiBoundary3D(double spacing, VType base_value, BorisRand& prng, std::function<VType(void)>& value_generator);

public:

	//--------------------------------------------CONSTRUCTORS : VEC_mng.h

	VEC(void);

	VEC(const SZ3& n_);

	VEC(const DBL3& h_, const Rect& rect_);

	VEC(const DBL3& h_, const Rect& rect_, VType value);

	virtual ~VEC() {}

	//--------------------------------------------INDEXING

	//Index using a single combined index (use e.g. when more convenient to use a single for loop to iterate over the quantity's elements)
	VType& operator[](int idx) { return quantity[idx]; }

	//index using a VAL3, integral type (e.g. use with nested loops)
	VType& operator[](const INT3& idx) { return quantity[idx.i + idx.j*n.x + idx.k*n.x*n.y]; }

	//index by position relative to VEC rect
	VType& operator[](const DBL3& rel_pos) { return quantity[int(rel_pos.x / h.x) + int(rel_pos.y / h.y) * n.x + int(rel_pos.z / h.z) * n.x * n.y]; }

	//get the managed std::vector by reference
	std::vector<VType>& get_vector(void) { return quantity; }

	//--------------------------------------------PROPERTY CHECKING : VEC_aux.h

	bool is_not_empty(int index) const { return (quantity[index] != VType()) ; }
	bool is_not_empty(const INT3& ijk) const { return (quantity[ijk.i + ijk.j*n.x + ijk.k*n.x*n.y] != VType()); }
	bool is_not_empty(const DBL3& rel_pos) const { return (quantity[int(rel_pos.x / h.x) + int(rel_pos.y / h.y) * n.x + int(rel_pos.z / h.z) * n.x * n.y] != VType()); }

	bool is_empty(int index) const { return (quantity[index] == VType()); }
	bool is_empty(const INT3& ijk) const { return (quantity[ijk.i + ijk.j*n.x + ijk.k*n.x*n.y] == VType()); }
	bool is_empty(const DBL3& rel_pos) const { return (quantity[int(rel_pos.x / h.x) + int(rel_pos.y / h.y) * n.x + int(rel_pos.z / h.z) * n.x * n.y] == VType()); }

	//check if all cells intersecting the rectangle (absolute coordinates) are empty
	bool is_empty(const Rect& rectangle) const;
	//check if all cells intersecting the rectangle (absolute coordinates) are not empty
	bool is_not_empty(const Rect& rectangle) const;

	//--------------------------------------------ITERATORS

	VType* begin(void) { return &quantity[0]; }
	VType* end(void) { return &quantity[linear_size()]; }
	VType* data(void) { return quantity.data(); }

	//--------------------------------------------SPECIAL DATA ACCESS

	std::vector<VType>& quantity_ref(void) { return quantity; }

	//--------------------------------------------SIZING : VEC_mng.h

	//all sizing methods (apart from clear) return true (success) or false (could not resize). If failed then previous settings are maintained.

	//change to new number of cells : keep h and rect.s the same but adjust rect.e. Also map values to new size.
	bool resize(const SZ3& new_n);
	//set rect and h; n is obtained from them and h also may be adjusted. Also map values to new size.
	bool resize(const DBL3& new_h, const Rect& new_rect);

	//works like resize but sets given value also
	bool assign(const SZ3& new_n, VType value);
	//works like resize but sets given value also
	bool assign(const DBL3& new_h, const Rect& new_rect, VType value);

	//set everything to zero but h - note, using shrink_to_fit to reduce capacity to zero (the std::vector clear method does not do this)
	//if you want to set the size of this VEC to zero you should use VEC::clear, not resize the size to zero. The reason for this explained below:
	//For VECs that do not go out of scope but have previously had a large size allocated we might be blocked from resizing this or another VEC for no good reason. 
	//This is because VECs are not allowed to resize beyond the available physical memory - virtual memory is useless for what VECs are intended to do.
	void clear(void);

	void shrink_to_fit(void) { quantity.shrink_to_fit(); }

	//--------------------------------------------MULTIPLE ENTRIES SETTERS : VEC_oper.h

	//set value in box
	void setbox(const Box& box, VType value = VType());

	//set value in rectangle (i.e. in cells intersecting the rectangle), where the rectangle is relative to this VEC's rectangle.
	void setrect(const Rect& rectangle, VType value = VType());

	//set value in all cells
	void set(VType value = VType());

	//re-normalize all non-zero values to have the new magnitude (multiply by new_norm and divide by current magnitude)
	template <typename PType = decltype(GetMagnitude(std::declval<VType>()))>
	void renormalize(PType new_norm);

	//copy values from copy_this but keep current dimensions - if necessary map values from copy_this to local dimensions
	void copy_values(const VEC<VType>& copy_this);

	//--------------------------------------------VEC GENERATORS : VEC_generate.h, VEC_Voronoi.h

	//most of these are specialised for double only

	//generate custom values from grayscale bitmap : black = 0, white = 1. Apply scaling and offset also.
	//bitmap size must match new_n.x * new_n.y
	bool generate_custom_2D(SZ3 new_n, Rect new_rect, double offset, double scale, std::vector<BYTE>& bitmap) { return true; }

	//similar to generate_linear except new dimensions not set
	void set_linear(DBL3 position1, VType value1, DBL3 position2, VType value2) {}

	//linear : set VEC dimensions and use interpolation to set values in this VEC based on projected distance between position1 and position2 and given fixed end values.
	bool generate_linear(DBL3 new_h, Rect new_rect, DBL3 position1, VType value1, DBL3 position2, VType value2) { return true; }

	//random: set VEC dimensions and generate random values in given range (prng instantiated with given seed)
	bool generate_random(DBL3 new_h, Rect new_rect, DBL2 range, unsigned seed);

	//defects: set VEC dimensions (force 2D in xy plane) and generate circular defects with a tanh radial profile with values in the given range, 
	//diameter range and average spacing (prng instantiated with given seed). The defect positioning is random. 
	bool generate_defects(DBL3 new_h, Rect new_rect, DBL2 range, VType base_value, DBL2 diameter_range, double spacing, unsigned seed) { return true; }

	//faults: set VEC dimensions (force 2D in xy plane) and generate line faults in the given range length, orientation length (degrees azimuthal) and average spacing (prng instantiated with given seed).
	bool generate_faults(DBL3 new_h, Rect new_rect, DBL2 range, VType base_value, DBL2 length_range, DBL2 orientation_range, double spacing, unsigned seed) { return true; }

	//jagged: set VEC dimensions (force 2D in xy plane) and generate random values in given range (prng instantiated with given seed) at a given spacing. 
	//In between these random values use bi-linear interpolation. The random values are spaced in the xy plane at equal distances along x or y using the spacing value (same units as the VEC rect)
	bool generate_jagged(DBL3 new_h, Rect new_rect, DBL2 range, double spacing, unsigned seed) { return true; }

	//voronoi 2D: set VEC dimensions (force 2D in xy plane) and generate random values in the given range with each value fixed in a voronoi cell, and average spacing (prng instantiated with given seed).
	bool generate_voronoi2d(DBL3 new_h, Rect new_rect, DBL2 range, double spacing, unsigned seed);

	//voronoi 3D: set VEC dimensions and generate random values in the given range with each value fixed in a voronoi cell, and average spacing (prng instantiated with given seed).
	bool generate_voronoi3d(DBL3 new_h, Rect new_rect, DBL2 range, double spacing, unsigned seed);

	//voronoi boundary 2D: set VEC dimensions (force 2D in xy plane) and generate voronoi 2d tessellation with average spacing. Set coefficient values randomly in the given range only at the Voronoi cell boundaries (prng instantiated with given seed).
	bool generate_voronoiboundary2d(DBL3 new_h, Rect new_rect, DBL2 range, VType base_value, double spacing, int seed);

	//voronoi boundary 3D: set VEC dimensions and generate voronoi 3d tessellation with average spacing. Set coefficient values randomly in the given range only at the Voronoi cell boundaries (prng instantiated with given seed).
	bool generate_voronoiboundary3d(DBL3 new_h, Rect new_rect, DBL2 range, VType base_value, double spacing, int seed);

	//voronoi rotations 2D: set VEC dimensions (force 2D in xy plane) and generate voronoi 2d tessellation with average spacing. This method is applicable only to DBL3 PType, where a rotation operation is applied, fixed in each Voronoi cell. 
	//The rotation uses the values for polar (theta) and azimuthal (phi) angles specified in given ranges in degrees. prng instantiated with given seed.
	//specialised for DBL3 only : applies rotation to vector
	bool generate_voronoirotation2d(DBL3 new_h, Rect new_rect, DBL2 theta, DBL2 phi, double spacing, int seed) { return true; }

	//voronoi rotations 3D: set VEC dimensions and generate voronoi 3d tessellation with average spacing. This method is applicable only to DBL3 PType, where a rotation operation is applied, fixed in each Voronoi cell. 
	//The rotation uses the values for polar (theta) and azimuthal (phi) angles specified in given ranges in degrees. prng instantiated with given seed.
	//specialised for DBL3 only : applies rotation to vector
	bool generate_voronoirotation3d(DBL3 new_h, Rect new_rect, DBL2 theta, DBL2 phi, double spacing, int seed) { return true; }

	//--------------------------------------------GETTERS : VEC_aux.h

	SZ3 size(void) const { return n; }
	size_t linear_size(void) const { return n.dim(); }

	//from cell index return cell center coordinates (relative to start of rectangle)
	DBL3 cellidx_to_position(int idx) const { DBL3 ijk_pos = DBL3((idx % n.x) + 0.5, ((idx / n.x) % n.y) + 0.5, (idx / (n.x*n.y)) + 0.5); return (h & ijk_pos); }
	
	//from cell index return cell center coordinates (relative to start of rectangle)
	DBL3 cellidx_to_position(const INT3& ijk) const { DBL3 ijk_pos = DBL3(ijk.i + 0.5, ijk.j + 0.5, ijk.k + 0.5); return (h & ijk_pos); }

	//return cell index from relative position : the inverse of cellidx_to_position
	int position_to_cellidx(const DBL3& position) const { return floor_epsilon(position.x / h.x) + floor_epsilon(position.y / h.y) * n.x + floor_epsilon(position.z / h.z) * n.x*n.y; }

	//get index of cell which contains position (absolute value, not relative to start of rectangle), capped to mesh size
	INT3 cellidx_from_position(const DBL3& absolute_position) const;

	//get cell rectangle (absolute values, not relative to start of mesh rectangle) for cell with index ijk
	Rect get_cellrect(const INT3& ijk) const { return Rect(rect.s + (h & ijk), rect.s + (h & ijk) + h); }
	
	//get_cellrect using single index.
	Rect get_cellrect(int idx) const { INT3 ijk = INT3((idx % n.x), (idx / n.x) % n.y, idx / (n.x*n.y)); return Rect(rect.s + (h & ijk), rect.s + (h & ijk) + h); }

	//extract box of cells intersecting with the given rectangle (rectangle is in absolute coordinates). Cells in box : from and including start, up to but not including end; Limited to VEC sizes.
	Box box_from_rect_max(const Rect& rectangle) const;
	
	//extract box of cells completely included in the given rectangle (rectangle is in absolute coordinates).
	Box box_from_rect_min(const Rect& rectangle) const;

	//count cells which don't have a null value set : i.e. non-empty.
	int get_nonempty_cells(void) const;

	//--------------------------------------------TRANSPOSITION : VEC_trans.h

	//transpose values from this VEC to output VEC

	//x -> y
	template <typename SType>
	void transpose_xy(VEC<SType>& out);

	//x -> z
	//transpose x and z values from this VEC to output VEC
	template <typename SType>
	void transpose_xz(VEC<SType>& out);
	
	//y -> z
	template <typename SType>
	void transpose_yz(VEC<SType>& out);

	//x, y, z -> z, x, y
	template <typename SType>
	void transpose_cycleup(VEC<SType>& out);

	//x, y, z -> y, z, x
	template <typename SType>
	void transpose_cycledn(VEC<SType>& out);

	//--------------------------------------------MATRIX OPERATIONS : VEC_matops.h

	//multiply xy planes of lvec and rvec considered as 2D matrices and place result in this VEC. Require lvec.n.x = rvec.n.y and lvec.n.z = rvec.n.z. Output matrix (this) sized as required.
	//specialised for double only
	void matrix_mul(VEC<double>& lvec, VEC<double>& rvec) {}

	//multiply matrix by floating point constant
	void matrix_mul(double constant);

	//multiply diagonal values in each xy plane of this VEC (considered as a matrix) by value.
	//If not square in the xy plane the "diagonal" starts at (0,0) and has min(n.x, n.y) points
	void matrix_muldiag(double value);

	//add matadd into this matrix point by point - sizes must match
	void matrix_add(VEC<VType>& matadd);

	//add lvec and rvec (sizes must match) point by point, setting output in this matrix
	void matrix_add(VEC<VType>& lvec, VEC<VType>& rvec);

	//subtract matadd from this matrix point by point - sizes must match
	void matrix_sub(VEC<VType>& matadd);

	//subtract rvec from lvec (sizes must match) point by point, setting output in this matrix
	void matrix_sub(VEC<VType>& lvec, VEC<VType>& rvec);

	//Invert each plane of this VEC considered as a matrix (must be square in xy plane) and return determinant of first matrix (first xy plane) - using algorithm from : A. Farooq, K. Hamid, "An Efficient and Simple Algorithm for Matrix Inversion" IJTD, 1, 20 (2010)
	//specialised for double only
	double matrix_inverse(void) {}

	//extract values from given xy plane (plane ranges from 0 to n.z - 1) diagonal into a std::vector
	//If not square in the xy plane the "diagonal" starts at (0,0) and has min(n.x, n.y) points
	void matrix_getdiagonal(std::vector<VType>& diagonal, int plane = 0);

	//--------------------------------------------OPERATIONS : VEC_oper.h

	//average in a box (which should be contained in the VEC dimensions)
	VType average(const Box& box) const;
	//average over given rectangle (relative to this VEC's rect)
	VType average(const Rect& rectangle = Rect()) const;

	//parallel processing versions - do not call from parallel code!!!
	VType average_omp(const Box& box) const;
	VType average_omp(const Rect& rectangle = Rect()) const;

	//even though VEC doesn't hold a shape we might want to obtain averages by excluding zero-value cells
	VType average_nonempty(const Box& box) const;
	VType average_nonempty(const Rect& rectangle = Rect()) const;

	//parallel processing versions - do not call from parallel code!!!
	VType average_nonempty_omp(const Box& box) const;
	VType average_nonempty_omp(const Rect& rectangle = Rect()) const;

	//smoother : obtain a weighted average value at coord, over a stencil of given size. All dimension units are same as h and rect. Include values from all cells which intersect the stencil.
	///the coord is taken as the centre value and is relative to the mesh rectangle start coordinate which might not be 0,0,0 : i.e. not an absolute value.
	//the weights vary linearly with distance from coord
	VType weighted_average(const DBL3& coord, const DBL3& stencil) const;
	
	//weighted average in given rectangle (absolute coordinates). weighted_average with coord and stencil is slightly faster.
	VType weighted_average(const Rect& rectangle) const;

	//ijk is the cell index in a mesh with cellsize cs and same rect as this VEC; if cs is same as h then just read the value at ijk - much faster! If not then get the usual weighted average.
	VType weighted_average(const INT3& ijk, const DBL3& cs) const;

	//--------------------------------------------MESH TRANSFER : VEC_MeshTransfer.h

	//set-up mesh transfers, ready to use - return false if failed (not enough memory)
	bool Initialize_MeshTransfer(const std::vector< VEC<VType>* >& mesh_in, const std::vector< VEC<VType>* >& mesh_out, int correction_type) { return transfer.initialize_transfer(mesh_in, mesh_out, correction_type); }

	//do the actual transfer of values to and from this mesh using these
	void transfer_in(void) { transfer.transfer_from_external_meshes(); }
	
	void transfer_out(bool setOutput = false) { transfer.transfer_to_external_meshes(setOutput); }

	//flattened in and out transfer sizes (i.e. total number of cell contributions
	size_t size_transfer_in(void) { return transfer.size_transfer_in(); }
	size_t size_transfer_out(void) { return transfer.size_transfer_out(); }

	//this is used to pass transfer information to a cuVEC for copying to gpu memory : for gpu computations we use "flattened" transfers so it can be parallelized better
	//return type: vector of transfers, where INT3 contains : i - input mesh index, j - input mesh cell index, k - super-mesh cell index. the double entry is the weight for the value contribution
	std::vector<std::pair<INT3, double>> get_flattened_transfer_in_info(void) { return transfer.get_flattened_transfer_in_info(); }

	//this is used to pass transfer information to a cuVEC for copying to gpu memory : for gpu computations we use "flattened" transfers so it can be parallelized better
	//return type: vector of transfers, where INT3 contains : i - output mesh index, j - output mesh cell index, k - super-mesh cell index. the double entry is the weight for the value contribution
	std::vector<std::pair<INT3, double>> get_flattened_transfer_out_info(void) { return transfer.get_flattened_transfer_out_info(); }
};