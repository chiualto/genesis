#ifelse, ifcomplex, nestedifs
# tests basic if else, multiclause ifs, and nestedifs


begin genesis
	
	global
	end
	
	program
	end

	feature test0
		TEST0 - Goes into IF. should output AAA
		value zero sample dist0
		genif ${zero}==0
			AAA
		genelse
			BBB
		end
		End of Test
	end

	feature test1
		TEST1 - Goes into ELSE. should output BBB
		value one sample dist1
		genif ${one}==0
			AAA
		genelse
			BBB
		end
		End of Test
	end

	feature test2
		TEST2 - Goes into ELSE with a genelsif. should output CCC
		value two sample dist2
		genif ${two}==0
			AAA
		genelsif ${two}==1
			BBB
		genelse
			CCC
		end
		End of Test
	end

	feature test3
		TEST3 - Goes into 1st ELSEIF and 2nd GENIF. should output BBB DDD
		value three sample dist1
		genif ${three}==0
			AAA
		genelsif ${three}==1
			BBB
		genelse
			CCC
		end
		genif ${three}==1
			DDD
		end
		End of Test
	end
	
	feature test4
		TEST4 - Inequality has 2 clauses. should output AAA
		value foura sample dist0 report(1)
		value fourb sample dist1 report(1)
		genif ${foura}==0&&${fourb}==1
			AAA
		genelse
			BBB
		end
		End of Test
	end
	
	feature test5
		TEST5 - Inequality has 2 clauses. should output BBB
		value fivea sample dist1 report(1)
		value fiveb sample dist1 report(1)
		genif ${fivea}==0&&${fiveb}==1
			AAA
		genelsif ${fivea}==1&&${fiveb}==1
			BBB
		genelse
			CCC
		end
		End of Test
	end
	
	feature test6
		TEST6 - Inequality has 2 clauses. should output CCC
		value sixa sample dist1 report(1)
		value sixb sample dist1 report(1)
		genif ${sixa}==0&&${sixb}==1
			value test sample {1:4}
			AAA
		genelsif ${sixa}==1&&${sixb}==0
			value test sample {1:4}
			BBB
		genelse
			value test sample {1:4}
			CCC
		end
		End of Test
	end
	
	feature test7
		TEST7 - Nested If. Should output BBB
		value sevena sample dist0 report(1)
		value sevenb sample dist1 report(1)
		genif ${sevena}==0
			genif ${sevenb}==0
				value test sample {1:4}
				AAA
			genelsif ${sevenb}==1
				value test sample {1:4}
				BBB
			end
		genelsif ${sevena}==1
			genif ${sevenb}==0
				CCC
			genelsif ${sevenb}==1
				DDD
			end
		genelse
			EEE
		end
		End of Test
	end
	
	feature test8
		TEST8 - Nested If. Should output DDD
		value eighta sample dist1 report(1)
		value eightb sample dist1 report(1)
		genif ${eighta}==0
			genif ${eightb}==0
				AAA
			genelsif ${eightb}==1
				BBB
			end
		genelsif ${eighta}==1
			genif ${eightb}==0
				CCC
			genelsif ${eightb}==1
				DDD
			end
		genelse
			EEE
		end
		End of Test
	end

	feature test9
		TEST9 - genif/genif/genelse with space. Should output ABCADAC
		genloop k:-1:1
			A
			value k_abs = ${k}
			genif ${k} < 0
				B
				genmath k_abs = 1
			end

			genif (${k_abs} == 1)
				C
			genelse
				D
			end
		end
		End of Test
	end
	
	feature test10
	TEST10 - genif/genif/genelse. Should output ABCADAC
		genloop k:-1:1
			A
			value k_abs = ${k}
			genif ${k} < 0
				B
				genmath k_abs = 1
			end
			genif (${k_abs} == 1)
				C
			genelse
				D
			end
		end
		End of Test
	end
	
	feature test11
		TEST11 - testing ==
		value abc = "abc"
		abc ${abc}
		quote = quote (works) (terminal warning)
		genif ${abc}=="abc" 
			AAA
		end
		quote = noquote
		genif ${abc}==abc 
			BBB
		end
		quote eq quote (works)
		genif ${abc} eq "abc"
			CCC
		end
		quote eq noquote
		genif ${abc} eq abc
			DDD
		end
		value abc2 = abc
		noquote == quote
		abc ${abc2}
		genif ${abc2}=="abc"
			EEE
		end
		noquote == noquote
		genif ${abc2}==abc
			FFF
		end
		noquote eq quote
		genif ${abc2} eq "abc"
			GGG
		end
		noquote eq noquote
		genif ${abc2} eq abc
			HHH
		end
		value abc3 = 'abc'
		singlequote == quote (works) (terminal warning)
		genif ${abc3} == "abc"
			III
		end
		singlequote == singlequote (works) (terminal warning)
		genif ${abc3} == 'abc'
			JJJ
		end
		singlequote == noquote 
		genif ${abc3} == abc
			KKK
		end
		singlequote eq quote (works)
		genif ${abc3} eq "abc"
			LLL
		end
		singlequote eq singlequote (works)
		genif ${abc3} eq 'abc'
			MMM
		end
		singlequote eq noquote
		genif ${abc3} eq abc
			NNN
		end
	end
	
	generate 1 with dist0 = {0}, dist1 = {1}, dist2 = {2}
end genesis

	${test0}
 
	${test1}
	
	${test2}
	
	${test3}
	
	${test4}
	
	${test5}
	
	${test6}
	
	${test7}
	
	${test8}
	
	${test9}
		
	${test10}
	
	${test11}