#combines cross and crosschar
#

begin genesis

	global
		value enumerator1 enumerate enumeratordist report(1)
		value sampler0 sample dist1 report(1)
		value enumerator2 enumerate chardist report(1)
	end

	program
	end

	feature varset
		ENUMERATED: ${enumerator1}
		SAME SOMETIMES: ${sampler0}
		ENUMERATED: ${enumerator2}

	end

	generate 2 with dist1 = {1:10}, enumeratordist = {1:2}, chardist = {a;b}
	generate 2 with dist1 = {11:20}, enumeratordist = {3:4}, chardist = {c;d}

end genesis

I stated Generate 2, twice
THIS SHOULD CREATE 16 sets of 1, since the cross of the enumerates in the global is 8, and you generate 2 of them for each cross.

    ${varset}
