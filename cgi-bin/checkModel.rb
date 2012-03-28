#!/usr/bin/ruby
require 'fileutils'
require 'specialID'

def getTLD(url)
	url.gsub!(/^(.*?)>.*/,'\1')
	domain = url.gsub(/.*?\/\/(.*?)\/.*/,'\1')
	tld = domain.gsub(/.*\.(.*\..*)/,'\1')
	return tld
end

def probeXPATH(record)
	return (record.index("<=:| ")!=nil)
end

def makeDirectory(param)
	if (!File.directory?(param))
		#create the dir
		directoryNames = param.split('/')
		#currentDir = "/" #(linux)
		currentDir = "" #(windows)
		directoriesToCreate = Array.new
		directoryNames.each{|d|
			currentDir = currentDir + d + "/"
			if (!File.directory? currentDir)
				directoriesToCreate.push(currentDir)
			end
		}
		directoriesToCreate.each{|d|
			Dir.mkdir(d,0777)
		}
	end
end

def ExtractPolicyFromFile(rootDir, domain, url)
	policy = Hash.new
	makeDirectory(rootDir+domain+"/"+url+"/policies/")
	policyFiles = Dir.glob(rootDir+domain+"/"+url+"/policies/*")
	policyFiles.each{|f|
		if ((f=='.')||(f=='..')) then next
		end
		currentDomain = f.gsub(/.*\/(.+)\.txt$/,'\1')
		if (!policy.has_key? currentDomain)
			policy[currentDomain] = Array.new
		end
		policyContent = File.read(f)
		policyContent.each_line {|l|
			l = l.chomp
			if (l.index(" =|> ")!=nil) then l = l[0..l.index(" =|> ")-1] end
			if (l.index(" ==> ")!=nil) then l = l[l.index(" ==> ")+5..-1] end
			policy[currentDomain].push(l)
		}
	}
	return policy
end

def CheckModel(record, domain, url, urlStructure, id, relative)
	makeDirectory($PolicyRDir+domain+"/"+urlStructure)
	makeDirectory($PolicyADir+domain+"/"+urlStructure)
	policyA = Hash.new
	policyA = ExtractPolicyFromFile($PolicyADir,domain,urlStructure)				#if policy file doesn't exist, policyA and policyR would just be empty hashes.
	policyR = Hash.new
	if relative then policyR = ExtractPolicyFromFile($PolicyRDir,domain,urlStructure)
	end
	accessHashR = Hash.new
	diffArrayR = Hash.new
	accessHashA = Hash.new
	diffArrayA = Hash.new
	record.each_line{|line|
		line=line.chomp
		_wholoc1 = line.index(" |:=> ")
		_wholoc2 = line.index(" <=:| ")
		_wholoc3 = line.index(" <=|:| ")
		if (_wholoc1==nil)
			next
		end
		_who = line[_wholoc1+6..line.length]		#source of access
		if (_wholoc3 != nil)
			_who = line[_wholoc1+6.._wholoc3-1]	#get rid of the extraInfo.
		end
		if (_wholoc2==nil)
			_whatA = line[0.._wholoc1-1]
			if (_wholoc3 != nil)
				_whatA = _whatA + " ," + line[_wholoc3+7..line.length]
			end
			_tld = getTLD(_who)
			if (accessHashA[_tld]==nil)
				#2-level array
				#accessHash[_tld] = Hash.new
				accessHashA[_tld] = Array.new
			end
			#If we want to care about the number of accesses of each node, we uncomment the next line and make necessary changes
			#accessHash[_tld][_what] = (accessHash[_tld][_what]==nil) ? 1 : accessHash[_tld][_what]+1
			if (!accessHashA[_tld].include? _whatA)
				accessHashA[_tld].push(_whatA)
			end
			if (line[0]!='/')
				#not DOM node access, but we still need to push it to relative model.
				if (accessHashR[_tld]==nil)
					accessHashR[_tld] = Array.new
				end
				if (!accessHashR[_tld].include? [_whatA,_whatA])
					accessHashR[_tld].push([_whatA,_whatA])
				end
			end
		else
			#relative XPATH
			_whatR = line[0.._wholoc2-1]
			_whatA = line[_wholoc2+6.._wholoc1-1]
			if (_wholoc3 != nil)
				_whatA = _whatA + " ," + line[_wholoc3+7..line.length]
				_whatR = _whatR + " ," + line[_wholoc3+7..line.length]
			end
			_tld = getTLD(_who)
			if (accessHashR[_tld]==nil)
				accessHashR[_tld] = Array.new
			end
			if (accessHashA[_tld]==nil)
				accessHashA[_tld] = Array.new
			end
			if (!accessHashR[_tld].include? [_whatR,_whatA])
				accessHashR[_tld].push([_whatR,_whatA])
			end
			if (!accessHashA[_tld].include? _whatA)
				accessHashA[_tld].push(_whatA)
			end
		end
	}
	#done extracting accessHash from current record
	recordedTLD = Hash.new
	accessHashA.each_key{|tld|
		#historyContent = ""
		#makeDirectory($PolicyADir+domain+"/"+urlStructure+"/histories/")
		#if (File.exists?($PolicyADir+domain+"/"+urlStructure+"/histories/"+tld+".txt")) then historyContent = File.read($PolicyADir+domain+"/"+urlStructure+"/histories/"+tld+".txt") end
		accessHashA[tld].each{|a|
			if (!policyA.has_key? tld)
				#haven't seen any scripts from this domain before, now we do not record a diff file for this, we just record it in model suggestion.
				if (!diffArrayA.has_key? tld) 
					diffArrayA[tld] = Array.new
					diffArrayA[tld].push(a)
				else 
					diffArrayA[tld].push(a)
				end
			else
				#we have seen scripts from this domain
				if (!policyA[tld].include? a)
					#but the models haven't included this access
					if (!diffArrayA.has_key?(tld)) 
						diffArrayA[tld] = Array.new
						diffArrayA[tld].push(a)
					else 
						diffArrayA[tld].push(a)
					end
					
				else
					#pointer = historyContent.index(a+"\n")
					#pointer = historyContent.index("\n->Accessed Entries:",pointer)
					#pointer = historyContent.index("\n", pointer+2)-1
					#historyContent = historyContent[0..pointer]+" "+url+id.to_s+historyContent[pointer+1..historyContent.length]
				end
			end
		}
		#if (historyContent !="") then File.open($PolicyADir+domain+"/"+urlStructure+"/histories/"+tld+".txt","w") {|f| f.write(historyContent)} end
	}
	if (relative)
		accessHashR.each_key{|tld|
			#historyContent = ""
			#makeDirectory($PolicyRDir+domain+"/"+urlStructure+"/histories/")
			#if (File.exists?($PolicyRDir+domain+"/"+urlStructure+"/histories/"+tld+".txt")) then historyContent = File.read($PolicyRDir+domain+"/"+urlStructure+"/histories/"+tld+".txt") end
			accessHashR[tld].each{|a|
				if (!policyR.has_key? tld)
					#haven't seen any scripts from this domain before, currently we don't do anything until a model is built (within a few accesses)
					if (!diffArrayR.has_key? tld) 
						diffArrayR[tld] = Array.new
						diffArrayR[tld].push(a)
					else 
						diffArrayR[tld].push(a)
					end
				else
					#we have seen scripts from this domain
					if (!policyR[tld].include? a[0])&&(!policyR[tld].include? a[1])
						#but the models haven't included this access
						if (!diffArrayR.has_key? tld) 
							diffArrayR[tld] = Array.new
							diffArrayR[tld].push(a)
						else 
							diffArrayR[tld].push(a)
						end
					else
						pointer = 0
						if (policyR[tld].include? a[0]) 
							#pointer = historyContent.index(a[0]+"\n")
						else
							#pointer = historyContent.index(a[1]+"\n")
						end
						#pointer = historyContent.index("\n->Accessed Entries:",pointer)
						#pointer = historyContent.index("\n", pointer+2)-1
						#historyContent = historyContent[0..pointer]+" "+url+id.to_s+historyContent[pointer+1..historyContent.length]
					end
				end
			}
			#if (historyContent !="") then File.open($PolicyRDir+domain+"/"+urlStructure+"/histories/"+tld+".txt","w") {|f| f.write(historyContent)} end
		}
	end
	if (!diffArrayA.empty?)
		makeDirectory($DiffADir+domain+"/"+urlStructure+"/")
		diffAFileHandle = File.open($DiffADir+domain+"/"+urlStructure+"/#{url}?"+id.to_s+".txt","w")
		diffArrayA.each_key{|tld|
			#historyContent = ""
			#if (File.exists?($PolicyADir+domain+"/"+urlStructure+"/histories/"+tld+".txt")) then historyContent = File.read($PolicyADir+domain+"/"+urlStructure+"/histories/"+tld+".txt") end
			makeDirectory($DiffADir+domain+"/"+urlStructure+"/"+tld+"/")
			diffATLDHandle = File.open($DiffADir+domain+"/"+urlStructure+"/"+tld+"/#{url}?"+id.to_s+".txt","w")
			diffAFileHandle.write(tld+"\n")
			ph = File.open($PolicyADir+domain+"/"+urlStructure+"/policies/"+tld+".txt","a")
			diffArrayA[tld].each{|d|
				ph.write(d+"\n")		#add simple policy entry
				#historyContent += (d+"\n->Time Added:"+(Time.new.to_s)+"\n->First seen traffic:"+url+id.to_s+"\n->Time Deleted:\n->Accessed Entries:"+url+id.to_s+"\n\n")		#add policy history
				diffAFileHandle.write(d+"\n")
				diffATLDHandle.write(d+"\n")
			}
			ph.close()
			#if (historyContent !="") then File.open($PolicyADir+domain+"/"+urlStructure+"/histories/"+tld+".txt","w") {|f| f.write(historyContent)} end
			diffAFileHandle.write("------------------------\n")
			diffATLDHandle.close()
		}
		diffAFileHandle.close()
	end
	suggestedAnchors = Array.new
	if ((relative)&&(!diffArrayR.empty?))
		makeDirectory($DiffRDir+domain+"/"+urlStructure+"/")
		diffRFileHandle = File.open($DiffRDir+domain+"/"+urlStructure+"/#{url}?"+id.to_s+".txt","w")
		pfh = File.open($SpecialIdDir+domain+"/"+urlStructure+"/patchup.txt","a")
		traffic = File.read($TrafficDir+domain+"/"+urlStructure+"/"+url+"?"+id.to_s+".txt")
		originalTraffic = traffic.gsub(/\sspecialId\s=\s\'.*?\'/,'')
		diffArrayR.each_key{|tld|
			#historyContent = ""
			#if (File.exists?($PolicyRDir+domain+"/"+urlStructure+"/histories/"+tld+".txt")) then historyContent = File.read($PolicyRDir+domain+"/"+urlStructure+"/histories/"+tld+".txt") end
			diffRFileHandle.write(tld+"\n")
			makeDirectory($DiffRDir+domain+"/"+urlStructure+"/"+tld+"/")
			diffRTLDHandle = File.open($DiffRDir+domain+"/"+urlStructure+"/"+tld+"/#{url}?"+id.to_s+".txt","w")
			policyRFH = File.open($PolicyRDir+domain+"/"+urlStructure+"/policies/"+tld+".txt","a")
			diffArrayR[tld].each{|d|
				if (d[0].match(/\A\/\/id\d+.*/)!=nil)
					#if the violation starts with 'id', we know it's already an anchor. we simply record them.
					diffRFileHandle.write(d[0]+"\n")
					diffRTLDHandle.write(d[0]+"\n")
					#only add anchored entries to the model, if it's not an anchor yet, we just record it in diff file, not in the model.
					policyRFH.write(d[0]+"\n")		#add simple policy entry
					#historyContent += (d[0]+"\n->Time Added:"+(Time.new.to_s)+"\n->First seen traffic:"+url+id.to_s+"\n->Time Deleted:\n->Accessed Entries:"+url+id.to_s+"\n\n")		#add policy history
				elsif (d[0].match(/\A\/\/\d+.*/)!=nil)
					#otherwise if the violation starts with a digital number, we know it's not in anchor yet. we want to consider adding it as an anchor.			
					diffRFileHandle.write(d[0] + " ==> " + d[1])
					diffRTLDHandle.write(d[0] + " ==> " + d[1])
					newAnchor = d[0].gsub(/\A\/\/(\d+)$/,'\1')			#cater //393
					newAnchor = newAnchor.gsub(/\A\/\/(\d+?)\D.*/,'\1')		#cater //393 ,innerHTML or //393/object
					if (d[0]!=newAnchor)
						#generate a patch info
						attrIndex = traffic.index("specialId = '#{newAnchor}'")
						closinggt = findclosinggt(traffic, attrIndex)
						openinglt = findopeninglt(traffic, attrIndex)
						tagInfo = traffic[openinglt..closinggt].gsub(/\sspecialId\s=\s\'.*?\'/,'')
						vicinityInfo = (traffic[closinggt+1,100].gsub(/\sspecialId\s=\s\'.*?\'/,''))[0..$AnchorLength]

						#ensure our vicinity feature length is long enough to distinguish between similar vicinities.
						matchpoints = originalTraffic.enum_for(:scan,tagInfo+vicinityInfo).map{Regexp.last_match.begin(0)}
						currentExtraLength = 0
						while (matchpoints.size>1)
							currentExtraLength += 10
							if (currentExtraLength>$MaxAnchorVicinityLength) then break end		#bail out
							vicinityInfo = (traffic[closinggt+1,100].gsub(/\sspecialId\s=\s\'.*?\'/,'').gsub(/[\r\n]/,''))[0..$AnchorLength+currentExtraLength]
							matchpoints = originalTraffic.enum_for(:scan,tagInfo+vicinityInfo).map{Regexp.last_match.begin(0)}
						end

						diffRFileHandle.write(" =|> " + tagInfo.gsub(/[\r\n]/,'') + " => " + vicinityInfo.gsub(/[\r\n]/,''))
						diffRTLDHandle.write(" =|> " + tagInfo.gsub(/[\r\n]/,'') + " => " + vicinityInfo.gsub(/[\r\n]/,''))
						policyRFH.write(d[0]+" ==> "+d[1]+" =|> " + tagInfo.gsub(/[\r\n]/,'') + " => " + vicinityInfo.gsub(/[\r\n]/,'') +"\n")		#add simple policy entry
						#historyContent += (d[1]+"\n->Time Added:"+(Time.new.to_s)+"\n->First seen traffic:"+url+id.to_s+"\n->Time Deleted:\n->Accessed Entries:"+url+id.to_s+"\n\n")		#add policy history
						if (!suggestedAnchors.include?(newAnchor))
							pfh.write("{zyczyc{" + tagInfo + "}zyczyc{" + vicinityInfo + "}zyczyc}" + url + "{zyczyc}\n")
						end
						suggestedAnchors.push(newAnchor)
					end
					diffRFileHandle.write("\n")
					diffRTLDHandle.write("\n")
				else
					#it's gotta be a non-DOM node related access, we simply record them.
					policyRFH.write(d[0]+"\n")
					diffRFileHandle.write(d[0]+"\n")
					diffRTLDHandle.write(d[0]+"\n")
					#historyContent += (d[0]+"\n->Time Added:"+(Time.new.to_s)+"\n->First seen traffic:"+url+id.to_s+"\n->Time Deleted:\n->Accessed Entries:"+url+id.to_s+"\n\n")		#add policy history
				end
			}
			policyRFH.close()
			diffRFileHandle.write("------------------------\n")
			diffRTLDHandle.close()
			#if (historyContent !="") then File.open($PolicyRDir+domain+"/"+urlStructure+"/histories/"+tld+".txt","w") {|f| f.write(historyContent)} end
		}
		diffRFileHandle.close()
		pfh.close()
	end
end

def AdaptAnchor(domain, url, urlStructure)
	if ((!File.exists?($SpecialIdDir+domain+"/"+urlStructure+"/patchup.txt"))&&(!File.exists?($SpecialIdDir+domain+"/"+urlStructure+"/patchdown.txt"))) then return end
	patchdownFile = ""	
	if (File.exists?($SpecialIdDir+domain+"/"+urlStructure+"/patchdown.txt"))
		patchdownFile = File.read($SpecialIdDir+domain+"/"+urlStructure+"/patchdown.txt")
	end
	patchlines = Hash.new			#key: googlesyndication3
	linesToDelete = Array.new
	linesToAdd = Array.new
	patchdownFileTemp = patchdownFile
	while (patchdownFileTemp!="")&&(patchdownFileTemp!=nil)
		startingPointer = patchdownFileTemp.index("{zyczyc{")
		middlePointer = patchdownFileTemp.index("}zyczyc{")
		endPointer = patchdownFileTemp.index("}zyczyc}\n")
		if (startingPointer==nil)||(middlePointer==nil)||(endPointer==nil) then break end
		thisinfo = patchdownFileTemp[startingPointer..endPointer+8]
		patchlines[thisinfo] = (patchlines[thisinfo]==nil) ? 1 : patchlines[thisinfo]+1
		patchdownFileTemp = patchdownFileTemp[endPointer+9..-1]
	end
	patchlines.each_key{|l|
		if (patchlines[l]>$PatchDownThreshold) then linesToDelete.push(l) end
	}
	patchupFile = ""
	if (File.exists?($SpecialIdDir+domain+"/"+urlStructure+"/patchup.txt"))
		patchupFile = File.read($SpecialIdDir+domain+"/"+urlStructure+"/patchup.txt")
	end
	patchupFileTemp = patchupFile
	patchlines = Hash.new
	patchlineURLs = Hash.new
	while (patchupFileTemp!="")&&(patchupFileTemp!=nil)
		startingPointer = patchupFileTemp.index("{zyczyc{")
		middlePointer = patchupFileTemp.index("}zyczyc{")
		middlePointer2 = patchupFileTemp.index("}zyczyc}")
		endPointer = patchupFileTemp.index("{zyczyc}\n")
		if (startingPointer==nil)||(middlePointer==nil)||(middlePointer2==nil)||(endPointer==nil) then break end
		patchlineURL = patchupFileTemp[middlePointer2+8..endPointer-1]
		thisinfo = patchupFileTemp[startingPointer+8..middlePointer2+7]+"\n"
		patchlines[thisinfo] = (patchlines[thisinfo]==nil) ? 1 : patchlines[thisinfo]+1
		if (patchlineURLs[thisinfo]==nil) then patchlineURLs[thisinfo] = Array.new end
		patchlineURLs[thisinfo].push(patchlineURL)
		patchupFileTemp = patchupFileTemp[endPointer+8..-1]
	end
	#eliminate those whose patchlineURLs only has 1 entry.
	#first get the standalone status
	if (File.exists?($StandaloneDir + domain + ".txt"))
		standaloneFC = File.read($StandaloneDir + domain + ".txt")
		standaloneFC.each_line{|l|
			if (l.match(/#{Regexp.quote(urlStructure)}\s.*/)!=nil)
				temp = l.chomp.gsub(/.*\s(.*)/,'\1')
				if (temp[0]==116)
					$standalonePage = true
				else
					$standalonePage = false 
				end
				break
			end
		}
	end
	if (!$standalonePage)
		# if this page is some kind of homepage that can have no more than 1 entry.
		patchlineURLs.each_key{|l|
			patchlineURLs[l].uniq!
			if (patchlineURLs[l].length == 1)
				patchlines.delete(l)
			end
		}
	end
	patchlines.each_key{|l|
		if (patchlines[l]>$PatchUpThreshold) then linesToAdd.push(l) end
	}
	linesToAdd.uniq!
	#obsolete anchors stored to oldAnchors.txt
	if ((!linesToDelete.empty?)||(!linesToAdd.empty?))
		original = File.read($SpecialIdDir+domain+"/"+urlStructure+"/"+urlStructure+".txt")
		id = 0
		original.each_line{|l|
			cur_id = l.gsub(/^\{zyczyc\{Tag\s(\d+)\s.*/,'\1')
			if (cur_id.to_i>id) then id = cur_id.to_i end
		}
		oldAFH = File.open($SpecialIdDir+domain+"/"+urlStructure+"/oldAnchors.txt","a")
		linesToDelete.each{|l|
			#oldAFH.write(l)
			original.gsub!(/#{Regexp.quote(l)}/m,'')
			patchdownFile.gsub!(/#{Regexp.quote(l)}/m,'')
=begin
			#delete all model entries associated with this anchor.
			Dir.glob($PolicyRDir+domain+"/"+urlStructure+"/policies/*"){|f|
				content = File.read(f)
				idToDelete = l.gsub(/\A#?Tag\s(\d+)\s.*/,'\1')
				modifiedContent = content.clone
				content.each_line{|l2|
					if (l2.match(/\A\/\/id#{Regexp.quote(idToDelete)}/)!=nil)
						modifiedContent.slice!(l2)			#l2 already has \n in it.
					end
				}
				File.open(f,"w"){|fh| fh.write(modifiedContent)}
			}
			#enter deletion time for all model histories associated with this anchor
			Dir.glob($PolicyRDir+domain+"/"+urlStructure+"/histories/*"){|f|
				content = File.read(f)
				idToDelete = l.gsub(/\A#?Tag\s(\d+)\s.*/,'\1')
				curTime = Time.new.to_s
				matchpoints = content.enum_for(:scan,"id#{idToDelete}").map{Regexp.last_match.begin(0)}
				matchpoints.each{|p|
					startpoint = content.index("->Time Deleted:",p)			
					endpoint = content.index("\n",startpoint+2)
					content = content[0..startpoint-1]+"->Time Deleted:"+curTime+content[endpoint..-1]
				}
				File.open(f,"w"){|fh| fh.write(content)}
			}
=end
		}
		oldAFH.close()
		#read all diff files into memory
		diffFiles = Dir.glob($DiffRDir+domain+"/"+urlStructure+"/*")
		diffFileHash = Hash.new
		diffFiles.each{|d|
			if (!File.directory? d) then diffFileHash[d] = File.read(d) end
		}
		#read all policy files into memory
		policyFiles = Dir.glob($PolicyRDir+domain+"/"+urlStructure+"/policies/*")
		policyFileHash = Hash.new
		policyFiles.each{|d|
			if (!File.directory? d) then policyFileHash[d] = File.read(d) end
		}
		linesToAdd.each{|l|
			if (original.match(/\{zyczyc\{Tag\s\d+\s:=\s#{Regexp.quote(l)}/)!=nil) then next end			#to avoid duplicates
			id += 1
			original = original + "{zyczyc{Tag #{id} := " + l
			tagContent = l.gsub(/^(.*?)\}zyczyc\{.*/m,'\1')
			vicinityInfo = l.gsub(/.*\}zyczyc\{(.*?)\}zyczyc\}.*/m,'\1')
			
			#also replace diff files with new id.
			diffFileHash.each_key{|k|
				#for each diff file
				diffFileHash[k].gsub!(/\n\/\/\d+(.*?)\s==>.*?#{Regexp.quote(" =|> " + tagContent.gsub(/[\r\n]/,'') + " => " + vicinityInfo.gsub(/[\r\n]/,''))}/,"\n//id#{id}"+'\1')
			}
			policyFileHash.each_key{|k|
				#for each policy file
				policyFileHash[k].gsub!(/\n\/\/\d+(.*?)\s==>.*?#{Regexp.quote(" =|> " + tagContent.gsub(/[\r\n]/,'') + " => " + vicinityInfo.gsub(/[\r\n]/,''))}/,"\n//id#{id}"+'\1')
			}
		}
		#flush diff file to disk.
		diffFileHash.each_key{|k|
			#uniq the lines
			temp = Array.new
			diffFileHash[k].each_line{|l|
				temp.push(l)
			}
			temp.uniq!
			towrite = temp.join()
			File.open(k,"w"){|fh| fh.write(towrite)}
		}
		#flush policy file to disk.
		policyFileHash.each_key{|k|
			#uniq the lines
			temp = Array.new
			policyFileHash[k].each_line{|l|
				temp.push(l)
			}
			temp.uniq!
			towrite = temp.join()
			File.open(k,"w"){|fh| fh.write(towrite)}
		}
		linesToAdd.each{|l|
			startingPoint = patchupFile.index("{zyczyc{"+l.chomp)
			while (startingPoint!=nil)
				endPoint = patchupFile.index("{zyczyc}\n",startingPoint)
				if startingPoint==0 then patchupFile = patchupFile[endPoint+9..-1] else patchupFile = patchupFile[0..startingPoint-1]+patchupFile[endPoint+9..-1] end
				startingPoint = patchupFile.index("{zyczyc{"+l.chomp)
			end
		}
		File.open($SpecialIdDir+domain+"/"+urlStructure+"/"+urlStructure+".txt","w"){|f| f.write(original)}		#change the anchors de facto
		#we have changed anchors, we need to remove patch recommendations as well.
		File.open($SpecialIdDir+domain+"/"+urlStructure+"/patchdown.txt","w"){|f| f.write(patchdownFile)}		#change the patchdown file
		File.open($SpecialIdDir+domain+"/"+urlStructure+"/patchup.txt","w"){|f| f.write(patchupFile)}		#change the patchup file
	end
end
