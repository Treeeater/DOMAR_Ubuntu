#!/usr/bin/ruby
require 'fileutils'

$checked = Hash.new

def getTLD(url)
	url.gsub!(/^(.*?)>.*/,'\1')
	domain = url.gsub(/.*?\/\/(.*?)\/.*/,'\1')
	tld = domain.gsub(/.*\.(.*\..*)/,'\1')
	return tld
end

def LookupURLStructure(url,domain)
	if (!File.exists?($GroupingDir+domain+"/list.txt")) then return nil end
	grouping_info = File.open($GroupingDir+domain+"/list.txt","r")
	while (line = grouping_info.gets)	
		if (line =~ /#{Regexp.quote(url)}\s.*/)
			category = line.chomp.gsub(/.*\s(.*)/,'\1')
			return category
		end
	end
	return nil
end

def extractURLStructure(url)
	#for example, let's say the url at here is http://www.nytimes.com/2012/01/03/sdfi-wer-qasdf-df.html
	protocol = url.gsub(/(.*?):\/\/.*/,'\1')	#get the protocol, normally it would be http
	url = url[protocol.length+3..-1]		#skip the ://, url becomes www.nytimes.com/2012/01/03/sdfi-wer-qasdf-df.html
	domainName = url.gsub(/(.*?)\/.*/,'\1')
	url = url[domainName.length+1..-1]		#skip the second /, url becomes 2012/01/03/sdfi-wer-qasdf-df.html
	subPathArray = url.split('/')
	subPathArrayType = Array.new
	subPathArray.each{|path|
		isEmpty = (path=="")
		if (isEmpty)
			next
		end
		isIndex = ((path =~ /\Aindex\./)!=nil)
		if (isIndex)
			subPathArrayType.push("id")
			next
		end
		isPureWord = ((path =~ /[^a-zA-Z]/)==nil)
		if (isPureWord)
			subPathArrayType.push("pw")
			next
		end
		isPureNumber = ((path =~ /\D/)==nil)
		if (isPureNumber)
			subPathArrayType.push("pn")
			next
		end
		isNonWord = ((path =~ /[a-zA-Z]/)==nil)
		if (isNonWord)
			subPathArrayType.push("nw")
			next
		end
		isNonNumber = ((path =~ /\d/)==nil)
		if (isNonNumber)
			subPathArrayType.push("nn")
			next
		end
		subPathArrayType.push("dk")		#don't know
	}
	return protocol + "_" + domainName + "_" + subPathArrayType.join("_")
end

def identifyId(traffic, record)
	#takes a traffic string and a record string, return an associative array containing domains as keys and an array of 'root' nodes associated with them.
	result = Hash.new
	record.each_line {|r|
		r=r.chomp
		if (r[0..1]=="//")
			url = ""
			if (r.index("<=|:|")==nil)
				url = r[r.index("|:=>")+5..r.length-1]
			else
				url = r[r.index("|:=>")+5..r.index("<=|:|")-2]
			end
			specialId = r.gsub(/^\/\/(\d+?)[\s\/].*/m,'\1')
			domain = getTLD(url)
			if (result.has_key? domain)
				result[domain].push(specialId)
			else
				result[domain] = Array.new
				result[domain].push(specialId)
			end
		end
	}
	result.each_key{|k|
		result[k] = result[k].uniq
	}
	#done getting all specialId touched
	#document = Hpricot(traffic)
	#document = Nokogiri::HTML(traffic)
=begin
	result.each_key{|k|
		result[k].each{|id|
			elem = document.search("//*[@specialid='#{id}']")[0]
			if (elem.elem?)
				elemp = elem.parent
				while (elemp!=nil)&&(elemp.elem?)
					includedId = elemp.get_attribute('specialid')
					result[k].delete(includedId)
					elemp = elemp.parent
				end
			end
		}
	}
=end
	return result
end

def findclosinggt(response,pointer)
    fsmcode = 0         # 0 stands for no opening attr, 1 stands for opening single quote attr and 2 stands for opening double quote attr.
    l = response.length
    while (pointer<l)
        if ((response[pointer]!=62)&&(response[pointer]!=39)&&(response[pointer]!=34))
            pointer+=1
            next
        elsif (response[pointer]==62)	#>
            if (fsmcode == 0)
                break
            end
            pointer+=1
            next
        elsif (response[pointer]==39)	#'
            if (fsmcode&2!=0)
                pointer+=1      #opening double quote attr, ignore sq
                next
            end
            fsmcode = 1 ^ fsmcode       #flip sq status
            pointer += 1
            next
        elsif (response[pointer]==34)	#"
            if (fsmcode&1!=0)
                pointer+=1      #opening single quote attr, ignore dq
                next
            end
            fsmcode = 2 ^ fsmcode       #flip dq status
            pointer += 1
            next
        end         
    end 
    return pointer
end

def findopeninglt(response,pointer)
    fsmcode = 0         # 0 stands for no opening attr, 1 stands for opening single quote attr and 2 stands for opening double quote attr.
    l = response.length
    while (pointer<l)
        if ((response[pointer]!=60)&&(response[pointer]!=39)&&(response[pointer]!=34))
            pointer-=1
            next
        elsif (response[pointer]==60)
            if (fsmcode == 0)
                break
            end
            pointer-=1
            next
        elsif (response[pointer]==39)
            if (fsmcode&2!=0)
                pointer-=1      #opening double quote attr, ignore sq
                next
            end
            fsmcode = 1 ^ fsmcode       #flip sq status
            pointer -= 1
            next
        elsif (response[pointer]==34)
            if (fsmcode&1!=0)
                pointer-=1      #opening single quote attr, ignore dq
                next
            end
            fsmcode = 2 ^ fsmcode       #flip dq status
            pointer -= 1
            next
        end         
    end 
    return pointer
end

def learnTextPattern(traffic, specialIds, textPattern, srcURL)
	specialIds.each_key{|k|
		specialIds[k].each{|id|
			attrIndex = traffic.index(/specialId\s=\s\'#{id}\'/)
			closinggt = findclosinggt(traffic, attrIndex)
			openinglt = findopeninglt(traffic, attrIndex)
			tagInfo = traffic[openinglt..closinggt].gsub(/\sspecialId\s=\s\'.*?\'/,'')
			vicinityInfo = (traffic[closinggt+1,100].gsub(/\sspecialId\s=\s\'.*?\'/,'').gsub(/[\r\n]/,''))[0..30]
			if ($standalonePage)
				if (!textPattern.include?([tagInfo, vicinityInfo]))
					textPattern.push([tagInfo, vicinityInfo])
				end
			else
				if (!$checked.has_key?(tagInfo + vicinityInfo))
					$checked[tagInfo+vicinityInfo] = srcURL
				else
					if ($checked[tagInfo+vicinityInfo] != srcURL)&&(!textPattern.include?([tagInfo, vicinityInfo]))
						textPattern.push([tagInfo, vicinityInfo])
					end
				end
			end
		}
	}
	return textPattern
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

def extractTextPattern(trafficFile,recordFile,outputFileName,recordDomain,urlStructure)
	textPattern = Array.new
	#automatically judge if this is a standalone page by looking at if all the urls are the same in the training data.
	tempurl = nil
	$standalonePage = true
	trafficFile.each{|t|
		if (t.index('?')==nil) then next end
		url = t.gsub(/.*\/(.*)\?.*/,'\1')
		if (tempurl == nil)
			tempurl = url
			next
		end
		if (tempurl!=url)
			$standalonePage = false
		end
	}
	#write this information to hard drive so that when we update the anchors, we look up the table to find if this group is a standalone group
	makeDirectory($StandaloneDir)
	File.open($StandaloneDir + recordDomain + ".txt","a"){|f| f.write(urlStructure+" "+$standalonePage.to_s+"\n")}
	trafficFile.each_index{|i|
		traffic = File.read(trafficFile[i])
		record = File.read(recordFile[i])
		result = identifyId(traffic,record)
		srcURL = (trafficFile[i])[0..trafficFile[i].index('?')-1]
		textPattern = learnTextPattern(traffic,result,textPattern,srcURL)
	}
	prepareDirectory(outputFileName[0..outputFileName.rindex('/')])
	#p result
	#p textPattern
	fh = File.new(outputFileName,'w')
	i = 0
	textPattern.each_index{|id|
		#fh.write("Domain:= "+k)
		fh.write("Tag ")
		fh.write(id.to_s)
		fh.write(" := "+textPattern[id][0]+"\n")
		fh.write("&"+textPattern[id][1].to_s)
		fh.write("\n")
		#fh.write("\n-----\n")
	}
end
=begin
outputFileName = "httpwwwnytimescom.txt"
trafficInputs = Array.new
recordInputs = Array.new
trafficInputs.push("traffic.txt")
recordInputs.push("record.txt")
trafficInputs.push("httpwwwnytimescom1500.txt")
recordInputs.push("record836.txt")
extractTextPattern(trafficInputs, recordInputs, PolicyDir + outputFileName)
=end
#extractTextPattern(TrafficDir+"traffic_techcrunch_item.txt",RecordsDir+"record_techcrunch_item.txt",PolicyDir+"httptechcrunchcom20120202visualizingfacebooksmediastorehowbigis100petabytes.txt")
