#!/usr/bin/ruby
require 'rubygems'
require 'hpricot'

def max(a,b,c)
	d = (a>b) ? a : b
	return (d > c) ? d : c
end
=begin
class Node

  attr_reader :children
  attr_accessor :parent, :name

public
	def initialize(n)
		@children = Array.new
		@name = n
		@parent = nil
	end

	def addkid(child)
		@children.push(child)
		child.parent = self
	end

	def printTree()
		if (@children.length!=0) 
			@children.each{|c| c.printTree}
		end
		puts @name
	end

	def treeDistance(t)
		if (@name!=t.name) then return 0 end
		if @children.length==0 then return 1 end
		if t.children.length==0 then return 1 end
		matrix = Array.new(@children.length+1)
		matrix.each_index{|mi| matrix[mi] = Array.new(t.children.length+1)}
		matrix.each_index{|si| matrix[si][0]=0}
		matrix[0].each_index{|ti| matrix[0][ti]=0}
		i = 0
		j = 0
		for i in (1..@children.length)
			for j in (1..t.children.length)
				matrix[i][j] = max(matrix[i][j-1], matrix[i-1][j], matrix[i-1][j-1] + (@children[i-1].treeDistance(t.children[j-1])) )
			end
		end
		return matrix[@children.length][t.children.length]+1
	end
end
=end
def CompareNodeContent(n1,n2)
	if (n1.text?)&&(n2.text?) then return true end
	if (n1.comment?)&&(n2.comment?) then return true end
	if (n1.name!=n2.name) then return false end
	if (n1.respond_to? "attributes")&&(n1.attributes['id']!=nil)
		if (!n2.respond_to? "attributes")||(n2.attributes['id']==nil) then return false end
		if (n1.attributes['id']==n2.attributes['id']) then return true end
	elsif (n2.respond_to? "attributes")&&(n2.attributes['id']!=nil)
		return false
	end
	return true
end

def TreeDistance(s,t)
	if !CompareNodeContent(s,t) then return 0 end						#if the root node's type/id doesn't match, return 0.
	if (!s.respond_to? "children")||(!t.respond_to? "children") then return 1 end		#if the content of the node matches, however at least one of the subject doesn't have children, return 1.
	if (s.children==nil)||(t.children==nil) then return 1 end
	if (s.children.length==0)||(t.children.length==0) then return 1 end
	matrix = Array.new(s.children.length+1)							#if both subject have children, do this recursively
	matrix.each_index{|mi| matrix[mi] = Array.new(t.children.length+1)}
	matrix.each_index{|si| matrix[si][0]=0}
	matrix[0].each_index{|ti| matrix[0][ti]=0}
	i = 0
	j = 0
	for i in (1..s.children.length)
		for j in (1..t.children.length)
			matrix[i][j] = max(matrix[i][j-1], matrix[i-1][j], matrix[i-1][j-1] + TreeDistance(s.children[i-1],t.children[j-1]))
		end
	end
	return matrix[s.children.length][t.children.length]+1
end

def CountNodes(t)
	if ((!t.respond_to? "children")||(t.children==nil)||(t.children.length==0)) then return 1 end
	total = 1
	t.children.each{|c|
		total += CountNodes(c)
	}
	return total
end

def GetSimilarity(s,t)
	#s and t are two hpricot root nodes
	distance = TreeDistance(s,t)
	nodeCount1 = CountNodes(s)
	nodeCount2 = CountNodes(t)
	return (nodeCount1>nodeCount2) ? (distance.to_f/nodeCount1) : (distance.to_f/nodeCount2)
end

=begin
tree1 = 0
tree2 = 0

doc1 = open("2.txt") {|f| tree1 = Hpricot(f)}
doc2 = open("3.txt") {|f| tree2 = Hpricot(f)}

rootNode1 = doc1.search("/html")
rootNode2 = doc2.search("/html")

p GetSimilarity(rootNode1[0],rootNode2[0])
=end
