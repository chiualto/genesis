begin genesis
	global
	end
	
	program
	
		value numvars sample numvardist
		
		varlist temp[${numvars}] type(float) init(0)
		varlist canbedefined from temp
		varlist definednotused from temp
		
		feature storedepochs process epochs
		
		value lifactor enumerate lidist report(1)
		value volatilefactor enumerate vdist
		value unrollfactor enumerate ufdist report(1)
		

	end

	feature computation 
		variable source1,source2,source3 from temp
		add source1, source2, source3 to canbedefined
		remove source1, source2, source3 from definednotused
		variable dest from canbedefined
		add dest to temp
		add dest to definednotused
		remove dest from canbedefined
		${dest} = ${source1} * ${source2} + ${source3};
	end

	feature shrinkingcomp 
		variable source1,source2,source3 from definednotused
		add source1, source2, source3 to canbedefined
		remove source1, source2, source3 from definednotused
		variable dest from canbedefined
		add dest to temp
		add dest to definednotused
		remove dest from canbedefined
		${dest} = ${source1} * ${source2} + ${source3};
	end

	feature readaccess
		variable varout from canbedefined
		value swapiter,swapiter2 sample swapiterdist noreplacement(1) report(1)
		value offset sample dist1 report(1)
		genif ${offset}==1
			c01 = ${swapiter} - 1;
			if (c01 < 0) c01 = 0;
			c02 = ${swapiter2} - 1;
			if (c02 < 0) c02 = 0;
			varout = arr_in[c01 * n + c02];
		end
		genif ${offset}==2
			c01 = ${swapiter} - 1;
			if (c01 < 0) c01 = 0;
			varout = arr_in[c01 * n + ${swapiter2}];
		end
		genif ${offset}==3
			c01 = ${swapiter} - 1;
			if (c01 < 0) c01 = 0;
			c02 = ${swapiter2} + 1;
			if (c02 >= n) c01 = n - 1;
			varout = arr_in[c01 * n + c02];
		end
		genif ${offset}==4
			c02 = ${swapiter2} - 1;
			if (c02 < 0) c02 = 0;
			varout = arr_in[${swapiter} * n + c02];
		end
		genif ${offset}==5
			varout = arr_in[${swapiter} * n + ${swapiter2}];
		end
		genif ${offset}==6
			c02 = ${swapiter} + 1;
			if (c02 >= n) c02 = n - 1;
			varout = arr_in[${swapiter} * n + c02];
		end
		genif ${offset}==7
			c01 = ${swapiter} + 1;
			if (c01 >= n) c01 = n - 1;
			c02 = ${swapiter2} - 1;
			if (c02 < 0) c02 = 0;
			varout = arr_in[c01 * n + c02];
		end
		genif ${offset}==8
			c01 = ${swapiter} + 1;
			if (c01 >= n) c01 = n - 1;
			varout = arr_in[c01 * n + ${swapiter2}];
		end
		genif ${offset}==9
			c01 = ${swapiter} + 1;
			if (c01 >= n) c01 = n - 1;
			c02 = ${swapiter2} + 1;
			if (c02 >= n) c01 = n - 1;
			varout = arr_in[c01 * n + c02];
		end
		add varout to temp
		add varout to definednotused
		remove varout from canbedefined
	end

	feature writaccess
		variable final from definednotused
		arr_out[i * n + j] = ${final};
	end

	feature readpoch
		value numcompsread sample compdist report(1)
		${computation[${numcompsread}]}
		${readaccess}
	end

	feature writpoch
		value numcompswrite sample compdist report(1)
		genloop ${definednotused}!=1
			${shrinkingcomp}
		end
		${writaccess}
	end

	feature maybevolatile
		genif ${volatilefactor}==0
			__volatile 
		end
	end

	feature functionheader
		__kernel void kernel_li0_c${volatilefactor}_u${unrollfactor}(int n, __global ${maybevolatile} float * arr_in, __global ${maybevolatile} float * arr_out)
	end

	feature epochs
		value numepochs sample epochdist report(1)
		value firstcomp sample vdist
		remove all from temp
		${readaccess}
		genif ${firstcomp}==1
			${computation}
		end
		${readaccess}
		${readpoch[${numepochs}]}
		${writpoch}
	end

	feature loopbody
		genloop unrolling:1:${unrollfactor}
			${storedepochs}
			genif ${unrollfactor}!=${unrolling}
				genif ${lifactor}==0
					j = j + j_step;
				end
				genif ${lifactor}==1
					i = i + i_step;
				end
			end
		end
	end

	feature loopinterchange
		genif ${lifactor}==0
			int i_init = block_start + get_local_id(1) * (1);
			int i_past_end = block_start + tblk_stride;
			int i_step = get_local_size(1) * (1);
			for (int i = i_init; i < i_past_end; i += i_step)
			{
				tblk_stride = ((n) - (0)) / get_num_groups(0);
				block_start = (0) + get_group_id(0) * tblk_stride;
				int j_init = block_start + get_local_id(0) * (1);
				int j_past_end = block_start + tblk_stride;
				int j_step = get_local_size(0) * (1);
				for (int j = j_init; j < j_past_end; j += j_step)
				{
		end
		genif ${lifactor}==1
			int j_init = block_start + get_local_id(1) * (1);
			int j_past_end = block_start + tblk_stride;
			int j_step = get_local_size(1) * (1);
			for (int j = j_init; j < j_past_end; j += j_step)
			{
				tblk_stride = ((n) - (0)) / get_num_groups(0);
				block_start = (0) + get_group_id(0) * tblk_stride;
				int i_init = block_start + get_local_id(0) * (1);
				int i_past_end = block_start + tblk_stride;
				int i_step = get_local_size(0) * (1);
				for (int i = i_init; i < i_past_end; i += i_step)
				{
		end
	end

	generate 1 notouch with dist1 = {1:9},numvardist = {10:20},epochdist = {1:8},compdist = {1:50},swapiterdist = {i;j},ufdist = {1}, lidist = {0;1}, vdist = {0;1}
end genesis



${functionheader}
{
	int c01 = 0;
    int c02 = 0;
    int tblk_stride = 0;
    int block_start = 0;
    tblk_stride = ((n) - (0)) / get_num_groups(1);
    block_start = (0) + get_group_id(1) * tblk_stride;
    ${loopinterchange}
			${loopbody}
        }
	}
 
}
