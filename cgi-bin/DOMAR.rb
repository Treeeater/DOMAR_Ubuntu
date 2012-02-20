#!/usr/bin/ruby

require 'cgi'
require 'fileutils'
require 'specialID'
require 'buildModel'
require 'checkModel'

#global variables
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
$ModelThreshold = 10
$AnchorThreshold = 5
$PatchThreshold = 5

puts "Content-Type: text/html"
puts
puts "<html>"
puts "<body>"



#Record this trace.
cgi = CGI.new
recordURL=""
recordDomain = ""
recordTrace = ""

if (!(cgi.has_key?('url')&&cgi.has_key?('domain')&&cgi.has_key?('trace')))
	puts "</body>"
	puts "</html>"
	return
end

recordURL = CGI.unescapeHTML(cgi['url'])
recordDomain = CGI.unescapeHTML(cgi['domain'])
recordTrace = CGI.unescapeHTML(cgi['trace'])
if (!File.directory?($RecordDir+recordDomain))
	Dir.mkdir($RecordDir+recordDomain, 0777)
end
if (!File.directory?($RecordDir+recordDomain+"/"+recordURL))
	Dir.mkdir($RecordDir+recordDomain+"/"+recordURL, 0777)
end
files = Dir.glob($RecordDir+recordDomain+"/"+recordURL+"/*")
times = Array.new
lookupTable = Hash.new
id = nil
files.each{|file|
	#FIXME:due to DOMAR.rb execution failure or trace submission failure there could be multiples of _zyc existing.
	if (file.index('_zyc')!=nil)
		id = file.gsub(/.*?(\d+)\.txt/,'\1')
		break
	end
}
fileName = $RecordDir+recordDomain+"/"+recordURL+"/record"+id.to_s+".txt"
toDelete = $RecordDir+recordDomain+"/"+recordURL+"/record_zyc"+id.to_s+".txt"
File.delete(toDelete)
fh = File.open(fileName, 'w+')
fh.write(recordTrace)
fh.close

#Check if there is specialId model
if (!File.exists?($SpecialIdDir+recordDomain+"/"+recordURL+"/"+recordURL+".txt"))
	#Does not exist, build it.
	if (files.size >= $AnchorThreshold)
		trafficInputs = Array.new
		recordInputs = Array.new
		files.each{|f|
			if (f.index('zyc')!=nil)
				next
			end
			id = f.gsub(/.*?(\d+)\.txt/,'\1')
			recordInputs.push(f)
			trafficInputs.push($TrafficDir+recordDomain+"/"+recordURL+"/"+recordURL+id+".txt")
		}
		outputPolicyFileName = $SpecialIdDir+recordDomain+"/"+recordURL+"/"+recordURL+".txt"
		extractTextPattern(trafficInputs, recordInputs, outputPolicyFileName)
		prepareDirectory($TrafficDir+recordDomain+"/"+recordURL+"/.anchorSeedTraffics/")
		prepareDirectory($RecordDir+recordDomain+"/"+recordURL+"/.anchorSeedRecords/")
		records = Dir.glob($RecordDir+recordDomain+"/"+recordURL+"/*")
		records.each{|r|
			fName = r.gsub(/.*\/(.+?\.txt)/,'\1')
			rName = r.gsub(/(.*\/).+?\.txt/,'\1')
			if (!File.directory? r)
				FileUtils.mv(r,rName+".anchorSeedRecords/"+fName)
			end
		}
		traffics = Dir.glob($TrafficDir+recordDomain+"/"+recordURL+"/*")
		traffics.each{|r|
			fName = r.gsub(/.*\/(.+?\.txt)/,'\1')
			rName = r.gsub(/(.*\/).+?\.txt/,'\1')
			if (!File.directory? r)
				FileUtils.mv(r,rName+".anchorSeedTraffics/"+fName)
			end
		}
	end
end
#Check if there is model built, if not, build it.

policyFiles = Dir.glob($PolicyRDir+recordDomain+"/"+recordURL+"/*")
if (policyFiles.empty?)
	#need to check if we want to build model
	if (files.size >= $ModelThreshold)
		#We want to build a model
		#File.open("/home/yuchen/success",'a+'){|fht| fht.write(files.size.to_s)}
		BuildModel(recordDomain, recordURL)
	end
	#else we do nothing, wait for more record.
else
	#we have the model, check it.
	relative = probeXPATH(recordTrace)
	policyA = ExtractPolicyFromFile($PolicyADir,recordDomain,recordURL)
	policyR = Hash.new
	if relative then policyR = ExtractPolicyFromFile($PolicyRDir,recordDomain,recordURL)
	end
	CheckModel(recordTrace, policyA, policyR, recordDomain, recordURL, id, relative)
	AdaptAnchor(recordDomain, recordURL)
end
puts "<h1>#{TrafficDir}!</h1>"
puts "</body>"
puts "</html>"


