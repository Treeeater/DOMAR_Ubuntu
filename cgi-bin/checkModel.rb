#!/usr/bin/ruby
require 'fileutils'

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
	policyA = ExtractPolicyFromFile($PolicyADir,domain,url)
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
		if (_wholoc1==nil)
			next
		end
		if (_wholoc2==nil)
			_whatA = line[0.._wholoc1]
			_who = line[_wholoc1+6..line.length]
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
			_whatR = line[0.._wholoc2]
			_whatA = line[_wholoc2+6.._wholoc1]
			_who = line[_wholoc1+6..line.length]
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
					File.open($PolicyADir+domain+"/"+url+"/LIST_"+tld,'a'){|f| f.write(id+"\n")}
					recordedTLD[tld]=true
					#we want to check if we can can build a model for this domain
					list = File.read($PolicyADir+domain+"/"+url+"/LIST_"+tld)
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
					if (!diffArrayA.has_key? tld) 
						diffArrayA[tld] = Array.new
						diffArrayA[tld].push(a)
					else 
						diffArrayA[tld].push(a)
					end
				end
			end
		}
	}
	if (relative)
		accessHashR.each_key{|tld|
			accessHashR[tld].each{|a|
				if (!policyR.has_key? tld)
					#haven't seen any scripts from this domain before
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
					end
				end
			}
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
	if ((relative)&&(!diffArrayR.empty?))
		makeDirectory($DiffRDir+domain+"/"+url+"/")
		diffRFileHandle = File.open($DiffRDir+domain+"/"+url+"/diff"+id.to_s+".txt","w")
		pf = File.open($SpecialIdDir+domain+"/"+url+"/patch.txt","a")
		possiblePatches = Hash.new
		if (File.exists?($AnchorErrorDir + domain + "/" + url + "/error" + id.to_s + ".txt"))
			#if previously we have recorded an error in parsing, now we want to try to handle it.
			efh = File.open($AnchorErrorDir + domain + "/" + url + "/error" + id.to_s + ".txt", "r")
			while (line = efh.gets)
				a = line.index(' => ')
				b = line.index(' ]> ')
				if ((a!=nil)&&(b!=nil))
					possiblePatches[line[a+4..b-1]]=line[b+4..line.length]
				end
			end
			efh.close()
		end
		diffArrayR.each_key{|tld|
			diffRFileHandle.write(tld+"\n")
			makeDirectory($DiffRDir+domain+"/"+url+"/"+tld+"/")
			diffRTLDHandle = File.open($DiffRDir+domain+"/"+url+"/"+tld+"/diff"+id.to_s+".txt","w")
			diffArrayR[tld].each{|d|
				diffRFileHandle.write(d+"\n")
				diffRTLDHandle.write(d+"\n")
				newAnchor = d.gsub(/^\/\/(.*?)[\/\s]/,'\1')		#\s is a bug, but we just get along with it.
				if ((d!=newAnchor)&&(possiblePatches.has_key?(newAnchor)))
					#generate a patch info
					pf.write(newAnchor + " => " + possiblePatches[newAnchor])
				end
			}
			diffRFileHandle.write("------------------------\n")
			diffRTLDHandle.close()
		}
		diffRFileHandle.close()
		pf.close()
	end
end

def AdaptAnchor(domain, url)
	adapted = false
	if (!File.exists?($SpecialIdDir+domain+"/"+url+"/patch.txt")) then return
	end
	patchFile = File.read($SpecialIdDir+domain+"/"+url+"/patch.txt")
	patchlines = Hash.new
	patchFile.each_line{|l|
		# l has \n
		patchlines[l] = (patchlines[l]==nil) ? 1 : patchlines[l]+1
	}
	patchlines.each_key{|l|
		if (patchlines[l]>$PatchThreshold)
			patchlines.delete(l)
			l = l.chomp
			if (l.index("->")==nil) then next end
			if (l.index("=>")==nil) then next end
			specialID = l[0..l.index("->")-1]
			vicinityInfo = l[l.index("=>")+3..l.length]		#no \n in vicinity Info
			anchorFile = File.read($SpecialIdDir+domain+"/"+url+"/"+url+".txt")
			currentDomain = ""
			currentId = ""
			firstLine = ""
			secondLine = ""
			found = false
			anchorFile.each_line{|al|
				al = al.chomp
				if (al[0..7]=="Domain:=") then currentDomain = al[9..al.length] end
				if (al[0..4]=="Tag:=")
					currentId = al.gsub(/.*>(\d+)/,'\1')
					if (currentDomain+currentId==specialID)
						firstLine = al
						found = true
						next
					end
				end
				if ((found)&&(al[0..0]=="&"))
					secondLine = al
					break
				end
			}
			
			anchorFile = anchorFile.sub(firstLine+"\n"+secondLine,firstLine+"\n&"+vicinityInfo)
			File.open($SpecialIdDir+domain+"/"+url+"/"+url+".txt","w"){|f| f.write(anchorFile)}
			adapted = true
		end
	}
	if (adapted)
		#we have changed anchors, we need to remove patch recommendations as well.
		newPatchContent = ""
		patchFile.each_line{|l|
			if (patchlines.has_key?(l))
				newPatchContent = newPatchContent + l
			end
		}
		File.open($SpecialIdDir+domain+"/"+url+"/patch.txt","w"){|f| f.write(newPatchContent)}
	end
end
=begin
record = File.read($RecordDir+"nytimescom/httpwwwnytimescom/record6.txt")
relative = probeXPATH(record)
domain = "nytimescom"
url = "httpwwwnytimescom"
id = 6
policyA = ExtractPolicyFromFile($PolicyADir,domain,url)
policyR = Hash.new
if relative then policyR = ExtractPolicyFromFile($PolicyRDir,domain,url)
end
CheckModel(record, policyA, policyR, domain, url, id, relative)
=end
