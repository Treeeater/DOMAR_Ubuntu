#!/usr/bin/ruby
require 'fileutils'
require 'specialID'

def getTLD(url)
	domain = url.gsub(/.*?\/\/(.*?)\/.*/,'\1')
	tld = domain.gsub(/.*\.(.*\..*)/,'\1')
	return tld
end

def probeXPATH(record)
	return (record.index("<=:| ")!=nil)
end

def makeDirectory(param)
	#cleans everything in param directory! Use extreme caution!
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
			policy[currentDomain].push(l.chomp)
		}
	}
	return policy
end

def CheckModel(record, domain, url, id, relative)
	makeDirectory($PolicyRDir+domain+"/"+url)
	makeDirectory($PolicyADir+domain+"/"+url)
	policyA = Hash.new
	policyA = ExtractPolicyFromFile($PolicyADir,domain,url)				#if policy file doesn't exist, policyA and policyR would just be empty hashes.
	policyR = Hash.new
	if relative then policyR = ExtractPolicyFromFile($PolicyRDir,domain,url)
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
				if (!accessHashR[_tld].include? _whatA)
					accessHashR[_tld].push(_whatA)
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
			if (!accessHashR[_tld].include? _whatR)
				accessHashR[_tld].push(_whatR)
			end
			if (!accessHashA[_tld].include? _whatA)
				accessHashA[_tld].push(_whatA)
			end
		end
	}
	#done extracting accessHash from current record
	recordedTLD = Hash.new
	accessHashA.each_key{|tld|
		historyContent = ""
		if (File.exists?($PolicyADir+domain+"/"+url+"/histories/"+tld+".txt")) then historyContent = File.read($PolicyADir+domain+"/"+url+"/histories/"+tld+".txt") end
		accessHashA[tld].each{|a|
			if (!policyA.has_key? tld)
				#haven't seen any scripts from this domain before, now we do not record a diff file for this, we just record it in model suggestion.
=begin
				if (!diffArrayA.has_key? tld) 
					diffArrayA[tld] = Array.new
					diffArrayA[tld].push(a)
				else 
					diffArrayA[tld].push(a)
				end
=end
				#we also want to record this in a model suggestion file (works for both absolute and relative)
				if (!recordedTLD.has_key? tld)
					makeDirectory($PolicyADir+domain+"/"+url+"/list/")
					File.open($PolicyADir+domain+"/"+url+"/list/"+tld,'a'){|f| f.write(id+"\n")}
					recordedTLD[tld]=true
					#we want to check if we can can build a model for this domain
					list = File.read($PolicyADir+domain+"/"+url+"/list/"+tld)
					lineNo = 0
					trainingDataIndices = Array.new
					list.each_line{|l|
						trainingDataIndices.push(l.chomp)
						lineNo+=1
					}
					if (lineNo>=$ModelThreshold)
						#we want to build the model for this domain
						BuildModel(domain, url, tld, trainingDataIndices)		#build model actually builds two models, one for absolute one for relative
						#File.delete($PolicyRDir+domain+"/"+url+"/LIST_"+tld)
					end
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
					File.open($PolicyADir+domain+"/"+url+"/policies/"+tld+".txt","a"){|f| f.write(a+"\n")}		#add simple policy entry
					historyContent += (a+"\n->Time Added:"+(Time.new.to_s)+"\n->Traffic ID:"+id.to_s+"\n->Time Deleted:\n->Accessed Entries:"+id.to_s+"\n\n")				#add policy history
				else
					#File.open("/home/yuchen/success","a"){|f| f.write(a+"\n")}
					pointer = historyContent.index(a+"\n")
					pointer = historyContent.index("\n->Accessed Entries:",pointer)
					pointer = historyContent.index("\n", pointer+2)-1
					historyContent = historyContent[0..pointer]+" "+id.to_s+historyContent[pointer+1..historyContent.length]
				end
			end
		}
		if (historyContent !="") then File.open($PolicyADir+domain+"/"+url+"/histories/"+tld+".txt","w") {|f| f.write(historyContent)} end
	}
	if (relative)
		accessHashR.each_key{|tld|
			historyContent = ""
			if (File.exists?($PolicyRDir+domain+"/"+url+"/histories/"+tld+".txt")) then historyContent = File.read($PolicyRDir+domain+"/"+url+"/histories/"+tld+".txt") end
			accessHashR[tld].each{|a|
				if (!policyR.has_key? tld)
					#haven't seen any scripts from this domain before, currently we don't do anything until a model is built (within a few accesses)
=begin
					if (!diffArrayR.has_key? tld) 
						diffArrayR[tld] = Array.new
						diffArrayR[tld].push(a)
					else 
						diffArrayR[tld].push(a)
					end
=end
				else
					#we have seen scripts from this domain
					if (!policyR[tld].include? a)
						#but the models haven't included this access
						if (!diffArrayR.has_key? tld) 
							diffArrayR[tld] = Array.new
							diffArrayR[tld].push(a)
						else 
							diffArrayR[tld].push(a)
						end
						if (a.match(/\A\/\/\d+.*/)==nil)
							#only add anchored entries to the model, if it's not an anchor yet, we just record it in diff file, not in the model.
							File.open($PolicyRDir+domain+"/"+url+"/policies/"+tld+".txt","a"){|f| f.write(a+"\n")}		#add simple policy entry
							historyContent += (a+"\n->Time Added:"+(Time.new.to_s)+"\n->Traffic ID:"+id.to_s+"\n->Time Deleted:\n->Accessed Entries:"+id.to_s+"\n\n")		#add policy history
						end
					else
						pointer = historyContent.index(a+"\n")
						pointer = historyContent.index("\n->Accessed Entries:",pointer)
						pointer = historyContent.index("\n", pointer+2)-1
						historyContent = historyContent[0..pointer]+" "+id.to_s+historyContent[pointer+1..historyContent.length]
					end
				end
			}
			if (historyContent !="") then File.open($PolicyRDir+domain+"/"+url+"/histories/"+tld+".txt","w") {|f| f.write(historyContent)} end
		}
	end
	if (!diffArrayA.empty?)
		makeDirectory($DiffADir+domain+"/"+url+"/")
		diffAFileHandle = File.open($DiffADir+domain+"/"+url+"/diff"+id.to_s+".txt","w")
		diffArrayA.each_key{|tld|
			makeDirectory($DiffADir+domain+"/"+url+"/"+tld+"/")
			diffATLDHandle = File.open($DiffADir+domain+"/"+url+"/"+tld+"/diff"+id.to_s+".txt","w")
			diffAFileHandle.write(tld+"\n")
			diffArrayA[tld].each{|d|
				diffAFileHandle.write(d+"\n")
				diffATLDHandle.write(d+"\n")
			}
			diffAFileHandle.write("------------------------\n")
			diffATLDHandle.close()
		}
		diffAFileHandle.close()
	end
	suggestedAnchors = Array.new
	if ((relative)&&(!diffArrayR.empty?))
		makeDirectory($DiffRDir+domain+"/"+url+"/")
		diffRFileHandle = File.open($DiffRDir+domain+"/"+url+"/diff"+id.to_s+".txt","w")
		pfh = File.open($SpecialIdDir+domain+"/"+url+"/patchup.txt","a")
		traffic = File.read($TrafficDir+domain+"/"+url+"/"+url+id.to_s+".txt")
		diffArrayR.each_key{|tld|
			diffRFileHandle.write(tld+"\n")
			makeDirectory($DiffRDir+domain+"/"+url+"/"+tld+"/")
			diffRTLDHandle = File.open($DiffRDir+domain+"/"+url+"/"+tld+"/diff"+id.to_s+".txt","w")
			diffArrayR[tld].each{|d|
				if (d.match(/\A\/\/id\d+.*/)!=nil)
					#if the violation starts with 'id', we know it's already an anchor. we simply record them.
					diffRFileHandle.write(d+"\n")
					diffRTLDHandle.write(d+"\n")
				elsif (d.match(/\A\/\/\d+.*/)!=nil)
					#otherwise if the violation starts with a digital number, we know it's not in anchor yet. we want to consider adding it as an anchor.			
					diffRFileHandle.write(d+"\n")
					diffRTLDHandle.write(d+"\n")
					newAnchor = d.gsub(/\A\/\/(\d+)$/,'\1')			#cater //393
					newAnchor = newAnchor.gsub(/\A\/\/(\d+?)\D.*/,'\1')		#cater //393 ,innerHTML or //393/object
					if ((d!=newAnchor)&&(!suggestedAnchors.include?(newAnchor)))
						#generate a patch info
						attrIndex = traffic.index("specialId = '#{newAnchor}'")
						closinggt = findclosinggt(traffic, attrIndex)
						openinglt = findopeninglt(traffic, attrIndex)
						tagInfo = traffic[openinglt..closinggt].gsub(/\sspecialId\s=\s\'.*?\'/,'')
						vicinityInfo = (traffic[closinggt+1,100].gsub(/\sspecialId\s=\s\'.*?\'/,'').gsub(/[\r\n]/,''))[0..30]
						suggestedAnchors.push(newAnchor)
						pfh.write(tagInfo + " => " + vicinityInfo + "\n")
					end
				else
					#it's gotta be a non-DOM node related access, we simply record them.
					diffRFileHandle.write(d+"\n")
					diffRTLDHandle.write(d+"\n")
				end
			}
			diffRFileHandle.write("------------------------\n")
			diffRTLDHandle.close()
		}
		diffRFileHandle.close()
		pfh.close()
	end
end

def AdaptAnchor(domain, url)
	if ((!File.exists?($SpecialIdDir+domain+"/"+url+"/patchup.txt"))&&(!File.exists?($SpecialIdDir+domain+"/"+url+"/patchdown.txt"))) then return end
	patchdownFile = File.read($SpecialIdDir+domain+"/"+url+"/patchdown.txt")
	patchlines = Hash.new			#key: googlesyndication3
	linesToDelete = Array.new
	linesToAdd = Array.new
	patchdownFile.each_line{|l|
		# l has \n
		patchlines[l] = (patchlines[l]==nil) ? 1 : patchlines[l]+1
	}
	patchlines.each_key{|l|
		if (patchlines[l]>$PatchDownThreshold) then linesToDelete.push(l) end
	}
	patchupFile = File.read($SpecialIdDir+domain+"/"+url+"/patchup.txt")
	patchlines = Hash.new
	patchupFile.each{|l|
		patchlines[l] = (patchlines[l]==nil) ? 1 : patchlines[l]+1
	}
	patchlines.each_key{|l|
		if (l.index(" => ")==nil) then next end
		if (patchlines[l]>$PatchUpThreshold) then linesToAdd.push(l) end
	}
	if ((!linesToDelete.empty?)||(!linesToAdd.empty?))
		original = File.read($SpecialIdDir+domain+"/"+url+"/"+url+".txt")
		id = 0
		original.each_line{|l|
			cur_id = l.gsub(/\A#?Tag\s(\d+)\s.*/,'\1')
			if (cur_id.to_i>id) then id = cur_id.to_i end
		}
		linesToDelete.each{|l|
			deleteStartPointer = original.index(l)
			deleteEndPointer = original.index("\n",deleteStartPointer)
			#deleteEndPointer = original.index("\n",deleteEndPointer+1)	#delete next line as well.
			original = original[0..deleteStartPointer-1]+"#"+original[deleteStartPointer..deleteEndPointer]+"#"+original[deleteEndPointer+1..original.length]		#Currently it just adds hash to beginning of line.
			patchdownFile.gsub!(l,'')
			#delete all model entries associated with this anchor.
			Dir.glob($PolicyRDir+domain+"/"+url+"/policies/*"){|f|
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
			Dir.glob($PolicyRDir+domain+"/"+url+"/histories/*"){|f|
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
		}
		linesToAdd.each{|l|
			if (l.index(" => ")==nil) then next end
			id += 1
			tagContent = l[0..l.index(" => ")-1]
			vicinityInfo = l[l.index(" => ")+4..l.length]
			original = original + "Tag #{id.to_s} := " + tagContent + "\n&" + vicinityInfo.chomp + "\n"
			patchupFile.gsub!(l,'')
		}
		File.open($SpecialIdDir+domain+"/"+url+"/"+url+".txt","w"){|f| f.write(original)}		#change the anchors de facto
		#we have changed anchors, we need to remove patch recommendations as well.
		File.open($SpecialIdDir+domain+"/"+url+"/patchdown.txt","w"){|f| f.write(patchdownFile)}		#change the patchdown file
		File.open($SpecialIdDir+domain+"/"+url+"/patchup.txt","w"){|f| f.write(patchupFile)}		#change the patchup file
	end
end
