#tests params, params inside genifs

begin genesis
	
	global
	end

	program
	end

	feature computation (source1,source2,dest)
		${dest} = ${source1} * ${source2};
	end

	feature access (stride1,stride2,offset,varj)
		genif 1==1
			${varj} = arr[${stride1}*it00 + ${stride2}*it01 + ${offset}];
		end
	end

	feature epoch
		${computation(var1,var2,var3)}
		${access(1,2,3,var2)}
	end

	feature test1
		TEST1:
		All vars should be:
		var3 var1 var2 - tests params
		1 2 3 var2 - tests params being used inside a genif
		
		${epoch[2]}
		End of Test
	end
	
	feature test2
		TEST2: symbols
		${access(+-*/(),2,3,var2)}
	end
	
	generate 1
end genesis

    ${test1}

	${test2}