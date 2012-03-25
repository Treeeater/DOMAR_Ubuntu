#!/usr/bin/ruby

require 'cgi'
require 'fileutils'
require 'specialID'
require 'buildModel'
require 'checkModel'
require 'grouping'

#global variables
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
$LogFile = "#{$HomeFolder}/Desktop/DOMAR/log.txt"
$ModelThreshold = 1
$AnchorThreshold = 20
$PatchDownThreshold = 100 #100
$PatchUpThreshold = 2
$SimilarityThreshold = 0.85
$standalonePage = true			#must be mutable variable here.
$DF = "/home/yuchen/success"		#debug purposes

puts "Content-Type: text/html"
puts
puts "<html>"
puts "<body>"

#Record this trace.
cgi = CGI.new

if (!(cgi.has_key?('url')&&cgi.has_key?('domain')&&cgi.has_key?('trace')&&cgi.has_key?('id')))
	puts "</body>"
	puts "</html>"
	return
end

recordURL = CGI.unescapeHTML(cgi['url'])
recordDomain = CGI.unescapeHTML(cgi['domain'])
recordTrace = CGI.unescapeHTML(cgi['trace'])
recordId = CGI.unescapeHTML(cgi['id'])

sanitizedURL = recordURL.gsub(/[^a-zA-Z0-9]/,"")
#urlStructure = extractURLStructure(recordURL)
urlStructure = LookupURLStructure(recordURL,recordDomain)
if (urlStructure==nil)
	#this url hasn't been grouped yet, we stop recording everything and begin grouping it.
	cur_traffic = File.read($TrafficDir+recordDomain+"/not_grouped/"+sanitizedURL+"?"+recordId+".txt")
	Grouping(cur_traffic,recordDomain,recordURL)
	return
end
makeDirectory($RecordDir+recordDomain+"/"+urlStructure)
files = Dir.glob($RecordDir+recordDomain+"/"+urlStructure+"/*")
times = Array.new
lookupTable = Hash.new
#File.open($DF,"a"){|f| f.write($RecordDir+recordDomain+"/"+urlStructure+"/#{sanitizedURL}?"+recordId.to_s+".txt")}
fileName = $RecordDir+recordDomain+"/"+urlStructure+"/#{sanitizedURL}?"+recordId.to_s+".txt"
fh = File.open(fileName, 'w+')
fh.write(recordTrace)
fh.close
=begin
if (File.exists?($StandaloneDir+recordDomain.gsub(/\./,'')+".txt"))
	fh = File.open($StandaloneDir+recordDomain.gsub(/\./,'')+".txt","r")
	while (line = fh.gets)
		if (recordURL == line.chomp)
			$standalonePage = true
			break
		end
	end
end
=end
#Check if there is specialId model
if (!File.exists?($SpecialIdDir+recordDomain+"/"+urlStructure+"/"+urlStructure+".txt"))
	#Does not exist, build it.
	if (files.size >= $AnchorThreshold)
		trafficInputs = Array.new
		files.each{|f|
			recordName = f.gsub(/.*\/(.*)\.txt$/,'\1')
			trafficInputs.push($TrafficDir+recordDomain+"/"+urlStructure+"/"+recordName+".txt")
		}
		outputPolicyFileName = $SpecialIdDir+recordDomain+"/"+urlStructure+"/"+urlStructure+".txt"
		extractTextPattern(trafficInputs, files, outputPolicyFileName, recordDomain, urlStructure)
		prepareDirectory($TrafficDir+recordDomain+"/"+urlStructure+"/.anchorSeedTraffics/")
		prepareDirectory($RecordDir+recordDomain+"/"+urlStructure+"/.anchorSeedRecords/")
		records = Dir.glob($RecordDir+recordDomain+"/"+urlStructure+"/*")
		records.each{|r|
			fName = r.gsub(/.*\/(.+?\.txt)/,'\1')
			rName = r.gsub(/(.*\/).+?\.txt/,'\1')
			if (!File.directory? r)
				FileUtils.mv(r,rName+".anchorSeedRecords/"+fName)
			end
		}
		traffics = Dir.glob($TrafficDir+recordDomain+"/"+urlStructure+"/*")
		traffics.each{|r|
			fName = r.gsub(/.*\/(.+?\.txt)/,'\1')
			rName = r.gsub(/(.*\/).+?\.txt/,'\1')
			if (!File.directory? r)
				FileUtils.mv(r,rName+".anchorSeedTraffics/"+fName)
			end
		}
	end
else
#our model is only based on the relative+absolute model, so if there is no anchors learnt, we do not check model.
	relative = probeXPATH(recordTrace)
	CheckModel(recordTrace, recordDomain, sanitizedURL, urlStructure, recordId, relative)
	AdaptAnchor(recordDomain, sanitizedURL, urlStructure)
end
File.open($LogFile, "a"){|f| f.write(recordURL+recordId+"\n")}
puts "<h1>!</h1>"
puts "</body>"
puts "</html>"


