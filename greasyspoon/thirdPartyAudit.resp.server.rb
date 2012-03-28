#rights=ADMIN
#--------------------------------------------------------------------
#
#This is a GreasySpoon script.
#
#To install, you need :
#   -jruby
#   -hpricot library
#--------------------------------------------------------------------
#
#WHAT IT DOES:
#
#http://www.google.fr:
#   - show ref links as html tag
#
#--------------------------------------------------------------------
#
#==ServerScript==
#@status on
#@name            ThirdPartyAudit
#@order 0
#@description     ThirdPartyAudit
#@include       .*
#==/ServerScript==
#
require 'rubygems'
require 'hpricot'
#require 'digest/md5'
#require 'net/http'
#require 'uri'
#require 'pp'

#Available elements provided through ICAP server
#puts "---------------"
#puts "HTTP request header: #{$requestheader}"
#puts "HTTP request body: #{$httprequest}"
#puts "HTTP response header: #{$responseheader}"
#puts "HTTP response body: #{$httpresponse}"
#puts "user id (login in most cases): #{$user_id}"
#puts "user name (CN  provided through LDAP): #{$user_name}"
#puts "---------------"

$HomeFolder = "/home/yuchen"
$PolicyADir = "#{$HomeFolder}/Desktop/DOMAR/policyA/"
$PolicyRDir = "#{$HomeFolder}/Desktop/DOMAR/policyR/"
$DiffADir = "#{$HomeFolder}/Desktop/DOMAR/diffA/"
$DiffRDir = "#{$HomeFolder}/Desktop/DOMAR/diffR/"
$AnchorDir = "#{$HomeFolder}/Desktop/DOMAR/anchors/"
$RecordDir = "#{$HomeFolder}/Desktop/DOMAR/records/"
$PreferenceList = "#{$HomeFolder}/Desktop/DOMAR/DOMAR_preference.txt"
$PreferenceListDir = "#{$HomeFolder}/Desktop/DOMAR/site_preferences/trusted_sites/"
$StandaloneDir = "#{$HomeFolder}/Desktop/DOMAR/site_preferences/grouping_info/"
$GroupingDir = "#{$HomeFolder}/Desktop/DOMAR/grouping_info/"
$SpecialIdDir = "#{$HomeFolder}/Desktop/DOMAR/specialID/"
$TrafficDir = "#{$HomeFolder}/Desktop/DOMAR/traffic/"
$AnchorErrorDir = "#{$HomeFolder}/Desktop/DOMAR/anchorErrors/"
$ModelThreshold = 100
$AnchorThreshold = 50
$AnchorLength = 50
$TrainNewAnchors = true
$DF = "/home/yuchen/success"		#debug purposes

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

def injectFFReplace(response,domain,filecnt)
=begin
	if (!File.exists? $PreferenceList)
		p "no preference file."
		return response
	end
	operatingList = File.read($PreferenceList)
	if (operatingList.index(domain)==nil)
		p "not in the mediation list"
		return response
	end
=end
	trustedDomains = Array.new
	if (File.exists?($PreferenceListDir+domain.gsub(/\./,'')+".txt"))
		fh = File.open($PreferenceListDir+domain.gsub(/\./,'')+".txt",'r')
		while (line = fh.gets)
			trustedDomains.push(line.chomp)
		end
	end
	#p trustedDomains
	lowerResponse = response.downcase
	insertIndex = lowerResponse.index('<head')
	if (insertIndex == nil) 
		insertIndex = lowerResponse.index('<body')
	end
	insertIndex = lowerResponse.index('>',insertIndex);
	total = ""
	if (insertIndex != nil)
		headpos = insertIndex+1
		firstportion = response[0..headpos]
		lastportion = response[headpos..response.length]
		middleportion = "<script src='http://chromium.cs.virginia.edu:12348/FFReplace_simpl.js'></script><script>"
		while (!trustedDomains.empty?)
			middleportion = middleportion + "__record().Push(\"" + trustedDomains.pop().to_s + "\");\n"
		end
		middleportion = middleportion + "__record().Push(\"chromium.cs.virginia.edu:12348\");"
		middleportion = middleportion + "__record().setId(\"#{filecnt.to_s}\");</script>"
		total = firstportion+middleportion+lastportion
	end
	return total
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

def collectTextPattern(url,host)
	if (File.exists? $SpecialIdDir+host+"/"+url+"/" + url + ".txt")
		return File.read($SpecialIdDir+host+"/"+url+"/" + url + ".txt")
	end
	return nil
end

def approxmatching(a,b)
	return (a==b)
end

def convertResponse(response, textPattern, url, filecnt, urlStructure)
	listToAdd = Hash.new
	vicinityList = Hash.new
	recordedVicinity = Hash.new
	processedNodes = Hash.new
	id = ""
	error = false
	errormsg = ""
	#sanitizedurl = url.gsub(/[^a-zA-Z0-9]/,"")
    	sanitizedhost = getTLD(url)
	sanitizedhost = sanitizedhost.gsub(/[^a-zA-Z0-9]/,"")
	while (textPattern!="")&&(textPattern!=nil)
		startingPointer = textPattern.index("{zyczyc{Tag ")
		middlePointer = textPattern.index("}zyczyc{")
		endPointer = textPattern.index("}zyczyc}\n")
		if (startingPointer==nil)||(middlePointer==nil)||(endPointer==nil) then return end
		matches = false
		thisinfo = textPattern[startingPointer..endPointer+8]
		textPattern = textPattern[endPointer+9..-1]
		id = thisinfo.gsub(/\{zyczyc\{Tag\s(\d+)\s:=.*/m,'\1')
		processedNodes[id]=thisinfo
		toMatch = thisinfo.gsub(/.*?\{zyczyc\{Tag\s\d+\s:=\s(.*?)\}zyczyc\{.*/m,'\1')
		matchpoints = response.enum_for(:scan,toMatch).map{Regexp.last_match.begin(0)}
		File.open($DF,"a"){|f| f.write(toMatch + "||number||" + matchpoints.size.to_s+"\n")}
		i = 0
		while (i<matchpoints.size)
			matches = true
			listToAdd[id] = (listToAdd[id]==nil) ? Array.new([matchpoints[i]+toMatch.length-1]) : listToAdd[id].push(matchpoints[i]+toMatch.length-1)
			vicinityInfo = (response[matchpoints[i]+toMatch.length,100].gsub(/[\r\n]/,''))[0..$AnchorLength]
			vicinityList[id] = (vicinityList[id]==nil) ? Array.new([vicinityInfo]) : vicinityList[id].push(vicinityInfo)
			i+=1
		end
		if (matches==false)
			File.open($SpecialIdDir+sanitizedhost+"/"+urlStructure+"/patchdown.txt","a"){|f| f.write(thisinfo)}
			error = true
			errormsg += "failed to find a match for "+toMatch+"\n"
		end
		recordedVicinity[id] = thisinfo.gsub(/.*?\}zyczyc\{(.*)\}zyczyc\}.*/m,'\1')		#if we want to extract children informatio
	end
	vicinityList.each_key{|id|
		if (vicinityList[id].length>1)
			found = 0
			candidates = Array.new
			candidatesVicinity = Array.new
			vicinityList[id].each_index{|i|
				if (approxmatching(vicinityList[id][i],recordedVicinity[id]))
					candidates.push(listToAdd[id][i])
					candidatesVicinity.push(vicinityList[id][i])
					#listToAdd[id]=Array.new([listToAdd[id][i]])
					found += 1
				end
			}
			if (found == 1)
				#we have found this is the only one that matches.
				listToAdd[id]=candidates.clone		#candidates only have one element - the correct one.
			elsif (found == 0)
				listToAdd.delete(id)
				File.open($SpecialIdDir+sanitizedhost+"/"+urlStructure+"/patchdown.txt","a"){|f| f.write(processedNodes[id])}
				error = true
				errormsg += "multiple matches found for: "+ id + ", but no vicinity matches original model.\n"
				p errormsg
			elsif (found > 1)
				listToAdd.delete(id)				#remove the original item
				File.open($SpecialIdDir+sanitizedhost+"/"+urlStructure+"/patchdown.txt","a"){|f| f.write(processedNodes[id])}
				error = true
				errormsg += "multiple matches found for: "+ id + ", because more than 1 vicinity matches original model. found a total of "+found.to_s+" matches.\n"
				p errormsg
			end
		end
	}
	needToCheckPatchDown = false
	patchDownContent = 0
	modifiedContent = 0
	if (File.exists?($SpecialIdDir+sanitizedhost+"/"+urlStructure+"/patchdown.txt"))
		patchDownContent = File.read($SpecialIdDir+sanitizedhost+"/"+urlStructure+"/patchdown.txt")
		modifiedContent = patchDownContent.clone
		needToCheckPatchDown = true
	end
	listToAdd.each_key{|id|
		index = listToAdd[id][0]
		content = " specialId = \'id#{id}\'"
		response = response.insert(index, content)
		listToAdd.each_key{|i|
			#N squared time complexity, we could definitely optimize this thing but I don't do it now.
			if (listToAdd[i][0] > listToAdd[id][0])
				listToAdd[i][0]+=content.length
			end
		}
		#We want to remove all entries in patchdown.txt if we have seen this id reappears
		if (needToCheckPatchDown)
			patchDownContent.each_line{|l|
				if (l.index("Tag #{id} :")!=nil)
					modifiedContent.slice!(l)
				end
			}
		end
	}
	if (needToCheckPatchDown) then File.open($SpecialIdDir+sanitizedhost+"/"+urlStructure+"/patchdown.txt","w"){|f| f.write(modifiedContent)} end
	#p vicinityList
	#p recordedVicinity	
	if (error)
		logfh = File.open("/home/yuchen/errorlog.txt","a")
		logfh.write("error when converting url: #{url}, id: #{filecnt}.\n")
		logfh.write(errormsg)
		logfh.close
	end
	return response
end

def universalTraining(response)
    globalNodeIdCount = 0
    pointer = 0
    heuristics = true
    startingTag = response.index('<',pointer)
    while (startingTag!=nil)
        pointer = startingTag+1
        while (response[pointer..pointer]==" ") 
            pointer+=1                          #skip spaces
        end
        if (response[pointer..pointer]=='/')                    #skip closing tags
            startingTag = response.index('<',pointer)
            next
        end
        if (response[pointer..pointer+7].casecmp('!doctype')==0)              #skip doctype declarations
            startingTag = response.index('>',pointer)               #assuming no greater than in DOCTYPE declaration.
            startingTag = response.index('<',startingTag)
            next
        end
        if (response[pointer..pointer+2]=='!--')                    #skip comment nodes
            startingTag = response.index('-->',pointer)
            startingTag = response.index('<',startingTag)
            next
        end
        if (response[pointer..pointer+5].casecmp('script')==0)              #skip chunks of scripts
            pointer = findclosinggt(response,pointer)
            if (response[pointer-1..pointer-1]=='/') 
                #self closing script tag, we don't need to worry about this.
                startingTag = response.index('<',pointer)
                next
            end
            #not self closing script tag, we need to find </script>
            pointer = response.downcase.index('</scr'+'ipt>',pointer) + 1
            startingTag = response.index('<',pointer)
            next
        end
	#heuristics to add html, head, title and body as id100000 id200000 id300000 and id400000
	#there should be only one of these tags existing in a webpage. (assumption)
	if (heuristics)
		if (response[pointer..pointer+3].casecmp('html')==0)
			startingPointer = pointer
			pointer = findclosinggt(response,pointer)
			if (response[pointer-1..pointer-1]=='/') 
				response = response[0..pointer-2] + " specialId = \'id100000\'" + response[pointer-1..-1]
			else
				response = response[0..pointer-1] + " specialId = \'id100000\'" + response[pointer..-1]
			end
			startingTag = response.index('<',pointer)
			next
		end
		if (response[pointer..pointer+3].casecmp('head')==0)
			startingPointer = pointer
			pointer = findclosinggt(response,pointer)
			if (response[pointer-1..pointer-1]=='/') 
				response = response[0..pointer-2] + " specialId = \'id200000\'" + response[pointer-1..-1]
			else
				response = response[0..pointer-1] + " specialId = \'id200000\'" + response[pointer..-1]
			end
			startingTag = response.index('<',pointer)
			next
		end
		if (response[pointer..pointer+4].casecmp('title')==0)
			startingPointer = pointer
			pointer = findclosinggt(response,pointer)
			if (response[pointer-1..pointer-1]=='/') 
				response = response[0..pointer-2] + " specialId = \'id300000\'" + response[pointer-1..-1]
			else
				response = response[0..pointer-1] + " specialId = \'id300000\'" + response[pointer..-1]
			end
			startingTag = response.index('<',pointer)
			next
		end
		if (response[pointer..pointer+3].casecmp('body')==0)
			startingPointer = pointer
			pointer = findclosinggt(response,pointer)
			if (response[pointer-1..pointer-1]=='/') 
				response = response[0..pointer-2] + " specialId = \'id400000\'" + response[pointer-1..-1]
			else
				response = response[0..pointer-1] + " specialId = \'id400000\'" + response[pointer..-1]
			end
			startingTag = response.index('<',pointer)
			heurstics = false		#faster performance
			next
		end
	end
	#end heuristics
        #we need to add special attrs, now we should find the closing greater than for this opening tag.
        #dealing with '>' in attrs.
	startingPointer = pointer
        pointer = findclosinggt(response,pointer)
	if (response[startingPointer..pointer].index('specialId')!=nil)	#skip the nodes that are already marked.
		startingTag = response.index('<',pointer)
		next
	end
        globalNodeIdCount+=1
        if (response[pointer-1..pointer-1]=='/') 
            response = response[0..pointer-2] + " specialId = \'" + globalNodeIdCount.to_s + "\'" + response[pointer-1..response.length-1]      #self closing tags
        else 
            response = response[0..pointer-1] + " specialId = \'" + globalNodeIdCount.to_s + "\'" + response[pointer..response.length-1]
        end
        startingTag = response.index('<',pointer)
    end
    return response
end


def process(response, url, host)
    #puts url
    #puts host
    url = url[0..240]		#file length restriction, 255 is maximum, we want to reserve for id and '.txt.'
    if (url.index('?')!=nil) then url = url[0..url.index('?')-1] end
    puts "Begin to parse "+url
    sanitizedurl = url.gsub(/[^a-zA-Z0-9]/,"")
    sanitizedhost = getTLD(url)
    filecnt = 1
    mediate = true
    if (!File.exists? $PreferenceList)
	p "no preference file."
	mediate = false
    end
    operatingList = File.read($PreferenceList)
    if (operatingList.index(sanitizedhost)==nil)
	p "not in the mediation list"
	mediate = false
    end
    #urlStructure = extractURLStructure(url)
    if (mediate)
	    sanitizedhost = sanitizedhost.gsub(/[^a-zA-Z0-9]/,"")		#get rid of the dot.
	    makeDirectory($GroupingDir+sanitizedhost+"/")
	    urlStructure = LookupURLStructure(url,sanitizedhost)
	    if (urlStructure==nil)
		#no grouping information for this page, we skip it.
		File.open($GroupingDir+sanitizedhost+"/request.txt","a"){|f| f.write(url+"\n")}		#debug purposes
		urlStructure = "not_grouped"
	    end
	    if (!File.directory? $TrafficDir)
		Dir.mkdir($TrafficDir,0777)
	    end
	    if (!File.directory? $TrafficDir+sanitizedhost)
		Dir.mkdir($TrafficDir+sanitizedhost,0777)
	    end
	    if (!File.directory? $TrafficDir+sanitizedhost+"/"+urlStructure)
		Dir.mkdir($TrafficDir+sanitizedhost+"/"+urlStructure,0777)
	    end
=begin
	    if (!File.directory? $RecordDir)
		Dir.mkdir($RecordDir,0777)
	    end
	    if (!File.directory? $RecordDir+sanitizedhost)
		Dir.mkdir($RecordDir+sanitizedhost,0777)
	    end
	    if (!File.directory? $RecordDir+sanitizedhost+"/"+urlStructure)
		Dir.mkdir($RecordDir+sanitizedhost+"/"+urlStructure,0777)
	    end
=end
	    while (File.exists? $TrafficDir+"#{sanitizedhost}/#{urlStructure}/#{sanitizedurl}?"+filecnt.to_s+".txt")
	    	filecnt+=1
	    end
	    #p response[0..10]
	
	    textPattern = collectTextPattern(urlStructure, sanitizedhost)
	    if (textPattern!=nil)
		#found policy file, we can use it directly
		response = convertResponse(response,textPattern,url,filecnt,urlStructure)
		if ($TrainNewAnchors) then response = universalTraining(response) end
	    elsif (urlStructure!="not_grouped")
		#we don't want to waste time adding anchors to not yet grouped urls.
	    	response = universalTraining(response)
	    end
	    File.open($TrafficDir+"#{sanitizedhost}/#{urlStructure}/#{sanitizedurl}?"+filecnt.to_s+".txt", 'w+') {|f| f.write(response) }
	    if $user_id!=nil then File.open($TrafficDir+"user-traffic.txt","a+") {|f| f.write("#{$user_id} => #{sanitizedurl}#{filecnt}.txt\n")} end
	    response = injectFFReplace(response,getTLD(url),filecnt)
    end
    puts "finish parsing "+url
    return response
end

#main function begins
url = ""
host = ""
hostChopped = ""
policyFile = ""
p ""
p ""
p "A new request"
if $user_id!=nil then p "by "+$user_id.to_s end
if ($httpresponse.match(/\A[^{]/))               #response should not start w/ '{', otherwise it's a json response
    #p $requestheader
    if (($httpresponse.match(/\A\s*\<[\!hH]/)!=nil)&&(!$httpresponse.match(/\A\s*\<\?[xX]/)))
        #getting the URL and host of the request
        if $requestheader =~ /GET\s(.*?)\sHTTP/     #get the URL of the request
		url = $1
		p "url is:" + url
		if $requestheader =~ /Host:\s(.*)/  #get the host of the request
		    host = $1
		    hostChopped = host.chop     # The $1 matches the string with a CR added. we don't want that.
		    hostChopped = hostChopped.gsub(/(\.|\/|:)/,'')
		    $httpresponse=process($httpresponse,url,host)
		end
        end
    end
end
