begin genesis

program
	value stencil_radius sample stencil_radius_dist
	value time_passes sample time_dist
	value dims sample dim_dist
	value stencil_size sample stencil_size_dist
	value negative_width = -1*stencil_radius
	value stencil_type sample stencil_type_dist
	distribution offset_dist = {negative_width:stencil_radius}
end

/// Determine the relevant constants
feature constants
	#define TIME_PASSES (time_passes)
	#define DIMS (dims)
	genif dims == 3
		#define Z_SIZE (256)
	end
	genif dims != 3
		#define Z_SIZE (1)
	end
	genif dims >= 2
		#define Y_SIZE (256)
	end
	genif dims == 1
		#define Y_SIZE (1)
	end
	#define X_SIZE (256)
	#define STENCIL_RADIUS (stencil_radius)
end

feature singleline(1) local_input_macro
	#define local_input(
	genif dims == 3
		z_index,
	end
	genif dims >= 2
		y_index,
	end
	x_index) (_local_input[
	genif dims == 3
		((z_index)*(B3_Y+2*stencil_radius) + (y_index)) * (B3_X+2*stencil_radius+LOCAL_PAD) + 
	end
	genif dims == 2
		(y_index) * (B3_X+2*stencil_radius+LOCAL_PAD) +
	end
	(x_index)])
end

feature singleline(1) local_output_macro
	#define local_output(
	genif dims == 3
		z_index,
	end
	genif dims >= 2
		y_index,
	end
	x_index) (_local_output[
	genif dims == 3
		((z_index % (B3_Z))*(B3_Y) + (y_index)) * (B3_X+LOCAL_PAD) + 
	end
	genif dims == 2
		(y_index) * (B3_X+2*stencil_radius+LOCAL_PAD) +
	end
	(x_index)])
end

feature main_line (volatile)
	__kernel void stencil(__global 
	#if (VX == 1)
	double
	#elif (VX == 2)
	double2
	#elif (VX == 4)
	double4
	#elif (VX == 8)
	double8
	#elif (VX == 16)
	double16
	#endif
	(*input)
	genif dims == 3
		[Y_SIZE]
	end
	genif dims >= 2
		[(X_SIZE+GLOBAL_PAD)/VX]
	end
	, volatile __global 
	#if (VX == 1)
	double
	#elif (VX == 2)
	double2
	#elif (VX == 4)
	double4
	#elif (VX == 8)
	double8
	#elif (VX == 16)
	double16
	#endif
	(*output)
	genif dims == 3
		[Y_SIZE]
	end
	genif dims >= 2
		[(X_SIZE+GLOBAL_PAD)/VX]
	end
	, __local double *_local_input
	, __local double *_local_output
	)
end

/// Gather the appropriate ids depending on the dimensionality of this kernel
feature get_ids
	int x_gid = get_global_id(0);
	int x_lid = get_local_id(0);
	genif dims >= 2
		int y_gid = get_global_id(1);
		int y_lid = get_local_id(1);
	end
	genif dims == 3
		int z_gid = get_global_id(2);
		int z_lid = get_local_id(2);
	end
end

feature get_starting_point
	genif dims == 3
		int z_base = z_gid / WZ * B3_Z;
		int z_start = z_base + z_lid * B1_Z;
	end
	genif dims >= 2
		int y_base = y_gid / WY * B3_Y;
		int y_start = y_base + y_lid * B1_Y;
	end
	int x_base = x_gid / WX * B3_X;
	int x_start = x_base + x_lid * B1_X;
end

feature initial_load_to_local_memory
	#if (USE_LOCAL_MEMORY == true)
	// We don't use the normal blocking scheme here
	// Instead we load into local memory as much data as specified by B3_X, B3_Y, and LOCAL_MEM_SLICES in an efficient manner
	{
		get_local_start_points(z_base)
		value loops=0
		genif dims == 3
			// No need for a preprocessor if here because this loop is needed even if B3_Z = 1
			// We have the flexibility to load only a portion of the data accessed by the thread block so that we can use local memory even when working with thread blocks that use a portion of the input too large to fit into local memory all at once
			int z;
			for (z = local_z_start - stencil_radius; z < z_base + stencil_radius + B2_Z*LOCAL_MEM_SLICES; z+=WZ)
			{
				int local_z = (z + stencil_radius) % (B2_Z*LOCAL_MEM_SLICES+2*stencil_radius);
				int safe_z = z < 0 ? 0 : z > Z_SIZE-1 ? Z_SIZE-1 : z;
			genmath loops=loops+1
		end
		load_slice_to_local_memory
		close_brackets(loops)
	}
	barrier(CLK_LOCAL_MEM_FENCE);
	#endif
end

feature load_to_local_memory
	genif dims==3
		#if (USE_LOCAL_MEMORY == true)
		if (z_counter % LOCAL_MEM_SLICES == 0 && z_counter != 0)
		{
			int z_block_base = z_block - B1_Z * z_lid;
			get_local_start_points(z_block_base)
			int z;
			for (z = local_z_start + stencil_radius; z < z_block_base + stencil_radius + B2_Z*LOCAL_MEM_SLICES; z+=WZ)
			{
				int local_z = (z + stencil_radius) % (B2_Z*LOCAL_MEM_SLICES+2*stencil_radius);
				int safe_z = z < 0 ? 0 : z > Z_SIZE-1 ? Z_SIZE-1 : z;
				load_slice_to_local_memory
			}
		}
		barrier(CLK_LOCAL_MEM_FENCE);
		#endif
	end
end

feature load_slice_to_local_memory
	value loops=0
	genif dims >= 2
		// No need for a preprocessor if here because this loop is needed even if B3_Y = 1
		int y;
		for (int local_y = y_lid, y = local_y_start - stencil_radius; y < y_base + stencil_radius + B3_Y; local_y+=WY, y+=WY)
		{
		int safe_y = y < 0 ? 0 : y > Y_SIZE-1 ? Y_SIZE-1 : y;
		genmath loops=loops + 1
	end
	{
		int x;
		#if (B3_X == 1)
		x = local_x_start;
		#else
		for (int local_x = x_lid + stencil_radius, x = local_x_start; x < x_base + B3_X; local_x+=WX, x+=WX)
		#endif
		{
			int safe_x = x;
			local_load
		}
	}
	// Load the x boundary
	// This is handled differently than the Y and Z boundaries to preserve memory coalescing
	for (int boundary_counter = x_lid; boundary_counter < stencil_radius * 2; boundary_counter+=WX)
	{
		int local_x, x;
		if (boundary_counter < stencil_radius)
		{
			local_x = boundary_counter;
			x = x_base - stencil_radius + boundary_counter;
		}
		else
		{
			local_x = B3_X + boundary_counter;
			x = x_base + B3_X - stencil_radius + boundary_counter;
		}
		int safe_x = x < 0 ? 0 : x > X_SIZE-1 ? X_SIZE-1 : x;
		local_load
	}
	close_brackets(loops)
end

feature get_local_start_points(z_base)
	genif dims == 3
		int local_z_start = z_base + z_lid;
	end
	genif dims >= 2
		int local_y_start = y_base + y_lid;
	end
	int local_x_start = x_base + x_lid;
end

feature singleline(1) local_load
	local_input(
	genif dims == 3
		local_z,
	end
	genif dims >= 2
		local_y,
	end
	local_x) = input
	genif dims == 3
		[safe_z]
	end
	genif dims >= 2
		[safe_y]
	end
	[safe_x];
end

feature block_loops
	value loops=0
	genif dims == 3
		int z_counter = 0;
		#if (B3_Z == B2_Z)
		int z_block = z_start;
		#else
		for (int z_block = z_start; z_block < z_base + B3_Z; z_block+=B2_Z, ++z_counter)
		#endif
		{
		genmath loops=loops+1
	end
	load_to_local_memory	
	genif dims >= 2
		#if (B3_Y == B2_Y)
		int y_block = y_start;
		#else
		for (int y_block = y_start; y_block < y_base + B3_Y; y_block+=B2_Y)
		#endif
		{
		genmath loops=loops + 1
	end
	#if (B3_X == B2_X)
	int x_block = x_start;
	#else
	for (int x_block = x_start; x_block < x_base + B3_X; x_block+=B2_X)
	#endif
	{
	genmath loops=loops + 1
		genif dims == 3
			int z = z_block;
			#if (B1_Z != 1)
			#pragma unroll
			for (int dummy_z = 0; dummy_z < B1_Z; ++dummy_z, ++z)
			#endif
			{
			genmath loops=loops + 1
		end
		genif dims >= 2
			int y = y_block;
			#if (B1_Y != 1)
			#pragma unroll
			for (int dummy_y = 0; dummy_y < B1_Y; ++dummy_y, ++y)
			#endif
			{
			genmath loops=loops + 1
		end
		int x = x_block;
		#if (B1_X != 1)
		#pragma unroll
		#if (VX == 1)
		for (int dummy_x = 0; dummy_x < B1_X; ++dummy_x, ++x)
		#else
		for (int dummy_x = 0; dummy_x < B1_X; dummy_x+=VX, x+=VX)
		#endif
		#endif
		{
		genmath loops=loops + 1
	#if (VX == 1)
	double temp = 0;
	#elif (VX == 2)
	double2 temp = (double2)(0.0, 0.0);
	double2 temp0, temp1, composite;
	#elif (VX == 4)
	double4 temp = (double4)(0.0, 0.0, 0.0, 0.0);
	double4 temp0, temp1, composite;
	#elif (VX == 8)
	double8 temp = (double8)(0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0);
	double8 temp0, temp1, composite;
	#elif (VX == 16)
	double16 temp = (double16)(0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0);
	double16 temp0, temp1, composite;
	#endif

	boundary_if
	genmath loops=loops + 1
	reads
	write
	close_brackets(loops)
end

feature boundary_if
	int lower_x_bound = stencil_radius / VX * VX;
	if (x >= lower_x_bound && x < X_SIZE - stencil_radius 
	genif dims >= 2
		&& y >= stencil_radius && y < Y_SIZE - stencil_radius
	end
	genif dims == 3
		&& z >= stencil_radius && z < Z_SIZE - stencil_radius
	end
	)
	{
end

feature close_brackets (num_brackets)
	genloop i:1:num_brackets
		}
	end
end

feature reads
	genif stencil_type==0
		genloop i:1:stencil_size
			value z_offset sample offset_dist
			value y_offset sample offset_dist
			value x_offset sample offset_dist
			value weight sample weight_dist
			// The addition and the second modulo ensure that this is positive (they have no effect if the result of the first modulo is already positive)
			#define alignment_offset_${i} (((x_offset % VX) + VX) % VX)
			#if (USE_LOCAL_MEMORY == true)
			read(read_local,z_offset,y_offset,x_offset,weight,i)
			#else
			read(read_global,z_offset,y_offset,x_offset,weight,i)
			#endif
		end
	genelsif stencil_type==1
		value id = 0
		distribution prism_half_length_dist = {0:stencil_radius}
		value z_min sample prism_half_length_dist
		value z_max sample prism_half_length_dist
		value y_min sample prism_half_length_dist
		value y_max sample prism_half_length_dist
		value x_min sample prism_half_length_dist
		value x_max sample prism_half_length_dist
		genloop i:-1*z_min:z_max
			genloop j:-1*y_min:y_max
				genloop k:-1*x_min:x_max
					value weight_cube sample weight_dist
					genmath id = id + 1
					// The addition and the second modulo ensure that this is positive (they have no effect if the result of the first modulo is already positive)
					#define alignment_offset_${id} (((k % VX) + VX) % VX)
					#if (USE_LOCAL_MEMORY == true)
					read(read_local,i,j,k,weight_cube,id)
					#else
					read(read_global,i,j,k,weight_cube,id)
					#endif
				end
			end
		end
	end
end

feature read (read_type,z_offset,y_offset,x_offset,weight,id)
	#if (VX == 1)
	temp += weight * read_type(z+z_offset,y+y_offset,x+x_offset)
	#elif (x_offset % VX == 0)
	temp += weight * read_type(z+z_offset,y+y_offset,(x+x_offset)/VX)
	#else
	genif (x_offset < 0)
		if (x + x_offset < 0)
		{
			#if (VX == 1)
			temp0 = 0;
			#elif (VX == 2)
			temp0 = (double2)(0.0, 0.0);
			#elif (VX == 4)
			temp0 = (double4)(0.0, 0.0, 0.0, 0.0);
			#elif (VX == 8)
			temp0 = (double8)(0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0);
			#elif (VX == 16)
			temp0 = (double16)(0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0);
			#endif
		}
		else
	end
	temp0 = read_type(z+z_offset,y+y_offset,((x+x_offset)/VX));
	genif (x_offset > 0)
		if (x + x_offset + VX > X_SIZE)
		{
			#if (VX == 1)
			temp1 = 0;
			#elif (VX == 2)
			temp1 = (double2)(0.0, 0.0);
			#elif (VX == 4)
			temp1 = (double4)(0.0, 0.0, 0.0, 0.0);
			#elif (VX == 8)
			temp1 = (double8)(0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0);
			#elif (VX == 16)
			temp1 = (double16)(0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0);
			#endif
		}
		else
	end
	temp1 = read_type(z+z_offset,y+y_offset,((((x+x_offset)&(~(VX-1)))/VX)+1));
//  The above code is basically doing the following except for when x+x_offset < 0
//	temp1 = read_type(z+z_offset,y+y_offset,(((x+x_offset)/VX)+1));
	value max_vx = 16
	genloop i:0:max_vx-1
		value i_symbol = i
		genif i == 10
			genmath i_symbol = a
		end
		genif i == 11
			genmath i_symbol = b
		end
		genif i == 12
			genmath i_symbol = c
		end
		genif i == 13
			genmath i_symbol = d
		end
		genif i == 14
			genmath i_symbol = e
		end
		genif i == 15
			genmath i_symbol = f
		end
		#if (i < VX)
		#if (i < VX - alignment_offset_${id})
		value j_symbol = -1
		genloop j:1:max_vx-1
			genmath j_symbol = j
			genif j == 10
				genmath j_symbol = a
			end
			genif j == 11
				genmath j_symbol = b
			end
			genif j == 12
				genmath j_symbol = c
			end
			genif j == 13
				genmath j_symbol = d
			end
			genif j == 14
				genmath j_symbol = e
			end
			genif j == 15
				genmath j_symbol = f
			end
			#if (alignment_offset_${id}+i == j)
			composite.s${i_symbol} = temp0.s${j_symbol};
			#endif
		end
		#else
		genloop j:0:max_vx-2
			genmath j_symbol = j
			genif j == 10
				genmath j_symbol = a
			end
			genif j == 11
				genmath j_symbol = b
			end
			genif j == 12
				genmath j_symbol = c
			end
			genif j == 13
				genmath j_symbol = d
			end
			genif j == 14
				genmath j_symbol = e
			end
			genif j == 15
				genmath j_symbol = f
			end
			#if (i-VX+alignment_offset_${id} == j)
			composite.s${i_symbol} = temp1.s${j_symbol};
			#endif
		end
		#endif
		#endif
	end
	temp += weight * composite;
	#endif
end

/// Read a value at an arbitrary offset from the center point and multiply it by an arbitrary weight
feature singleline(1) read_global (z,y,x)
	input
	genif dims == 3
		[z]
	end
	genif dims >= 2
		[y]
	end
	[x];
end

/// Same as above but read from local memory
feature singleline(1) read_local (z,y,x)
	local_input(
	genif dims == 3
		(z+stencil_radius) % (B2_Z*LOCAL_MEM_SLICES+2*stencil_radius),
	end
	genif dims >= 2
		y-y_base+stencil_radius,
	end
	x-x_base+stencil_radius);
end

/// Sum the temp variables and write the result to the output array
feature write
	value output_array=0
//	genloop i:1:2
//		genif i == 1
//			genmath output_array=local_output
//			#if (WRITE_OUTPUT_TO_LOCAL)
//		genelse
			genmath output_array=output
//			#else
//		end

		genif dims == 1
			#if (VX == 1)
			output_array[x] = 
			#else
			output_array[x/VX] = 
			#endif
		end
		genif dims == 2
			#if (VX == 1)
			output_array[y][x] = 
			#else
			output_array[y][x/VX] = 
			#endif
		end
		genif dims == 3
			#if (VX == 1)
			output_array[z][y][x] = 
			#else
			output_array[z][y][x/VX] = 
			#endif
		end
		temp;
//	end
//	#endif
end

generate 1 with
	time_dist = {1}
	dim_dist = {3}
	stencil_size_dist = {1:10}
	stencil_radius_dist = {1:10}
	weight_dist = {1:10}
	stencil_type_dist = {0}
end
end genesis

#pragma OPENCL EXTENSION cl_khr_fp64 : enable

#include "parameters.h"

constants

local_input_macro
local_output_macro

// For now B4 is as large as the entire data space
// So there are only 3 levels of blocking (i.e. 4 conceptual loop clusters)
// Since 2 of these conceptual loop clusters (the loops that iterate by B1 and by B3) are captured by the OpenCL programming model, only 2 loop clusters appear here (the loops that iterate by 1 and by B2)
// If we were considering the 5th loop cluster we'd have a 3rd loop cluster here
#if (VOLATILE_OUTPUT)
main_line(volatile)
#else
main_line( )
#endif
{
	get_ids
	
	get_starting_point
	
	initial_load_to_local_memory
	block_loops	
}
