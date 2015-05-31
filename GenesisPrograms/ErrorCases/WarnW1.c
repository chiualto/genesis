#shows theres a timing different when theres a assert

begin genesis
	global
	end
	
	program
		distribution oops = {1:2}
		value topic enumerate oops
	end

	feature test1
		genassert ${topic}!=2
		genloop test:1:10000
			${test}
		end
	end

	generate 2
end genesis

${test1[5]}
