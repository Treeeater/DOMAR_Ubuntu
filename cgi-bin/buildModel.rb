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
	trainingDataIndices = trainingDataIndices.sort_by{|a| File.mtime($RecordDir + url + "/" + domain + "/record"+a+".txt")}		#sort by modifying time
	trainingDataIndices.each{|t|
		files.push($RecordDir + url + "/" + domain + "/record"+t+".txt")
	}
	files.each{|fileName|
		mTime = File.mtime(fileName)
		id = fileName.gsub(/.*\/record(\d+)\.txt$/,'\1')
		f = File.open(fileName, 'r')
		while (line = f.gets)
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
					accessHashA[_tld] = Hash.new
				end
				#If we want to care about the number of accesses of each node, we uncomment the next line and make necessary changes
				#accessHash[_tld][_what] = (accessHash[_tld][_what]==nil) ? 1 : accessHash[_tld][_what]+1
				if (!accessHashA[_tld].has_key? _whatA)
					accessHashA[_tld][_whatA] = {:mtime=>mTime,:id=>id}
				end
				if (line[0]!='/')
					#not DOM node access, but we still need to push it to relative model.
					if (accessHashR[_tld]==nil)
						accessHashR[_tld] = Hash.new
					end
					if (!accessHashR[_tld].include? _whatA)
						accessHashR[_tld][_whatA] = {:mtime=>mTime,:id=>id}
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
					accessHashR[_tld] = Hash.new
				end
				if (accessHashA[_tld]==nil)
					accessHashA[_tld] = Hash.new
				end
				if (!accessHashR[_tld].has_key? _whatR)
					accessHashR[_tld][_whatR] = {:mtime=>mTime,:id=>id}
				end
				if (!accessHashA[_tld].has_key? _whatA)
					accessHashA[_tld][_whatA] = {:mtime=>mTime,:id=>id}
				end
			end
		end
		f.close()
	}
	p "done learning basic model."
=begin
	#sort accessHash in an alphebatically order
	accessHashA.each_key{|_tld|
		accessHashA[_tld] = accessHashA[_tld].sort
	}
	accessHashR.each_key{|_tld|
		accessHashR[_tld] = accessHashR[_tld].sort
	}
	p "done sorting all tlds."
=end
	temp = ExtractedRecords.new(accessHashR, accessHashA)
	return temp
end

def exportPolicy(extractedRecords, url, domain, targetDomain=nil)
	#model building part we only record one access entry (the earliest one).
	pFolderA = $PolicyADir + url + "/" + domain + "/policies/"
	pFolderR = $PolicyRDir + url + "/" + domain + "/policies/"
	pFolderHistoryA = $PolicyADir + url + "/" + domain + "/histories/"
	pFolderHistoryR = $PolicyRDir + url + "/" + domain + "/histories/"
	makeDirectory(pFolderA)
	makeDirectory(pFolderR)
	makeDirectory(pFolderHistoryA)
	makeDirectory(pFolderHistoryR)
	accessArrayA = extractedRecords.recordsA
	if (targetDomain==nil)
		accessArrayA.each_key{|tld|
			f = File.open(pFolderA+tld+".txt","w")
			fHistory = File.open(pFolderHistoryA+tld+".txt","w")
			accessArrayA[tld].each_key{|xpath|
				f.puts(xpath)#+"|:=>"+accessArray[tld][xpath].to_s)
				fHistory.puts(xpath+"\n->Time Added:"+accessArrayA[tld][xpath][:mtime].to_s+"\n->Traffic ID:"+accessArrayA[tld][xpath][:id]+"\n->Time Deleted:\n->Accessed Entries:"+accessArrayA[tld][xpath][:id]+"\n\n")
			}
			f.close()
			fHistory.close()
		}
	else
		if (accessArrayA[targetDomain]!=nil)
			f = File.open(pFolderA+targetDomain+".txt","w")
			fHistory = File.open(pFolderHistoryA+targetDomain+".txt","w")
			accessArrayA[targetDomain].each_key{|xpath|
				f.puts(xpath)
				fHistory.puts(xpath+"\n->Time Added:"+accessArrayA[targetDomain][xpath][:mtime].to_s+"\n->Traffic ID:"+accessArrayA[targetDomain][xpath][:id]+"\n->Time Deleted:\n->Accessed Entries:"+accessArrayA[targetDomain][xpath][:id]+"\n\n")
			}
			f.close()
			fHistory.close()
		end
	end

	accessArrayR = extractedRecords.recordsR
	if (targetDomain==nil)
		accessArrayR.each_key{|tld|
			f = File.open(pFolderR+tld+".txt","w")
			fHistory = File.open(pFolderHistoryR+tld+".txt","w")
			accessArrayR[tld].each_key{|xpath|
				f.puts(xpath)#+"|:=>"+accessArray[tld][xpath].to_s)
				fHistory.puts(xpath+"\n->Time Added:"+accessArrayR[tld][xpath][:mtime].to_s+"\n->Traffic ID:"+accessArrayR[tld][xpath][:id]+"\n->Time Deleted:\n->Accessed Entries:"+accessArrayR[tld][xpath][:id]+"\n\n")
			}
			f.close()
			fHistory.close()
		}
	else
		if (accessArrayR[targetDomain]!=nil)
			f = File.open(pFolderR+targetDomain+".txt","w")
			fHistory = File.open(pFolderHistoryR+targetDomain+".txt","w")
			accessArrayR[targetDomain].each_key{|xpath|
				f.puts(xpath)
				fHistory.puts(xpath+"\n->Time Added:"+accessArrayR[targetDomain][xpath][:mtime].to_s+"\n->Traffic ID:"+accessArrayR[targetDomain][xpath][:id]+"\n->Time Deleted:\n->Accessed Entries:"+accessArrayR[targetDomain][xpath][:id]+"\n\n")
			}
			f.close()
			fHistory.close()
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
