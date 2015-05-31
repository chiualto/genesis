begin genesis

	global
		value numepochs sample epochdist report(1)
	end
	
	program
		value numvars sample numvardist
		varlist temp[5] type(float)
		varlist foo[${numvars}] type(int)
		
		value sample1 sample {0:99}
		value sample2 = 300

		value sample1_orig = ${sample1}
		value sample2_orig = ${sample2}
	
	end
		

	feature computation 
		variable dest from temp
		variable source1 from temp
		variable source2 from temp
		variable source3 from temp
		${dest} = ${source1} * ${source2} + ${source3};
	end

	feature test1
		tester [${numepochs} + ${numvars}]
	end

	feature tester
		This line occurs multiple times: repetition bracket has math.
	end

	feature access
		variable varj from temp
		value stride1 sample dist1 report(1)
		value stride2 sample dist1 report(1)
		value offset sample dist2 report(1)
		${varj} = arr[${stride1}*it00 + ${stride2}*it01 + ${offset}];
	end

	feature test2

		value wah = abc;

		The middle has been replaced with abc.
		AAA ${wah} BBB
		
		Not yet sampled:  (removed ref, no longer allowed)
		QQQ numcompsrefwashere WWW
		value numcomps sample compdist report(1)
		variable anvar from temp
		
		Normal:
		TEST ${numvars} TEST
		genmath numvars=${numvars}+30
		+30:
		TEST ${numvars} TEST
		genif 1==1
			Inside genif +30:
			genmath numvars = ${numvars} + 30
			TESTA ${numvars} TESTA
		end
		Outside genif, still scoped:
		TEST ${numvars} TEST
		genif 1==0
			genmath numvars = ${numvars} + 30
			remove all from temp
		end
		
		genif 1==1
			Sampled inside genif:
			value hope sample compdist
			AAA ${hope} BBB
		end
		Won't work cause outside of genif: (removed ref, no longer allowed)
		CCC hoperefwashere DDD
		
		variable asdf from temp
		#remove all from temp
		#variable asdf2 from temp
		${asdf}
		TEST ${numvars} TEST
		genmath numvars=${numvars}+30
		TEST ${numvars} TEST
		TEST2 ${numcomps} TEST2
		TEST3 destwashere exists elsewhere (removed ref, no longer allowed)
		TEST4 doesntexistwashere TEST4 (removed ref, no longer allowed)
		
		
		Last 6 should work:
		FIX: only last should work
		
		\numcomps
		\\numcomps
		\numcomps (removed ref, no longer allowed)
		\\numcomps (removed ref, no longer allowed)
		numcompsa];
		 numcompsa];
		 anumcomps];
		[numcompsa];
		a numcompsa];
		a [numcomps];
		a [numcomps] ;
		a ${numcomps a];
		numcomps a];
		a numcomps a];
		a ${numcomps} a];

		\anvar
		\\anvar
		\anvar (removed ref, no longer allowed)
		\\anvar (removed ref, no longer allowed)
		anvara];
		 anvara];
		 aanvar];
		[anvara];
		a anvara];
		a [anvar];
		a [anvar] ;
		a ${anvar a];
		anvar a];
		a anvar a];
		a ${anvar} a];

		\access
		\\access
		\access (removed ref, no longer allowed)
		\\access (removed ref, no longer allowed)
		accessa];
		 accessa];
		 aaccess];
		[accessa];
		a accessa];
		a [access];
		a [access] ;
		a ${access a];
		access a];
		a access a];
		a ${access} a];

		value dummy=1
		
		genloop paramvar:${numvars}+1:${numvars}+2
			\paramvar
			\\paramvar
			\paramvar (removed ref, no longer allowed)
			\\paramvar (removed ref, no longer allowed)
			paramvara];
			 paramvara];
			 aparamvar];
			[paramvara];
			a paramvara];
			a [paramvar];
			a [paramvar] ;
			a ${paramvar a];
			paramvar a];
			a paramvar a];
			a ${paramvar} a];
		end


		Escape charactered so these should all show up:
		\genloop asdf:1:2
		\genif qwer==1

		1 \\\:
		\\\ abc
		\\\\ abc

		1 genspace:
		genspace
		\genspace

		geneval differences. 1 is plain, 2 is evaled, 3 is escaped:
		1+2
		geneval(1+2)
		\geneval(1+2)

		showing gen tab. 1 is plain, 2 is gen tabed, 3 is escaped:
		ABC
		gentabABC
		\gentabABC


		For fun: (removed ref, no longer allowed)
		varj = arr[stride1*it00 + stride2*it01 + offset];
	end


	
feature print
	#define sample1 (${sample1}) ${sample1_orig}
	#define sample2 (${sample2}) ${sample2_orig}
end


feature change
	genmath sample2 = ${sample1}
	${print}
end

feature test3
	TEST3: Feature Test
	Original Values:
	${print}
	
	Perform the Change and print in "change"
	${change}
	
	printing inside the Test:
	${print}
end

	
	generate 5 with dist1 = {1:10},numvardist = {2:8},epochdist = {1:5},compdist = {1:5},dist2 = {1:10;;real}
end genesis


	${test1}
	
	${test2}
	
	${test3}

	Printing in target code:
	${print}