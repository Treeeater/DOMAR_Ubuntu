#!/usr/bin/ruby

require 'fileutils'

#$RecordDir = "/home/yuchen/Desktop/DOMAR/records/"
#$PolicyADir = "/home/yuchen/Desktop/DOMAR/policyA/"
#$PolicyRDir = "/home/yuchen/Desktop/DOMAR/policyR/"

class ExtractedRecords
	attr_accessor :recordsR, :recordsA
	def initialize(recordsR, recordsA)
		@recordsR = recordsR
		@recordsA = recordsA
	end
end

def getTLD(url)
	domain = url.gsub(/.*?\/\/(.*?)\/.*/,'\1')
	tld = domain.gsub(/.*\.(.*\..*)/,'\1')
	return tld
end

def probeXPATH(hostD)
	files = Dir.glob(hostD+"*")
	return File.read(files[0]).include?("<=:| ")
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

def prepareDirectory(param)
	#cleans everything in param directory! Use extreme caution!
	if File.directory?(param)
		#clean the dir
		Dir.foreach(param) do |f|
			if f == '.' or f == '..' then next 
			elsif File.directory?(param+f) then FileUtils.rm_r(param+f)      
			else FileUtils.rm(param+f)
			end
		end 
	else
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

def extractRecordsFromTrainingData(url, domain, trainingDataIndices)
# This function extracts data from files to an associative array randomly, given the P_inst.
	accessHashA = Hash.new
	accessHashR = Hash.new
	#rFolder = $RecordDir + url + "/" + domain + "/"
	#files = Dir.glob(rFolder+"*")
	files = Array.new
	trainingDataIndices.each{|t|
		files.push($RecordDir + url + "/" + domain + "/record"+t+".txt")
	}
	files.each{|fileName|
		f = File.open(fileName, 'r')
		while (line = f.gets)
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
		end
		f.close()
	}
	p "done learning basic model."
	#sort accessHash in an alphebatically order
	accessHashA.each_key{|_tld|
		accessHashA[_tld] = accessHashA[_tld].sort
	}
	accessHashR.each_key{|_tld|
		accessHashR[_tld] = accessHashR[_tld].sort
	}
	p "done sorting all tlds."
	temp = ExtractedRecords.new(accessHashR, accessHashA)
	return temp
end

def exportPolicy(extractedRecords, url, domain, targetDomain=nil)
	pFolderA = $PolicyADir + url + "/" + domain + "/policies/"
	pFolderR = $PolicyRDir + url + "/" + domain + "/policies/"
	makeDirectory(pFolderA)
	makeDirectory(pFolderR)
	accessArrayA = extractedRecords.recordsA
	if (targetDomain==nil)
		accessArrayA.each_key{|tld|
			f = File.open(pFolderA+tld+".txt","w")
			accessArrayA[tld].each{|xpath|
				f.puts(xpath)#+"|:=>"+accessArray[tld][xpath].to_s)
			}
			f.close()
		}
	else
		if (accessArrayA[targetDomain]!=nil)
			f = File.open(pFolderA+targetDomain+".txt","w")
			accessArrayA[targetDomain].each{|xpath|
				f.puts(xpath)#+"|:=>"+accessArray[tld][xpath].to_s)
			}
			f.close()
		end
	end

	accessArrayR = extractedRecords.recordsR
	if (targetDomain==nil)
		accessArrayR.each_key{|tld|
			f = File.open(pFolderR+tld+".txt","w")
			accessArrayR[tld].each{|xpath|
				f.puts(xpath)#+"|:=>"+accessArray[tld][xpath].to_s)
			}
			f.close()
		}
	else
		if (accessArrayR[targetDomain]!=nil)
			f = File.open(pFolderR+targetDomain+".txt","w")
			accessArrayR[targetDomain].each{|xpath|
				f.puts(xpath)#+"|:=>"+accessArray[tld][xpath].to_s)
			}
			f.close()
		end
	end
end

def BuildModel(url, domain, targetDomain, trainingDataIndices)
	extractedRecords = extractRecordsFromTrainingData(url, domain, trainingDataIndices)
	exportPolicy(extractedRecords, url, domain, targetDomain)
=begin
	extractedRecords.recordsA.each_key{|tld|
		tempModel = buildStrictModel(extractedRecords.recordsA[tld], tld) 	#strictest model is actually just extractedRecord
	}
	if (relativeXPATH)
		extractedRecords.recordsR.each_key{|tld|
			tempModel = buildStrictModel(extractedRecords.recordsR[tld], tld) 	#strictest model is actually just extractedRecord
		}
	end
=end
end

#BuildModel("nytimescom","httpwwwnytimescom")
