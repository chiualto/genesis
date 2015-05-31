#contains various value sampling
#tests 
#	-global distributions
#	-global distributions with sampled value in range
#	-negative samples
#	-character samples
#	-real samples
#	-sample spacing
# same value names/dist names in a feature

begin genesis

	global
		varlist temp[10]
		distribution distx={"${abc"}
		distribution disty={"efg}"}
	end
	
	program
		distribution dist1 = {1:10}
		value stride1 sample dist1 report(1)
		distribution dist2 = {1:${stride1}}
	end

	feature access
		value stride2 sample dist2 report(1)
		Stride2 is ${stride2}
	end

	feature test1
		TEST1: Various samplings
		value normaloffset sample dist3 report(1)
		value negoffset sample dist4 report(1)
		value charoffset sample dist5 report(1)
		value realoffset sample dist6 report(1)
		value realoffset3 sample dist63 report(1)
		value realoffset8 sample dist68 report(1)
		value abc,qwe,zxc sample dist7 noreplacement(1)
		stride1(1:10) is ${stride1}
		Five Stride2s (1:Stride1)
		${access[5]}
		
		1:10: ${normaloffset}
		Twice in one line: ${normaloffset} ${normaloffset}
		-10:-1: ${negoffset}
		a b or c: ${charoffset}
		1:10, real2: ${realoffset}
		1:10, real3: ${realoffset3}
		1:10, real8: ${realoffset8}		
		1,2,3, no replacement: ${abc} ${qwe} ${zxc}
		End of Test
	end
	
	feature test2
		TEST2: same distribution name in genifs
		genif 1==1
			distribution dist8 = {1:10}
			value tester sample dist8
			1:10: ${tester}
		end
		genif 1==1
			distribution dist8 = {11:20}
			value tester sample dist8
			11:20: ${tester}
		end
		End of Test
	end
	
	feature test3
		TEST3: Test2 addon, same value name
		genif 1==1
			value tester sample dist1
			1:10: ${tester}
		end
		End of Test
	end
	
	feature test4
		TEST4: Valvarequal: All these should be the same
		variable source1 from temp report(1)
		variable source2 = ${source1} report(1)
		${source1} ${source1} ${source2};
		value stride3 sample dist1 report(1)
		value stride4 = ${stride3} report(1)
		value offset = ${stride4} report(1)
		${stride3} ${stride4} ${offset}
	end
	
	feature test5
		TEST5: Value with same name in other feature.
		1st line replaced (with a neg value), 2nd line should not be replaced 
		value normaloffset sample dist4
		In the feature: ${normaloffset}
		sub5test
	end
	
	feature sub5test
		In sub feature: should not replace: ${normaloffset}
	end
	
	feature test6
		TEST6: inline sampling
		value test6a sample {1:5}
		value test6b sample {1;5}
		value test6c sample {1{0.8};5{0.2}}
		${test6a} ${test6b} ${test6c}
	end

	feature test7
		TEST6: Concatenation: concats 2 references whose values make a reference
		should say "hello" next line
		value a1 sample distx
		value a2 sample disty
		value abcefg = "hello"
		${a1}${a2}
	end
	
	generate 5 with dist3 = { 1:10 } , dist4 = { -10: -1}, dist5 = {a; b;c} , dist6 ={1:10;;real}, dist63 ={1:10;;real(3)},dist68 ={1:10;;real(8)}, dist7 = {1:3}
end genesis

    ${test1}
	
	${test2}
	
	${test3}

	${test4}
	
	${test5}
	
	${test6}
	
	${test7}