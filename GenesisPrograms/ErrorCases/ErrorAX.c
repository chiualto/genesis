begin genesis

feature test0
	TEST0 - should output CCC RRR
	value zero sample dist0
	genif ${zero}==0
		CCC
	genelse
		DDD
	end
	RRR
end

feature test1
	TEST1 - should output DDD RRR
	value one sample dist1
	genif ${one}==0
		CCC
	genelse
		DDD
	end
	RRR
end

feature test2
	TEST2 - should output DDD RRR
	value two sample dist2
	genif ${two}==0
		CCC
	genelsif ${two}=?1
		EEE
	genelse
		DDD
	end
	RRR
end

feature test3
	TEST3 - should output EEE FFF RRR
	value three sample dist1
	genif ${three}==0
		CCC
	genelsif ${three}==1
		EEE
	genelse
		DDD
	end
	genif ${three}==1
		FFF
	end
	RRR
end

generate 1 with dist0 = {0}, dist1 = {1}, dist2 = {2}
end genesis

__kernel
void kernel_mc02_orig(unsigned int outer_tc, unsigned int inner_tc, __global __volatile float *arr){

	${test0}
 
	${test1}
	
	${test2}
	
	${test3}
}
