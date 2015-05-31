begin genesis

	global
		distribution backgrounddist = {1:3}
		distribution numfacesdist = {1:20}
		distribution facesdist = {1:1000}
		distribution locationdist = {1:1024}
		value counter = 0
	end

	program
	end
	
	feature loadimage
		value background sample backgrounddist
		genif background == 1
			genmath background = "grass.jpg"
		genelsif background == 2
			genmath background = "field.jpg"
		genelsif background == 3
			genmath background = "house.jpg"
		end	
		load "background" to outputfile
	end
	
	feature overlayface
		value heightvalue sample locationdist
		value widthvalue sample locationdist
		value sizelimit = photosize-heightvalue
		distribution sizedist = {1:sizelimit}
		value sizevalue sample sizedist
		value face sample facesdist
		place facefile${face}.jpg at height heightvalue and width widthvalue with size ${sizevalue}x
	end
	
	feature storeimage
		genmath counter = counter + 1
		load outputfile to "output${counter}.jpg"
	end
	
	feature image
		loadimage
		value numberfaces sample numfacesdist
		overlayface[numberfaces]
		storeimage
	end

	generate   
end genesis

image[1000]