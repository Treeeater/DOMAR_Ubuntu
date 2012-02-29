#!/usr/bin/ruby
require 'fileutils'

def getTLD(url)
	domain = url.gsub(/.*?\/\/(.*?)\/.*/,'\1')
	tld = domain.gsub(/.*\.(.*\..*)/,'\1')
	return tld
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
    while (pointer<response.length)
        if ((response[pointer..pointer]!='>')&&(response[pointer..pointer]!='\'')&&(response[pointer..pointer]!='"'))
            pointer+=1
            next
        elsif (response[pointer..pointer]=='>')
            if (fsmcode == 0)
                break
            end
            pointer+=1
            next
        elsif (response[pointer..pointer]=='\'')
            if (fsmcode&2!=0)
                pointer+=1      #opening double quote attr, ignore sq
                next
            end
            fsmcode = 1 - fsmcode       #flip sq status
            pointer += 1
            next
        elsif (response[pointer..pointer]=='"')
            if (fsmcode&1!=0)
                pointer+=1      #opening single quote attr, ignore dq
                next
            end
            fsmcode = 2 - fsmcode       #flip sq status
            pointer += 1
            next
        end         
    end 
    return pointer
end

def findopeninglt(response,pointer)
    fsmcode = 0         # 0 stands for no opening attr, 1 stands for opening single quote attr and 2 stands for opening double quote attr.
    while (pointer<response.length)
        if ((response[pointer..pointer]!='<')&&(response[pointer..pointer]!='\'')&&(response[pointer..pointer]!='"'))
            pointer-=1
            next
        elsif (response[pointer..pointer]=='<')
            if (fsmcode == 0)
                break
            end
            pointer-=1
            next
        elsif (response[pointer..pointer]=='\'')
            if (fsmcode&2!=0)
                pointer-=1      #opening double quote attr, ignore sq
                next
            end
            fsmcode = 1 - fsmcode       #flip sq status
            pointer -= 1
            next
        elsif (response[pointer..pointer]=='"')
            if (fsmcode&1!=0)
                pointer-=1      #opening single quote attr, ignore dq
                next
            end
            fsmcode = 2 - fsmcode       #flip sq status
            pointer -= 1
            next
        end         
    end 
    return pointer
end

def learnTextPattern(traffic, specialIds, textPattern)
	specialIds.each_key{|k|
		if (textPattern[k]==nil)
			textPattern[k]=Array.new
		end
		specialIds[k].each{|id|
			attrIndex = traffic.index(/specialId\s=\s\'#{id}\'/)
			closinggt = findclosinggt(traffic, attrIndex)
			openinglt = findopeninglt(traffic, attrIndex)
			tagInfo = traffic[openinglt..closinggt].gsub(/\sspecialId\s=\s\'.*?\'/,'')
			vicinityInfo = (traffic[closinggt+1,100].gsub(/\sspecialId\s=\s\'.*?\'/,'').gsub(/[\r\n]/,''))[0..30]
			if (!$checked.include?(tagInfo + vicinityInfo))
				textPattern[k].push( [ tagInfo , vicinityInfo ] )
				$checked.push(tagInfo+vicinityInfo)
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

def extractTextPattern(trafficFile,recordFile,outputFileName)
	textPattern = Hash.new
	trafficFile.each_index{|i|
		traffic = File.read(trafficFile[i])
		record = File.read(recordFile[i])
		result = identifyId(traffic,record)
		textPattern = learnTextPattern(traffic,result,textPattern)
	}
	prepareDirectory(outputFileName[0..outputFileName.rindex('/')])
	#p result
	#p textPattern
	fh = File.new(outputFileName,'w')
	i = 0
	textPattern.each_key{|k|
		#fh.write("Domain:= "+k)
		textPattern[k].each_index{|id|
			i+=1
			fh.write("Tag ")
			fh.write(i.to_s)
			fh.write(" := "+textPattern[k][id][0]+"\n")
			fh.write("&"+textPattern[k][id][1].to_s)
			fh.write("\n")
		}
		#fh.write("\n-----\n")
	}
end
$checked = Array.new
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
