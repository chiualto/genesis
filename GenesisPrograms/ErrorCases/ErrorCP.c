begin genesis

	global
		distribution photosizedist = {64;128;256;512}
		distribution numfacesdist = {1:10}
		distribution backgrounddist = {1:3}
		distribution facesdist = {1:1000}

	end

	program
		value photosize sample photosizedist
	end
	
	feature storeimage
		load output to "output.jpg"
		${dummy}
	end
	
	feature dummy
		${storeimage}
	end
	
	feature image
		${storeimage}
	end

	generate 5
end genesis

${image}
