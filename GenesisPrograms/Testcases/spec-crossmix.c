#combines cross and crosschar
#

begin genesis

	global
		value enumerator1 enumerate enumeratordist report(1)
		value sampler0 sample dist1 report(1)
		value enumerator2 enumerate chardist report(1)
	end

	program
		value enumerator3 enumerate enumeratordist report(1)
		value sampler1 sample dist1 report(1)
		value enumerator4 enumerate chardist report(1)		
	end

	feature varset
		value sampler4 sample dist1 report(1)

		GLOBAL ENUMERATED: ${enumerator1}
		SAMPLED: ${sampler0}
		GLOBAL ENUMERATED: ${enumerator2}
		PROGRAM ENUMERATED: ${enumerator3}
		SAMPLED SAME ALWAYS: ${sampler1}
		ENUMERATED: ${enumerator4}
		DIFFERENT IN PROGRAM: ${sampler4}
	end

	generate 1 with dist1 = {1:100}, enumeratordist = {1:2}, chardist = {a;b}
end genesis

    ${varset[2]}
