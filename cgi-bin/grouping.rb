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
		newCategoryName = dirs.length.to_s
		Dir.mkdir($TrafficDir+domain+"/"+newCategoryName+"/", 0777)
		File.open($GroupingDir+domain+"/list.txt","a") {|f| f.write(url+" "+newCategoryName+"\n")}
		File.open($TrafficDir+domain+"/"+newCategoryName+"/sample.txt", "w"){|f| f.write(traffic)}
	end
end
