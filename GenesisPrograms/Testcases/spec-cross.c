#combines cross and crosschar
#

begin genesis

	global
		value sampler0 sample dist1 report(1)
	end

	program
		value sampler1 sample dist1 report(1)
		value enumerator1 enumerate enumeratordist report(1)
		value enumerator2 enumerate chardist report(1)
		value sampler2 sample dist1 report(1)
		value enumerator3 enumerate chardist report(1)	
		value sampler3 sample dist1 report(1)		
	end

	feature varset
		value sampler4 sample dist1 report(1)

		SAME ALWAYS: ${sampler0}
		SAME THROUGH SET: ${sampler1}
		ENUMERATED: ${enumerator1}
		ENUMERATED: ${enumerator2}
		DIFFERENT PER 2 PROGRAM: ${sampler2}
		ENUMERATED: ${enumerator3}
		DIFFERENT PER PROGRAM: ${sampler3}
		DIFFERENT IN PROGRAM: ${sampler4}
	end

	generate 1 with dist1 = {1:100}, enumeratordist = {1:2}, chardist = {a;b}
end genesis

    ${varset[2]}
