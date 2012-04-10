#rights=ADMIN
#------------------------------------------------------------------- 
# This is a GreasySpoon script.
# --------------------------------------------------------------------
# WHAT IT DOES:
# --------------------------------------------------------------------
# ==ServerScript==
# @name            no-cache
# @status off
# @description     
# @include        .*
# @exclude        
# ==/ServerScript==
# --------------------------------------------------------------------
# Available elements provided through ICAP server:
# ---------------
# requestedurl  :  (String) Requested URL
# requestheader  :  (String)HTTP request header
# httprequest    :  (String)HTTP request body
# user_id        :  (String)user id (login or user ip address)
# user_group     :  (String)user group or user fqdn
# sharedcache    :  (hashtable<String, Object>) shared table between all scripts
# trace		   :  (String) variable for debug output - requires to set log level to FINE
# ---------------

def getTLD(url)
	domain = url.gsub(/.*?\/\/(.*?)\/.*/,'\1')
	tld = domain.gsub(/.*\.(.*\..*)/,'\1')
	return tld
end
if $requestheader.downcase.index("if-modified-since")!=nil
	start = $requestheader.downcase.index("if-modified-since")
	ending = $requestheader.downcase.index("\n",start)
	$requestheader = $requestheader[0..start-1]+$requestheader[ending+1..$requestheader.length]
end


if $requestheader.downcase.index("cache-control")!=nil
	start = $requestheader.downcase.index("cache-control")
	ending = $requestheader.downcase.index("\n",start)
	$requestheader = $requestheader[0..start-1]+$requestheader[ending+1..$requestheader.length]
end
if (($requestheader[-1..-1]=="\n")&&($requestheader[-2..-2]=="\r")&&($requestheader[-3..-3]=="\n")&&($requestheader[-4..-4]=="\r"))
	$requestheader = $requestheader[0..-3]
end
$requestheader = $requestheader + "Cache-Control: no-cache\r\n"

if $requestheader.downcase.index("pragma")==nil
	if (($requestheader[-1..-1]=="\n")&&($requestheader[-2..-2]=="\r")&&($requestheader[-3..-3]=="\n")&&($requestheader[-4..-4]=="\r"))
		$requestheader = $requestheader[0..-3]
	end
	$requestheader= $requestheader + "Pragma: no-cache\r\n"
end

#File.open("/home/yuchen/header","a"){|f| f.write($requestheader)}



















