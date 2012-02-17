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

def ExtractPolicyFromFile(rootDir, domain, url)
	policy = Hash.new
	policyFiles = Dir.glob(rootDir+domain+"/"+url+"/*")
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

def CheckModel(record, policyA, policyR, domain, url, id, relative)
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
	accessHashA.each_key{|tld|
		accessHashA[tld].each{|a|
			if (!policyA.has_key? tld)
				#haven't seen any scripts from this domain before
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
					if (!diffArrayR.has_key? tld) 
						diffArrayR[tld] = Array.new
						diffArrayR[tld].push(a)
					else 
						diffArrayR[tld].push(a)
					end
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
			diffAFileHandle.write(tld+"\n")
			diffArrayA[tld].each{|d|
				diffAFileHandle.write(d+"\n")
			}
			diffAFileHandle.write("------------------------\n")
		}
	end
	if ((relative)&&(!diffArrayR.empty?))
		makeDirectory($DiffRDir+domain+"/"+url+"/")
		diffRFileHandle = File.open($DiffRDir+domain+"/"+url+"/diff"+id.to_s+".txt","w")
		diffArrayR.each_key{|tld|
			diffRFileHandle.write(tld+"\n")
			diffArrayR[tld].each{|d|
				diffRFileHandle.write(d+"\n")
			}
			diffRFileHandle.write("------------------------\n")
		}
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
