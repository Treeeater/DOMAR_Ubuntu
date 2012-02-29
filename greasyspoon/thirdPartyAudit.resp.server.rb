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
$PreferenceListDir = "#{$HomeFolder}/Desktop/DOMAR/site_preferences/"
$SpecialIdDir = "#{$HomeFolder}/Desktop/DOMAR/specialID/"
$TrafficDir = "#{$HomeFolder}/Desktop/DOMAR/traffic/"
$AnchorErrorDir = "#{$HomeFolder}/Desktop/DOMAR/anchorErrors/"
$ModelThreshold = 100
$AnchorThreshold = 50

def getTLD(url)
	domain = url.gsub(/.*?\/\/(.*?)\/.*/,'\1')
	tld = domain.gsub(/.*\.(.*\..*)/,'\1')
	return tld
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

def injectFFReplace(response,url,domain,filecnt)
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

def collectTextPattern(url,host)
	if (File.exists? $SpecialIdDir+host+"/"+url+"/" + url + ".txt")
		return File.read($SpecialIdDir+host+"/"+url+"/" + url + ".txt")
	end
	return nil
end

def approxmatching(a,b)
	return (a==b)
end

def convertResponse(response, textPattern, url, filecnt)
	listToAdd = Hash.new
	vicinityList = Hash.new
	recordedVicinity = Hash.new
	processedNodes = Hash.new
	id = ""
	error = false
	errormsg = ""
	currentDomain = ""
	sanitizedurl = url.gsub(/[^a-zA-Z0-9]/,"")
    	sanitizedhost = getTLD(url)
	sanitizedhost = sanitizedhost.gsub(/[^a-zA-Z0-9]/,"")
	textPattern.each_line{|l|
		l = l.chomp
		if (l[0..8]=="Domain:= ")
			currentDomain = l[9..l.length]
			next
		end
		if (l[0..2]=='Tag')
			matches = false
			id = currentDomain + l.gsub(/\ATag\s(\d+).*/,'\1')
			if (processedNodes[id]!=nil)
				next			#we don't want to add multiples of specialId to a node.
			end
			processedNodes[id]=l
			#tagName = l.gsub(/\<(\w*).*/,'\1')
			toMatch = l.gsub(/.*?(\<.*\>)$/,'\1')
			toMatcht = toMatch
=begin
			#this is the code base to deal with attributes shuffled. However there is a bug. if we need to turn this back on we need to fix it.
			toMatchGrp = toMatch.scan(/(\w*)=\"([\w\s]*)\"/)
			toMatchGrp.each_index{|i|
				toMatchGrp[i] = toMatchGrp[i][0]+"=\""+toMatchGrp[i][1]+"\""
			}
			 to deal with the problem of having different permutations of attributes.
			temp = toMatchGrp.permutation(toMatchGrp.length).to_a
			temp.each_index{|i|
				toMatch = '<'+tagName+(temp[i].length==0?"":" ")+temp[i].join(" ")+'>'
				matchpoints = response.enum_for(:scan,toMatch).map{Regexp.last_match.begin(0)}
				i = 0
				while (i<matchpoints.size)
					matches = true
					listToAdd[id] = (listToAdd[id]==nil) ? Array.new([matchpoints[i]+toMatch.length-1]) : listToAdd[id].push(matchpoints[i]+toMatch.length-1)
					vicinityInfo = (response[matchpoints[i]+toMatch.length,100].gsub(/\n/,''))[0,30]
					vicinityList[id] = (vicinityList[id]==nil) ? Array.new([vicinityInfo]) : vicinityList[id].push(vicinityInfo)
					i+=1
					#response.insert(response.index(toMatch)+toMatch.length-1,' specialId="'+id.to_s+'"')
				end
			}
=end
			matchpoints = response.enum_for(:scan,toMatch).map{Regexp.last_match.begin(0)}
			i = 0
			while (i<matchpoints.size)
				matches = true
				listToAdd[id] = (listToAdd[id]==nil) ? Array.new([matchpoints[i]+toMatch.length-1]) : listToAdd[id].push(matchpoints[i]+toMatch.length-1)
				vicinityInfo = (response[matchpoints[i]+toMatch.length,100].gsub(/[\r\n]/,''))[0..30]
				vicinityList[id] = (vicinityList[id]==nil) ? Array.new([vicinityInfo]) : vicinityList[id].push(vicinityInfo)
				i+=1
			end
			if (matches==false)
				File.open($SpecialIdDir+sanitizedhost+"/"+sanitizedurl+"/patchdown.txt","a"){|f| f.write(l+"\n")}
				error = true
				errormsg += "failed to find a match for "+toMatcht+"\n"
			end
		end
		if (l[0..0]=='&')
			recordedVicinity[id] = l[1,l.length]		#if we want to extract children information
		end
	}
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
				File.open($SpecialIdDir+sanitizedhost+"/"+sanitizedurl+"/patchdown.txt","a"){|f| f.write(processedNodes[id]+"\n")}
=begin
				candidates = listToAdd[id].clone		#temporarily store the previously found elements (all of them are incorrect) in a new array.
				listToAdd.delete(id)				#remove the original item
				#add all original items differently.
				#store vicinity information in a cache folder
				makeDirectory($AnchorErrorDir+sanitizedhost+"/"+sanitizedurl+"/")
				fh=File.open($AnchorErrorDir+sanitizedhost+"/"+sanitizedurl+"/error"+filecnt.to_s+".txt","a")
				candidates.each_index{|c|
					idpatched = id + "->" + c.to_s
					listToAdd[idpatched] = Array.new([candidates[c]])
					fh.write(id + " => " + idpatched + " ]> " + vicinityList[id][c] + "\n" )
				}
				fh.close()
=end
				error = true
				errormsg += "multiple matches found for: "+ id + ", but no vicinity matches original model.\n"
				p errormsg
			elsif (found > 1)
				listToAdd.delete(id)				#remove the original item
				File.open($SpecialIdDir+sanitizedhost+"/"+sanitizedurl+"/patchdown.txt","a"){|f| f.write(processedNodes[id]+"\n")}
=begin
				#add all original items differently, FIXME:we should include more vicinity info.
				#store vicinity information in a cache folder
				makeDirectory($AnchorErrorDir+sanitizedhost+"/"+sanitizedurl+"/")
				fh=File.open($AnchorErrorDir+sanitizedhost+"/"+sanitizedurl+"/error"+filecnt.to_s+".txt","a")
				candidates.each_index{|c|
					idpatched = id + "->" + c.to_s
					listToAdd[idpatched] = Array.new([candidates[c]])
					fh.write(id + " => " + idpatched + " ]> " + candidatesVicinity[c] + "\n" )
				}
				fh.close()
=end
				error = true
				errormsg += "multiple matches found for: "+ id + ", because more than 1 vicinity matches original model. found a total of "+found.to_s+" matches.\n"
				p errormsg
			end
		end
	}
=begin
	checkDup = Hash.new
	listToAdd.each_key{|id|
		#remove duplicates.
		#This scenario happens only when input file number is more than 1.
		if (checkDup.key?(listToAdd[id][0])==nil)
			checkDup[listToAdd[id][0]]=true
		else
			
		end
	}
=end
	listToAdd.each_key{|id|
		index = listToAdd[id][0]		#FIXME: this actually can be 0
		content = " specialId = \'id#{id}\'"
		response = response.insert(index, content)
		listToAdd.each_key{|i|
			#N squared time complexity, we could definitely optimize this thing but I don't do it now.
			if (listToAdd[i][0] > listToAdd[id][0])
				listToAdd[i][0]+=content.length
			end
		}
	}
	#p vicinityList
	#p recordedVicinity	
=begin
	if (error)
		logfh = File.open("/home/yuchen/errorlog.txt","a")
		logfh.write("error when converting url: #{url}, id: #{filecnt}.\n")
		logfh.write(errormsg)
		logfh.close
	end
=end
	return response
end

def universalTraining(response)
    globalNodeIdCount = 0
    pointer = 0
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
        if (response.downcase[pointer..pointer+7]=='!doctype')              #skip doctype declarations
            startingTag = response.index('>',pointer)               #assuming no greater than in DOCTYPE declaration.
            startingTag = response.index('<',startingTag)
            next
        end
        if (response[pointer..pointer+2]=='!--')                    #skip comment nodes
            startingTag = response.index('-->',pointer)
            startingTag = response.index('<',startingTag)
            next
        end
        if (response.downcase[pointer..pointer+5] == "script")              #skip chunks of scripts
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
        #we need to add special attrs, now we should find the closing greater than for this opening tag.
        #dealing with '>' in attrs.
	startingPointer = pointer
        pointer = findclosinggt(response,pointer)
	if (response[startingPointer..pointer].downcase.index('specialid')!=nil)	#skip the nodes that are already marked.
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
    sanitizedhost = sanitizedhost.gsub(/[^a-zA-Z0-9]/,"")		#get rid of the dot.
    if (mediate)
	    if (!File.directory? $TrafficDir)
		Dir.mkdir($TrafficDir,0777)
	    end
	    if (!File.directory? $TrafficDir+sanitizedhost)
		Dir.mkdir($TrafficDir+sanitizedhost,0777)
	    end
	    if (!File.directory? $TrafficDir+sanitizedhost+"/"+sanitizedurl)
		Dir.mkdir($TrafficDir+sanitizedhost+"/"+sanitizedurl,0777)
	    end
	    if (!File.directory? $RecordDir)
		Dir.mkdir($RecordDir,0777)
	    end
	    if (!File.directory? $RecordDir+sanitizedhost)
		Dir.mkdir($RecordDir+sanitizedhost,0777)
	    end
	    if (!File.directory? $RecordDir+sanitizedhost+"/"+sanitizedurl)
		Dir.mkdir($RecordDir+sanitizedhost+"/"+sanitizedurl,0777)
	    end
	    while (File.exists? $TrafficDir+"#{sanitizedhost}/#{sanitizedurl}/#{sanitizedurl}"+filecnt.to_s+".txt")
	    	filecnt+=1
	    end
	    #p response[0..10]
	
	    textPattern = collectTextPattern(sanitizedurl, sanitizedhost)
	    if (textPattern!=nil)
		#found policy file, we can use it directly
		response = convertResponse(response,textPattern,url,filecnt)
	    end
	    response = universalTraining(response)
	    File.open($TrafficDir+"#{sanitizedhost}/#{sanitizedurl}/#{sanitizedurl}"+filecnt.to_s+".txt", 'w+') {|f| f.write(response) }
	    if $user_id!=nil then File.open($TrafficDir+"user-traffic.txt","a+") {|f| f.write("#{$user_id} => #{sanitizedurl}#{filecnt}.txt\n")} end
	    response = injectFFReplace(response,sanitizedurl,getTLD(url),filecnt)
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
