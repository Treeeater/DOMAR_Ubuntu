#!/usr/bin/ruby
require 'treeDistance'

def Grouping(traffic,domain,url)
	doc1 = Hpricot(traffic)
	maxSimilarity = 0.0
	index = ""
	dirs = Dir.glob($TrafficDir+domain+"/*")
	dirs.each{|dir|
		if (dir==$TrafficDir+domain+"/not_grouped") then next end
		files = Dir.glob(dir+"/*")
		targetTraffic = File.read(files[rand(files.length)])		#get a random file in that category.
		doc2 = Hpricot(targetTraffic)
		rootNode1 = doc1.search("/html")
		rootNode2 = doc2.search("/html")
		sim = GetSimilarity(rootNode1[0],rootNode2[0])
		#File.open($DF,"a"){|f| f.write(dir+" "+sim.to_s+"\n")}
		if (sim > $SimilarityThreshold) && (sim > maxSimilarity)
			maxSimilarity = sim
			index = dir.gsub(/.*\/(.*)/,'\1')
		end
	}
	if (index!="")
		#we found an existing group for this traffic
		File.open($GroupingDir+domain+"/list.txt","a") {|f| f.write(url+" "+index+"\n")}
	else
		#we establish a new group for this traffic
		#newCategoryName = dirs.length.to_s
		newCategoryName = 1
		while (File.directory?($TrafficDir+domain+"/"+newCategoryName.to_s+"/"))
			newCategoryName += 1
		end
		Dir.mkdir($TrafficDir+domain+"/"+newCategoryName.to_s+"/", 0777)
		File.open($GroupingDir+domain+"/list.txt","a") {|f| f.write(url+" "+newCategoryName.to_s+"\n")}
		File.open($TrafficDir+domain+"/"+newCategoryName.to_s+"/sample.txt", "w"){|f| f.write(traffic)}
	end
end

=begin
def ExtractURLStructure(url)
	#for example, let's say the url at here is http://www.nytimes.com/2012/01/03/sdfi-wer-qasdf-df.html
	protocol = url.gsub(/(.*?):\/\/.*/,'\1') #get the protocol, normally it would be http
	url = url[protocol.length+3..-1] #skip the ://, url becomes www.nytimes.com/2012/01/03/sdfi-wer-qasdf-df.html
	domainName = url.gsub(/(.*?)\/.*/,'\1')
	url = url[domainName.length+1..-1] #skip the second /, url becomes 2012/01/03/sdfi-wer-qasdf-df.html
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
		subPathArrayType.push("dk") #don't know
	}
	return protocol + "_" + domainName + "_" + subPathArrayType.join("_")
end

def Grouping(traffic,domain,url)
	newCategoryName = ExtractURLStructure(url)
	if (!File.directory?($TrafficDir+domain+"/"+newCategoryName+"/")) then Dir.mkdir($TrafficDir+domain+"/"+newCategoryName+"/", 0777) end
	File.open($GroupingDir+domain+"/list.txt","a") {|f| f.write(url+" "+newCategoryName+"\n")}
end
=end
