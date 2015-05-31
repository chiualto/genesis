begin genesis

program
	value z_min enumerate stencil_radius_dist  
	value y_min = ${z_min}
end

feature reads

end

generate 1 with
	stencil_size_dist = {1:10}
end
end genesis