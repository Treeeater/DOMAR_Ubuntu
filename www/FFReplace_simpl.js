/* DOM Access recording, author: Yuchen Zhou
Oct, 2011.  University of Virginia.*/

/*This version only works on Firefox*/

/*
Mediated APIs:
--document selectors--
document.getElementById
document.getElementsByClassName
document.getElementsByTagName
document.getElementsByName
--traversals--
parentNode
nextSibling
previousSibling
firstChild
lastChild
childNodes
children
--document special properties--
document.cookie
document.cookie=
document.images/anchors/links/applets/forms
--node special properties--
node.innerHTML
*/
function ___record(){					
var seqID = 0;
var recordedDOMActions = new Array();		//used to remember what we have already recorded to avoid duplicants.
if (/Firefox[\/\s](\d+\.\d+)/.test(navigator.userAgent))
{ //test for Firefox/x.x or Firefox x.x (ignoring remaining digits);
	var ffversion=new Number(RegExp.$1) // capture x.x portion and store as a number
}
if (!ffversion||(ffversion<5)) return null;
//private variable: records all DOM accesses
var record = new Array(new Array(), new Array(), new Array());
var trustedDomains = ["0.1"];
var filecnt = "";
var DOMRecord = 0;
var windowRecord = 1;
var documentRecord = 2;
var curDomain;
var curTopDomain;
var cur_Attributes = new Array();		//works as a buffer to hold specialids and their nodes if attributes is called.
var cur_InnerHTML = new Array();		//works as a buffer to hold specialids and their nodes if innerHTML is called.
//Enumerates all types of elements to mediate properties like parentNode
//According to DOM spec level2 by W3C, HTMLBaseFontElement not defined in FF.
var allElementsType = [HTMLElement,HTMLHtmlElement,HTMLHeadElement,HTMLLinkElement,HTMLTitleElement,HTMLMetaElement,HTMLBaseElement,HTMLStyleElement,HTMLBodyElement,HTMLFormElement,HTMLSelectElement,HTMLOptGroupElement,HTMLOptionElement,HTMLInputElement,HTMLTextAreaElement,HTMLButtonElement,HTMLLabelElement,HTMLFieldSetElement,HTMLLegendElement,HTMLUListElement,HTMLDListElement,HTMLDirectoryElement,HTMLMenuElement,HTMLLIElement,HTMLDivElement,HTMLParagraphElement,HTMLHeadingElement,HTMLQuoteElement,HTMLPreElement,HTMLBRElement,HTMLFontElement,HTMLHRElement,HTMLModElement,HTMLAnchorElement,HTMLImageElement,HTMLParamElement,HTMLAppletElement,HTMLMapElement,HTMLAreaElement,HTMLScriptElement,HTMLTableElement,HTMLTableCaptionElement,HTMLTableColElement,HTMLTableSectionElement,HTMLTableRowElement,HTMLTableCellElement,HTMLFrameSetElement,HTMLFrameElement,HTMLIFrameElement,HTMLObjectElement,HTMLSpanElement];
//These need to be here because getXPath relies on this.
var oldParentNode = Element.prototype.__lookupGetter__('parentNode');
var oldNextSibling = Element.prototype.__lookupGetter__('nextSibling');
var oldPreviousSibling = Element.prototype.__lookupGetter__('previousSibling');
var oldChildNodes = Element.prototype.__lookupGetter__('childNodes');
var oldGetAttribute = Element.prototype.getAttribute;

var restoreAttributes = function()
{
	//used to move buffer back to dom tree.
	i = 0;
	for (id in cur_InnerHTML)
	{
		i++;
		thisNode = cur_InnerHTML[id];
		if (thisNode)
		{
			var func = oldSetAttr[thisNode.constructor];
			if (func==undefined) func = oldSetAttr[HTMLObjectElement];
			func.apply(thisNode,['specialId',id]);
		}
	}
	cur_InnerHTML = new Array();
	return;
};

var clearSpecialId = function(node)
{
	try{
	if ((!node)||(node.nodeType!=1)) return;
	var get = oldGetAttr[node.constructor];
	if (get==undefined) get = oldGetAttr[HTMLObjectElement];
	if ((node.getAttribute!=undefined)&&(node.removeAttribute!=undefined))
	{
		var temp = get.apply(node,["specialId"]);
		if (temp)
		{
			node.removeAttribute("specialId");
			if (cur_InnerHTML[temp]==undefined) cur_InnerHTML[temp] = node;
		}
	}

	var child = oldChildren.apply(node);
	for (nodes in child)
	{
		clearSpecialId(child[nodes]);
	}
	return;
	}catch(e){alert(e)}
}

var getXPathA = function(elt)
{
	restore = false;
	for (i in cur_InnerHTML) {restore = true; break;}
	if (restore) restoreAttributes();			//innerHTML can be restored, but attributes cannot.  The reason is that attributes handlers can still be held by a malicious script and call [] later.
    var path = "";
    for (; elt && (elt.nodeType == 1||elt.nodeType == 3||elt.nodeType == 2); elt = oldParentNode.apply(elt))
    {
		idx = getElementIdx(elt);
		if (elt.nodeType ==1) xname = elt.tagName;
		else if (elt.nodeType == 3) xname = "TEXT";
		else if (elt.nodeType == 2) xname = "ATTR";
		if (idx > 1) xname += "[" + idx + "]";
		path = "/" + xname + path;
    }
    if (path.substr(0,5)!="/HTML") return "";		//right now, if this node is not originated from HTMLDocument (e.g., some script calls createElement which does not contain any private information, we do not record this access.
	return path;
};

var getXPathR = function(elt)
{
    var path = "";
	var relative = false;
    for (; elt && (elt.nodeType == 1||elt.nodeType == 3||elt.nodeType == 2); elt = oldParentNode.apply(elt))
    {
		if ((elt.nodeType ==1)&&(oldGetAttribute.apply(elt,['specialId'])!=null))
		{
			path = "//" + oldGetAttribute.apply(elt,['specialId']) + path;
			break;
		}
		for (id in cur_Attributes)			//Looking for cur_Attributes is enough, don't need to look for cur_InnerHTML, because they are already restored.
		{
			if (cur_Attributes[id]==elt)
			{
				path = "//" + id + path;
				relative = true;
				break;
			}
		}
		if (relative) break;
		idx = getElementIdx(elt);
		if (elt.nodeType ==1) xname = elt.tagName;
		else if (elt.nodeType == 3) xname = "TEXT";
		else if (elt.nodeType == 2) xname = "ATTR";
		if (idx > 1) xname += "[" + idx + "]";
		path = "/" + xname + path;
    }
    //if (!(path.substr(0,2)=="//")) return "";		//right now, if this node is not originated from //, we do not record this access. Without this, getXPathR will return the same result as getXPathA if it does not hit an anchor.
    return path;
}

var getElementIdx = function(elt)
{
    var count = 1;
	if (elt.nodeType==1)
	{
		for (var sib = oldPreviousSibling.apply(elt); sib ; sib = oldPreviousSibling.apply(sib))
		{
			if(sib.nodeType == 1 && sib.tagName == elt.tagName)	count++;
		}
	}
	else if (elt.nodeType==3)
	{
		for (var sib = oldPreviousSibling.apply(elt); sib ; sib = oldPreviousSibling.apply(sib))
		{
			if(sib.nodeType == 3)	count++;
		}
	}
	else if (elt.nodeType==2)
	{
		for (var sib = oldPreviousSibling.apply(elt); sib ; sib = oldPreviousSibling.apply(sib))
		{
			if(sib.nodeType == 2)	count++;
		}
	}
    return count;
};
//if getCallerInfo returns null, all recording functions will not record current access.
var getCallerInfo = function() {
    try {
        this.undef();
        return null;
    } catch (e) {
		var entireStack = e.stack;
		var ignored = "";
		var untrustedStack = "";
		var recordedDomains = [];
		if (entireStack.length>3000) 
		{
			entireStack = entireStack.substr(entireStack.length-3000,entireStack.length);		//Assumes the total call stack is less than 3000 characters. avoid the situation when arguments becomes huge and regex operation virtually stalls the browser.  This could very well happen when innerHTML is changed. For example, flickr.com freezes our extension without this LOC.
			ignored = "> stack trace is more than 3000 chars";					//notify the record that this message is not complete.
		}
		while (entireStack != "")
		{
			//assuming a http or https protocol, which is true >99% of the time.
			var curLine = "";
			curLine = entireStack.replace(/([\s\S]*?@http.*\n)[\s\S]*/m, "$1");
			if (curLine=="") return null;		//giveup if it's not http/https protocol
			entireStack = entireStack.substr(curLine.length,entireStack.length);	//entireStack is adjusted to remove curLine
			curLine = curLine.replace(/[\s\S]*@(http.*\n)$/,"$1");				//get rid of the whole arguments
			curDomain = curLine.replace(/.*?\/\/(.*?)\/.*/,"$1");				//http://www.google.com/a.html, w/ third slash.
			if (curDomain==curLine) curDomain = curLine.replace(/.*?\/\/(.*)/,"$1");	//http://www.google.com, no third slash.
			if ((curDomain==curLine) || (curDomain.substr(0,12).toLowerCase()=="@javascript:"))
			{
				curTopDomain="javascript pseudo protocol";								//maybe this is a javascript pseudo protocol
			}
			else
			{
				curTopDomain = curDomain.replace(/.*\.(.*\..*)/,"$1");				//get the top domain
			}
			if (curTopDomain[curTopDomain.length-1]=="\n") curTopDomain=curTopDomain.substr(0,curTopDomain.length-1);	//chomp
			var i = 0;
			var trusted = false;
			var recorded = false;
			for (i=0; i < trustedDomains.length; i++)
			{
				if (curLine.indexOf(trustedDomains[i])>-1)
				{
					trusted = true;
					break;
				}
			}
			if (!trusted)
			{
				for (i=0; i < recordedDomains.length; i++)
				{
					//See if we have already recorded this domain in this access.
					if (curLine.indexOf(recordedDomains[i])>-1)
					{
						recorded = true;
						break;
					}
				}
			}
			if ((!trusted)&&(!recorded)) 
			{
				untrustedStack += curTopDomain;
				break;												//this is ad-hoc. we do not tackle multiple third party scripts in the same stack for now.
				if (curTopDomain!="javascript pseudo protocol") recordedDomains.push(curTopDomain);		//Now we ignore pseudo-protocol
			}
		}
		if (untrustedStack == "") return null;
		returnstring = untrustedStack+ignored;
		if (returnstring[returnstring.length-1]=="\n") returnstring=returnstring.substr(0,returnstring.length-1);	//chomp
		return returnstring;
    }
};
var getFullCallerInfo = function() {
    try {
        this.undef();
        return null;
    } catch (e) {
        return e.stack;
    }
};
//Original DOM-ECMAscript API
var oldGetId = document.getElementById;	
var oldGetClassName = document.getElementsByClassName;
var oldGetTagName = document.getElementsByTagName;
var oldGetName = document.getElementsByName;
var oldGetTagNameNS = document.getElementsByTagNameNS;
var oldQuerySelector = document.querySelector;			//new
var oldQuerySelectorAll = document.querySelectorAll;		//new
//New DOM-ECMAScript API
if (oldGetId)
{
	var newGetId = function(){
		var returnValue = oldGetId.apply(document,arguments);
		var callerInfo = getCallerInfo();
		if (callerInfo!=null)
		{
			var thispathA = getXPathA(returnValue);
			var thispathR = getXPathR(returnValue);
			if (thispathA!="")
			{
				//If this node is attached to the root DOM tree, but not something created out of nothing.
				//To record the calling stack
				//To record the acutal content.
				seqID++;
				if (recordedDOMActions[thispathA+callerInfo]!=true)
				{
					recordedDOMActions[thispathA+callerInfo]=true;
					record[DOMRecord].push({what:thispathA,whatR:thispathR,when:seqID,who:callerInfo});		//what: always available; whatR: record only DOM nodes access that has Relative XPATH
				}
			}
		}
		return returnValue;
	};
}
if (oldGetClassName)
{
	var newGetClassName = function(){
		var callerInfo = getCallerInfo();
		if (callerInfo!=null)
		{
			seqID++;
			if (recordedDOMActions["getElementsByClassName called on document, Class: "+arguments[0]+callerInfo]!=true)
			{
				recordedDOMActions["getElementsByClassName called on document, Class: "+arguments[0]+callerInfo]=true;
				record[documentRecord].push({what:"getElementsByClassName called on document, Class: "+arguments[0], when:seqID, who:callerInfo});
			}
		}
		return oldGetClassName.apply(document,arguments);
	};
}
if (oldGetTagName)
{
	var newGetTagName = function(){
		var callerInfo = getCallerInfo();	
		if (callerInfo!=null){
			seqID++;
			if (recordedDOMActions["getElementsByTagName called on document, Tag: "+arguments[0]+callerInfo]!=true)
			{
				recordedDOMActions["getElementsByTagName called on document, Tag: "+arguments[0]+callerInfo]=true;
				record[documentRecord].push({what:"getElementsByTagName called on document, Tag: "+arguments[0], when:seqID,who:callerInfo});
			}
		}
		return oldGetTagName.apply(document,arguments);
	};
}
if (oldGetTagNameNS)
{
	var newGetTagNameNS = function(){
		var callerInfo = getCallerInfo();	
		if (callerInfo!=null){
		seqID++;
		if (recordedDOMActions["getElementsByTagNameNS called on document, NS: "+arguments[0]+" Tag: "+arguments[1]+callerInfo]!=true)
			{
				recordedDOMActions["getElementsByTagNameNS called on document, NS: "+arguments[0]+" Tag: "+arguments[1]+callerInfo]=true;
				record[documentRecord].push({what:"getElementsByTagNameNS called on document: NS: "+arguments[0]+" Tag: "+arguments[1], when:seqID,who:callerInfo});
			}
		}
		return oldGetTagNameNS.apply(document,arguments);
	};
}
if (oldGetName)
{
	var newGetName = function(){
		var callerInfo = getCallerInfo();	
		if (callerInfo!=null){
			seqID++;
			if (recordedDOMActions["getElementsByName called on document, Name: "+arguments[0]+callerInfo]!=true)
			{
				recordedDOMActions["getElementsByName called on document, Name: "+arguments[0]+callerInfo]=true;
				record[documentRecord].push({what:"getElementsByName called on document, Name: "+arguments[0], when:seqID,who:callerInfo});
			}
		}
		return oldGetName.apply(document,arguments);
	};
}
if (oldQuerySelector)
{
	var newQuerySelector = function(){
		var callerInfo = getCallerInfo();	
		var returnValue = oldQuerySelector.apply(document,arguments);
		var thispathA = getXPathA(returnValue);
		var thispathR = getXPathR(returnValue);
		if (thispathA!="")
		{
			if (callerInfo!=null){
				seqID++;
				if (recordedDOMActions[thispathA+callerInfo]!=true)
				{
					recordedDOMActions[thispathA+callerInfo]=true;
					record[DOMRecord].push({what:thispathA,whatR:thispathR, when:seqID,who:callerInfo});
				}
			}
		}
		return returnValue;
	};
}
if (oldQuerySelectorAll)
{
	var newQuerySelectorAll = function(){
		var callerInfo = getCallerInfo();	
		if (callerInfo!=null){
			seqID++;
			if (recordedDOMActions["querySelectorAll called on document, CSS selector: "+arguments[0]+callerInfo]!=true)
			{
				recordedDOMActions["querySelectorAll called on document, CSS selector: "+arguments[0]+callerInfo]=true;
				record[documentRecord].push({what:"querySelectorAll called on document, CSS selector: "+arguments[0], when:seqID,who:callerInfo});
			}
		}
		return oldQuerySelectorAll.apply(document,arguments);
	};
}
document.querySelector = newQuerySelector;
document.querySelectorAll = newQuerySelectorAll;
//Get original property accessors
var oldFirstChild = Element.prototype.__lookupGetter__('firstChild');
var oldLastChild = Element.prototype.__lookupGetter__('lastChild');
var oldChildren = Element.prototype.__lookupGetter__('children');
var oldAttributes = Element.prototype.__lookupGetter__('attributes');
//innerHTML
var oldInnerHTMLGetter = HTMLElement.prototype.__lookupGetter__('innerHTML');
var oldTextContentGetter = HTMLElement.prototype.__lookupGetter__('textContent');
//Get original DOM special properties
var old_cookie_setter = HTMLDocument.prototype.__lookupSetter__ ('cookie');
var old_cookie_getter = HTMLDocument.prototype.__lookupGetter__ ('cookie');
var oldImages = HTMLDocument.prototype.__lookupGetter__('images');
var oldAnchors = HTMLDocument.prototype.__lookupGetter__('anchors');
var oldLinks = HTMLDocument.prototype.__lookupGetter__('links');
var oldApplets = HTMLDocument.prototype.__lookupGetter__('applets');
var oldForms = HTMLDocument.prototype.__lookupGetter__('forms');
var oldURL = HTMLDocument.prototype.__lookupGetter__('URL');
var oldDomain = HTMLDocument.prototype.__lookupGetter__('domain');
var oldTitle = HTMLDocument.prototype.__lookupGetter__('title');
var oldReferrer = HTMLDocument.prototype.__lookupGetter__('referrer');
var oldLastModified = HTMLDocument.prototype.__lookupGetter__('lastModified');
//Define new DOM Special Properties
if (old_cookie_getter)
{
	var newCookieGetter = function(){
		var callerInfo = getCallerInfo();	
		if (callerInfo!=null){
			seqID++;
			if (recordedDOMActions['document.cookie read!'+callerInfo]!=true)
			{
				recordedDOMActions['document.cookie read!'+callerInfo] = true;
				record[documentRecord].push({what:'document.cookie read!',when:seqID,who:callerInfo});
			}
		}
		return old_cookie_getter.apply(document);
	};
}
if (old_cookie_setter)
{
	var newCookieSetter = function(str){
		var callerInfo = getCallerInfo();	
		if (callerInfo!=null){
			seqID++;
			if (recordedDOMActions['document.cookie set!'+callerInfo]!=true)
			{
				recordedDOMActions['document.cookie set!'+callerInfo] = true;
				record[documentRecord].push({what:'document.cookie set!',when:seqID,who:callerInfo});
			}
		}
		return old_cookie_setter.call(document,str);
	};
}
if (oldImages)
{
	var newImages = function(){
		var callerInfo = getCallerInfo();	
		if (callerInfo!=null){
			seqID++;
			if (recordedDOMActions['document.images read!'+callerInfo]!=true)
			{
				recordedDOMActions['document.images read!'+callerInfo] = true;
				record[documentRecord].push({what:'document.images read!',when:seqID,who:callerInfo});
			}
		}
		return oldImages.apply(document);
	};
}
if (oldAnchors)
{
	var newAnchors = function(){
		var callerInfo = getCallerInfo();	
		if (callerInfo!=null){
			seqID++;
			if (recordedDOMActions['document.anchors read!'+callerInfo]!=true)
			{
				recordedDOMActions['document.anchors read!'+callerInfo] = true;
				record[documentRecord].push({what:'document.anchors read!',when:seqID,who:callerInfo});
			}
		}
		return oldAnchors.apply(document);
	};
}
if (oldLinks)
{
	var newLinks = function(){
		var callerInfo = getCallerInfo();	
		if (callerInfo!=null){
			seqID++;
			if (recordedDOMActions['document.links read!'+callerInfo]!=true)
			{
				recordedDOMActions['document.links read!'+callerInfo] = true;
				record[documentRecord].push({what:'document.links read!',when:seqID,who:callerInfo});
			}
		}
		return oldLinks.apply(document);
	};
}
if (oldForms)
{
	var newForms = function(){
		var callerInfo = getCallerInfo();	
		if (callerInfo!=null){
			seqID++;
			if (recordedDOMActions['document.forms read!'+callerInfo]!=true)
			{
				recordedDOMActions['document.forms read!'+callerInfo] = true;
				record[documentRecord].push({what:'document.forms read!',when:seqID,who:callerInfo});
			}
		}
		return oldForms.apply(document);
	};
}
if (oldApplets)
{
	var newApplets = function(){
		var callerInfo = getCallerInfo();	
		if (callerInfo!=null){
			seqID++;
			if (recordedDOMActions['document.applets read!'+callerInfo]!=true)
			{
				recordedDOMActions['document.applets read!'+callerInfo] = true;
				record[documentRecord].push({what:'document.applets read!',when:seqID,who:callerInfo});
			}
		}
		return oldApplets.apply(document);
	};
}
if (oldURL)
{
	var newURL = function(){
		var callerInfo = getCallerInfo();	
		if (callerInfo!=null){
			seqID++;
			if (recordedDOMActions['document.URL read!'+callerInfo]!=true)
			{
				recordedDOMActions['document.URL read!'+callerInfo] = true;
				record[documentRecord].push({what:'document.URL read!',when:seqID,who:callerInfo});
			}
		}
		return oldURL.apply(document);
	};
}
if (oldDomain)
{
	var newDomain = function(){
		var callerInfo = getCallerInfo();	
		if (callerInfo!=null){
			seqID++;
			if (recordedDOMActions['document.domain read!'+callerInfo]!=true)
			{
				recordedDOMActions['document.domain read!'+callerInfo] = true;
				record[documentRecord].push({what:'document.domain read!',when:seqID,who:callerInfo});
			}
		}
		return oldDomain.apply(document);
	};
}
if (oldTitle)
{
	var newTitle = function(){
		var callerInfo = getCallerInfo();	
		if (callerInfo!=null){
			seqID++;
			if (recordedDOMActions['document.title read!'+callerInfo]!=true)
			{
				recordedDOMActions['document.title read!'+callerInfo] = true;
				record[documentRecord].push({what:'document.title read!',when:seqID,who:callerInfo});
			}
		}
		return oldTitle.apply(document);
	};
}
if (oldReferrer)
{
	var newReferrer = function(){
		var callerInfo = getCallerInfo();	
		if (callerInfo!=null){
			seqID++;
			if (recordedDOMActions['document.referrer read!'+callerInfo]!=true)
			{
				recordedDOMActions['document.referrer read!'+callerInfo] = true;
				record[documentRecord].push({what:'document.referrer read!',when:seqID,who:callerInfo});
			}
		}
		return oldReferrer.apply(document);
	};
}
if (oldLastModified)
{
	var newLastModified = function(){
		var callerInfo = getCallerInfo();	
		if (callerInfo!=null){
			seqID++;
			if (recordedDOMActions['document.lastModified read!'+callerInfo]!=true)
			{
				recordedDOMActions['document.lastModified read!'+callerInfo] = true;
				record[documentRecord].push({what:'document.lastModified read!',when:seqID,who:callerInfo});
			}
		}
		return oldLastModified.apply(document);
	};
}
//Set default DOM special Properties to newly defined APIs.
if (newCookieGetter)
{
	HTMLDocument.prototype.__defineGetter__("cookie",newCookieGetter);
}
if (newCookieSetter)
{
	HTMLDocument.prototype.__defineSetter__("cookie",newCookieSetter);
}
if (newImages)
{
	HTMLDocument.prototype.__defineGetter__("images",newImages);
}
if (newAnchors)
{
	HTMLDocument.prototype.__defineGetter__("anchors",newAnchors);
}
if (newForms)
{
	HTMLDocument.prototype.__defineGetter__("forms",newForms);
}
if (newLinks)
{
	HTMLDocument.prototype.__defineGetter__("links",newLinks);
}
if (newApplets)
{
	HTMLDocument.prototype.__defineGetter__("applets",newApplets);
}
if (newTitle)
{
	HTMLDocument.prototype.__defineGetter__("title",newTitle);
}
if (newDomain)
{
	HTMLDocument.prototype.__defineGetter__("domain",newDomain);
}
if (newURL)
{
	HTMLDocument.prototype.__defineGetter__("URL",newURL);
}
if (newReferrer)
{
	HTMLDocument.prototype.__defineGetter__("referrer",newReferrer);
}
if (newLastModified)
{
	HTMLDocument.prototype.__defineGetter__("lastModified",newLastModified);
}
//old window-associated special property accessors:
var oldUserAgent = Navigator.prototype.__lookupGetter__("userAgent");
var oldPlatform = Navigator.prototype.__lookupGetter__("platform");
var oldAppCodeName = Navigator.prototype.__lookupGetter__("appCodeName");
var oldAppVersion = Navigator.prototype.__lookupGetter__("appVersion");
var oldAppName = Navigator.prototype.__lookupGetter__("appName");
var oldCookieEnabled = Navigator.prototype.__lookupGetter__("cookieEnabled");
var oldAvailHeight = Screen.prototype.__lookupGetter__("availHeight");
var oldAvailWidth = Screen.prototype.__lookupGetter__("availWidth");
var oldColorDepth = Screen.prototype.__lookupGetter__("colorDepth");
var oldHeight = Screen.prototype.__lookupGetter__("height");
var oldPixelDepth = Screen.prototype.__lookupGetter__("pixelDepth");
var oldWidth = Screen.prototype.__lookupGetter__("width");
//define new window special property accessors:
if (oldUserAgent) { 
	var newUserAgent = function(){ 
		var callerInfo = getCallerInfo(); 
		if (callerInfo!=null) {
			seqID++;
			if (recordedDOMActions['navigator.userAgent read!'+callerInfo]!=true)
			{
				recordedDOMActions['navigator.userAgent read!'+callerInfo] = true;
				record[windowRecord].push({what:'navigator.userAgent read!',when:seqID,who:callerInfo});
			}
		} 
		return oldUserAgent.apply(navigator);
	};
}
if (oldPlatform) { 
	var newPlatform = function(){ 
		var callerInfo = getCallerInfo(); 
		if (callerInfo!=null) {
			seqID++;
			if (recordedDOMActions['navigator.platform read!'+callerInfo]!=true)
			{
				recordedDOMActions['navigator.platform read!'+callerInfo] = true;
				record[windowRecord].push({what:'navigator.platform read!',when:seqID,who:callerInfo});
			}
		} 
		return oldPlatform.apply(navigator);
	};
}
if (oldAppCodeName) { 
	var newAppCodeName = function(){ 
		var callerInfo = getCallerInfo(); 
		if (callerInfo!=null) {
			seqID++;
			if (recordedDOMActions['navigator.appCodeName read!'+callerInfo]!=true)
			{
				recordedDOMActions['navigator.appCodeName read!'+callerInfo] = true;
				record[windowRecord].push({what:'navigator.appCodeName read!',when:seqID,who:callerInfo});
			}
		} 
		return oldAppCodeName.apply(navigator);
	};
}
if (oldAppVersion) { 
	var newAppVersion = function(){ 
		var callerInfo = getCallerInfo(); 
		if (callerInfo!=null) {
			seqID++;
			if (recordedDOMActions['navigator.appVersion read!'+callerInfo]!=true)
			{
				recordedDOMActions['navigator.appVersion read!'+callerInfo] = true;
				record[windowRecord].push({what:'navigator.appVersion read!',when:seqID,who:callerInfo});
			}
		} 
		return oldAppVersion.apply(navigator);
	};
}
if (oldAppName) { 
	var newAppName = function(){ 
		var callerInfo = getCallerInfo(); 
		if (callerInfo!=null) {
			seqID++;
			if (recordedDOMActions['navigator.appName read!'+callerInfo]!=true)
			{
				recordedDOMActions['navigator.appName read!'+callerInfo] = true;
				record[windowRecord].push({what:'navigator.appName read!',when:seqID,who:callerInfo});
			}
		} 
		return oldAppName.apply(navigator);
	};
}
if (oldCookieEnabled) { 
	var newCookieEnabled = function(){ 
		var callerInfo = getCallerInfo(); 
		if (callerInfo!=null) {
			seqID++;
			if (recordedDOMActions['navigator.cookieEnabled read!'+callerInfo]!=true)
			{
				recordedDOMActions['navigator.cookieEnabled read!'+callerInfo] = true;
				record[windowRecord].push({what:'navigator.cookieEnabled read!',when:seqID,who:callerInfo});
			}
		} 
		return oldCookieEnabled.apply(navigator);
	};
}
if (oldAvailWidth) { 
	var newAvailWidth = function(){ 
		var callerInfo = getCallerInfo(); 
		if (callerInfo!=null) {
			seqID++;
			if (recordedDOMActions['navigator.availWidth read!'+callerInfo]!=true)
			{
				recordedDOMActions['navigator.availWidth read!'+callerInfo] = true;
				record[windowRecord].push({what:'navigator.availWidth read!',when:seqID,who:callerInfo});
			}
		} 
		return oldAvailWidth.apply(screen);
	};
}
if (oldAvailHeight) { 
	var newAvailHeight = function(){ 
		var callerInfo = getCallerInfo(); 
		if (callerInfo!=null) {
			seqID++;
			if (recordedDOMActions['navigator.availHeight read!'+callerInfo]!=true)
			{
				recordedDOMActions['navigator.availHeight read!'+callerInfo] = true;
				record[windowRecord].push({what:'navigator.availHeight read!',when:seqID,who:callerInfo});
			}
		} 
		return oldAvailHeight.apply(screen);
	};
}
if (oldColorDepth) { 
	var newColorDepth = function(){ 
		var callerInfo = getCallerInfo(); 
		if (callerInfo!=null) {
			seqID++;
			if (recordedDOMActions['navigator.colorDepth read!'+callerInfo]!=true)
			{
				recordedDOMActions['navigator.colorDepth read!'+callerInfo] = true;
				record[windowRecord].push({what:'navigator.colorDepth read!',when:seqID,who:callerInfo});
			}
		} 
		return oldColorDepth.apply(screen);
	};
}
if (oldHeight) { 
	var newHeight = function(){ 
		var callerInfo = getCallerInfo(); 
		if (callerInfo!=null) {
			seqID++;
			if (recordedDOMActions['navigator.height read!'+callerInfo]!=true)
			{
				recordedDOMActions['navigator.height read!'+callerInfo] = true;
				record[windowRecord].push({what:'navigator.height read!',when:seqID,who:callerInfo});
			}
		} 
		return oldHeight.apply(screen);
	};
}
if (oldWidth) { 
	var newWidth = function(){ 
		var callerInfo = getCallerInfo(); 
		if (callerInfo!=null) {
			seqID++;
			if (recordedDOMActions['navigator.width read!'+callerInfo]!=true)
			{
				recordedDOMActions['navigator.width read!'+callerInfo] = true;
				record[windowRecord].push({what:'navigator.width read!',when:seqID,who:callerInfo});
			}
		} 
		return oldWidth.apply(screen);
	};
}
if (oldPixelDepth) { 
	var newPixelDepth = function(){ 
		var callerInfo = getCallerInfo(); 
		if (callerInfo!=null) {
			seqID++;
			if (recordedDOMActions['navigator.pixelDepth read!'+callerInfo]!=true)
			{
				recordedDOMActions['navigator.pixelDepth read!'+callerInfo] = true;
				record[windowRecord].push({what:'navigator.pixelDepth read!',when:seqID,who:callerInfo});
			}
		} 
		return oldPixelDepth.apply(screen);
	};
}
//override the old window special property accessors:
if (newUserAgent) { Navigator.prototype.__defineGetter__("userAgent",newUserAgent); }
if (newPlatform) { Navigator.prototype.__defineGetter__("platform",newPlatform); }
if (newAppCodeName) { Navigator.prototype.__defineGetter__("appCodeName",newAppCodeName); }
if (newAppVersion) { Navigator.prototype.__defineGetter__("appVersion",newAppVersion); }
if (newAppName) { Navigator.prototype.__defineGetter__("appName",newAppName); }
if (newCookieEnabled) { Navigator.prototype.__defineGetter__("cookieEnabled",newCookieEnabled); }
if (newAvailWidth) { Screen.prototype.__defineGetter__("availWidth",newAvailWidth); }
if (newAvailHeight) { Screen.prototype.__defineGetter__("availHeight",newAvailHeight); }
if (newColorDepth) { Screen.prototype.__defineGetter__("colorDepth",newColorDepth); }
if (newHeight) { Screen.prototype.__defineGetter__("height",newHeight); }
if (newWidth) { Screen.prototype.__defineGetter__("width",newWidth); }
if (newPixelDepth) { Screen.prototype.__defineGetter__("pixelDepth",newPixelDepth); }

//Set default accessors to newly defined APIs.

if (newGetId)
{
	document.getElementById = newGetId;
}
if (newGetClassName)
{
	document.getElementsByClassName = newGetClassName;
}
if (newGetTagName)
{
	document.getElementsByTagName = newGetTagName;
}
if (newGetTagNameNS)
{
	document.getElementsByTagNameNS = newGetTagNameNS;
}
if (newGetName)
{
	document.getElementsByName = newGetName;
}
//Set property accessors to new traversal APIs.
var i = 0;
var oldEGetTagName = new Array();
var oldEGetClassName = new Array();
var oldEGetTagNameNS = new Array();
var oldEQuerySelector = new Array();
var oldEQuerySelectorAll = new Array();
for (; i<allElementsType.length; i++)
{
	//store element.getElementsByTagName to old value
	oldEGetTagName[allElementsType[i]] = allElementsType[i].prototype.getElementsByTagName;
	oldEGetClassName[allElementsType[i]] = allElementsType[i].prototype.getElementsByClassName;
	oldEGetTagNameNS[allElementsType[i]] = allElementsType[i].prototype.getElementsByTagNameNS;
	oldEQuerySelector[allElementsType[i]] = allElementsType[i].prototype.querySelector;
	oldEQuerySelectorAll[allElementsType[i]] = allElementsType[i].prototype.querySelectorAll;
	allElementsType[i].prototype.__defineGetter__('parentNode',function(){var returnValue = oldParentNode.apply(this); var callerInfo = getCallerInfo(); if (callerInfo!=null) {var thispathA = getXPathA(returnValue); var thispathR = getXPathR(returnValue); if (thispathA!="") {seqID++; if (recordedDOMActions[thispathA+callerInfo]!=true) { recordedDOMActions[thispathA+callerInfo]=true; record[DOMRecord].push({what:thispathA,when:seqID,who:callerInfo,whatR:thispathR});}}} return returnValue;});
	
	allElementsType[i].prototype.__defineGetter__('nextSibling',function(){var returnValue = oldNextSibling.apply(this); var callerInfo = getCallerInfo(); if (callerInfo!=null) {var thispathA = getXPathA(returnValue); var thispathR = getXPathR(returnValue); if (thispathA!="") {seqID++; if (recordedDOMActions[thispathA+callerInfo]!=true) { recordedDOMActions[thispathA+callerInfo]=true; record[DOMRecord].push({what:thispathA,when:seqID,who:callerInfo,whatR:thispathR});}}} return returnValue;});

	allElementsType[i].prototype.__defineGetter__('previousSibling',function(){var returnValue = oldPreviousSibling.apply(this); var callerInfo = getCallerInfo(); if (callerInfo!=null) {var thispathA = getXPathA(returnValue); var thispathR = getXPathR(returnValue); if (thispathA!="") {seqID++; if (recordedDOMActions[thispathA+callerInfo]!=true) { recordedDOMActions[thispathA+callerInfo]=true; record[DOMRecord].push({what:thispathA,when:seqID,who:callerInfo,whatR:thispathR});}}} return returnValue;});

	allElementsType[i].prototype.__defineGetter__('firstChild',function(){var returnValue = oldFirstChild.apply(this); var callerInfo = getCallerInfo(); if (callerInfo!=null) {var thispathA = getXPathA(returnValue); var thispathR = getXPathR(returnValue); if (thispathA!="") {seqID++; if (recordedDOMActions[thispathA+callerInfo]!=true) { recordedDOMActions[thispathA+callerInfo]=true; record[DOMRecord].push({what:thispathA,when:seqID,who:callerInfo,whatR:thispathR});}}} return returnValue;});
	
	allElementsType[i].prototype.__defineGetter__('lastChild',function(){var returnValue = oldLastChild.apply(this); var callerInfo = getCallerInfo(); if (callerInfo!=null) {var thispathA = getXPathA(returnValue); var thispathR = getXPathR(returnValue); if (thispathA!="") {seqID++; if (recordedDOMActions[thispathA+callerInfo]!=true) { recordedDOMActions[thispathA+callerInfo]=true; record[DOMRecord].push({what:thispathA,when:seqID,who:callerInfo,whatR:thispathR});}}} return returnValue;});

	allElementsType[i].prototype.__defineGetter__('children',function(){var callerInfo = getCallerInfo(); if (callerInfo==null) {return oldChildren.apply(this);} var thispathA = getXPathA(this); var thispathR = getXPathR(this); if (thispathA!="") {seqID++; if (recordedDOMActions["Children called on: "+thispathA+callerInfo]!=true) { recordedDOMActions["Children called on: "+thispathA+callerInfo]=true; record[DOMRecord].push({what:thispathA,when:seqID,who:callerInfo,whatR:thispathR,extraInfo:"children"});}} return oldChildren.apply(this);});

	allElementsType[i].prototype.__defineGetter__('childNodes',function(){var callerInfo = getCallerInfo(); if (callerInfo==null) {return oldChildNodes.apply(this);} var thispathA = getXPathA(this); var thispathR = getXPathR(this); if (thispathA!="") {seqID++; if (recordedDOMActions["childNodes called on: "+thispathA+callerInfo]!=true) { recordedDOMActions["childNodes called on: "+thispathA+callerInfo]=true; record[DOMRecord].push({what:thispathA,when:seqID,who:callerInfo,whatR:thispathR,extraInfo:"childNodes"});}} return oldChildNodes.apply(this);});

}
var oldGetAttr = new Array();
var oldSetAttr = new Array();
var oldHasAttr = new Array();
var oldInsertBefore = new Array();
var oldAppendChild = new Array();
var oldReplaceChild = new Array();
var oldAttributes = new Array();
//assign element.getElementsByTagName to new value
for (i=0; i<allElementsType.length; i++)
{
	oldGetAttr[allElementsType[i]] = allElementsType[i].prototype.getAttribute;
	oldSetAttr[allElementsType[i]] = allElementsType[i].prototype.setAttribute;
	oldHasAttr[allElementsType[i]] = allElementsType[i].prototype.hasAttribute;
	oldInsertBefore[allElementsType[i]] = allElementsType[i].prototype.insertBefore;
	oldAppendChild[allElementsType[i]] = allElementsType[i].prototype.appendChild;
	oldReplaceChild[allElementsType[i]] = allElementsType[i].prototype.replaceChild;
	oldAttributes[allElementsType[i]] = allElementsType[i].prototype.__lookupGetter__('attributes');
	allElementsType[i].prototype.getElementsByTagName = function(){
		var func = oldEGetTagName[this.constructor];
		if (func==undefined) func = oldEGetTagName[HTMLObjectElement];
		//record.push('Called someElement.getElementsByTagName('+arguments[0]+');');	//This is only going to add a English prose to record.
		var callerInfo = getCallerInfo();
		if (callerInfo!=null)
		{
			var thispathA = getXPathA(this);
			var thispathR = getXPathR(this);
			if (thispathA!="")
			{
				seqID++;
				if (recordedDOMActions["getElementsByTagName called on "+thispathA+" Tag: "+arguments[0]+callerInfo]!=true) 
				{ 
					recordedDOMActions["getElementsByTagName called on "+thispathA+" Tag: "+arguments[0]+callerInfo]=true; 
					record[DOMRecord].push({what:thispathA,when:seqID,who:callerInfo,whatR:thispathR,extraInfo:"getElementsByTagName, Tag:"+arguments[0]});			
				}
			}
		}
		return func.apply(this,arguments);
	};
	allElementsType[i].prototype.getElementsByClassName = function(){
		var func = oldEGetClassName[this.constructor];
		if (func==undefined) func = oldEGetClassName[HTMLObjectElement];
		//record.push('Called someElement.getElementsByClassName('+arguments[0]+');');	//This is only going to add a English prose to record.
		var callerInfo = getCallerInfo();
		if (callerInfo!=null)
		{
			var thispathA = getXPathA(this);
			var thispathR = getXPathR(this);
			if (thispathA!="")
			{
				seqID++;
				if (recordedDOMActions["getElementsByClassName called on "+thispathA+" Class: "+arguments[0]+callerInfo]!=true) 
				{ 
					recordedDOMActions["getElementsByClassName called on "+thispathA+" Class: "+arguments[0]+callerInfo]=true; 
					record[DOMRecord].push({what:thispathA,when:seqID,who:callerInfo,whatR:thispathR,extraInfo:"getElementsByClassName, Tag:"+arguments[0]});
				}
			}
		}
		return func.apply(this,arguments);
	};
	allElementsType[i].prototype.getElementsByTagNameNS = function(){
		var func = oldEGetTagNameNS[this.constructor];
		if (func==undefined) func = oldEGetTagNameNS[HTMLObjectElement];
		//record.push('Called someElement.getElementsByTagNameNS('+arguments[0]+');');	//This is only going to add a English prose to record.
		var callerInfo = getCallerInfo();
		if (callerInfo!=null)
		{
			var thispathA = getXPathA(this);
			var thispathR = getXPathR(this);
			if (thispathA!="")
			{
				seqID++;
				if (recordedDOMActions["getElementsByTagNameNS called on "+thispathA+" NS: "+arguments[0]+" Tag: "+arguments[1]+callerInfo]!=true) 
				{ 
					recordedDOMActions["getElementsByTagNameNS called on "+thispathA+" NS: "+arguments[0]+" Tag: "+arguments[1]+callerInfo]=true; 
					record[DOMRecord].push({what:thispathA,when:seqID,who:callerInfo,whatR:thispathR,extraInfo:"getElementsByTagNameNS, NS: "+arguments[0]+", Tag: "+arguments[1]});
				}
			}
		}
		return func.apply(this,arguments);
	};
	allElementsType[i].prototype.querySelector = function(){
		var func = oldEQuerySelector[this.constructor];
		if (func==undefined) func = oldEQuerySelector[HTMLObjectElement];
		var returnValue = func.apply(this,arguments);
		var callerInfo = getCallerInfo();
		if (callerInfo==null) return returnValue;
		var thispathA = getXPathA(returnValue);
		var thispathR = getXPathR(returnValue);
		if (thispathA!="")
		{
			seqID++;
			if (recordedDOMActions[thispathA+callerInfo]!=true) documentRecord
			{ 
				recordedDOMActions[thispathA+callerInfo]=true; 
				record[DOMRecord].push({what:thispathA,when:seqID,who:callerInfo,whatR:thispathR});			
			}
		}
		return returnValue;
	};
	allElementsType[i].prototype.querySelectorAll = function(){
		var func = oldEQuerySelectorAll[this.constructor];
		if (func==undefined) func = oldEQuerySelectorAll[HTMLObjectElement];
		var callerInfo = getCallerInfo();
		if (callerInfo!=null)
		{
			var thispathA = getXPathA(this);
			var thispathR = getXPathR(this);
			if (thispathA!="")
			{
				seqID++;
				if (recordedDOMActions["querySelectorAll called on "+thispathA+" Tag: "+arguments[0]+callerInfo]!=true) 
				{ 
					recordedDOMActions["querySelectorAll called on "+thispathA+" Tag: "+arguments[0]+callerInfo]=true; 
					record[DOMRecord].push({what:thispathA,when:seqID,who:callerInfo,whatR:thispathR,extraInfo:"querySelectorAll, Tag:"+arguments[0]});			
				}
			}
		}
		return func.apply(this,arguments);
	};
////////////////////////////

	allElementsType[i].prototype.getAttribute = function(){
		//of course, there is more ways to get/set attribute, including getAttributeNode, even innerHTML and then parse it. This is not a complete defense but could be if we really want to deploy it.
		var func = oldGetAttr[this.constructor];
		if (func==undefined) func = oldGetAttr[HTMLObjectElement];
		if ((arguments[0]!=null)&&(arguments[0].toLowerCase!=null)&&(arguments[0].toLowerCase()=="specialid"))
		{
			var thispathA = getXPathA(this);
			var thispathR = getXPathR(this);
			var callerInfo = getCallerInfo();
			if ((thispathA!="")&&(callerInfo!=null))
			{
				seqID++;
				if (recordedDOMActions["getAttribute specialId called on "+thispathA+callerInfo]!=true) 
				{ 
					recordedDOMActions["getAttribute specialId called on "+thispathA+callerInfo]=true; 
					record[DOMRecord].push({what:thispathA,when:seqID,who:callerInfo,whatR:thispathR,extraInfo:"getAttribute specialId called"});
				}
			}
		}
		return func.apply(this,arguments);
	};
	allElementsType[i].prototype.setAttribute = function(){
		var func = oldSetAttr[this.constructor];
		if (func==undefined) func = oldSetAttr[HTMLObjectElement];
		if ((arguments[0]!=null)&&(arguments[0].toLowerCase!=null)&&(arguments[0].toLowerCase()=="specialid"))
		{
			var thispathA = getXPathA(this);
			var thispathR = getXPathR(this);
			var callerInfo = getCallerInfo("setAttribute");
			if ((thispathA!="")&&(callerInfo!=null))
			{
				seqID++;
				if (recordedDOMActions["setAttribute specialId called on "+thispathA+" attr: "+arguments[1]+callerInfo]!=true) 
				{ 
					recordedDOMActions["setAttribute specialId called on "+thispathA+" attr: "+arguments[1]+callerInfo]=true; 
					record[DOMRecord].push({what:thispathA,when:seqID,who:callerInfo,whatR:thispathR,extraInfo:"setAttribute specialId called, attr: "+arguments[1]});
				}
			}
		}
		return func.apply(this,arguments);
	};
	allElementsType[i].prototype.hasAttribute = function(){
		var func = oldHasAttr[this.constructor];
		if (func==undefined) func = oldHasAttr[HTMLObjectElement];
		if ((arguments[0]!=null)&&(arguments[0].toLowerCase!=null)&&(arguments[0].toLowerCase()=="specialid"))
		{
			var thispathA = getXPathA(this);
			var thispathR = getXPathR(this);
			var callerInfo = getCallerInfo("hasAttribute");
			if ((thispathA!="")&&(callerInfo!=null))
			{
				seqID++;
				if (recordedDOMActions["hasAttribute specialId called on "+thispathA+callerInfo]!=true) 
				{ 
					recordedDOMActions["hasAttribute specialId called on "+thispathA+callerInfo]=true; 
					record[DOMRecord].push({what:thispathA,when:seqID,who:callerInfo,whatR:thispathR,extraInfo:"hasAttribute specialId called"});
				}
			}
		}
		return func.apply(this,arguments);
	};
	allElementsType[i].prototype.insertBefore = function(){
	//var insertedElement = parentElement.insertBefore(newElement, referenceElement);
		var func = oldInsertBefore[this.constructor];
		var get = oldGetAttr[this.constructor];
		if (func==undefined) 
		{
			func = oldInsertBefore[HTMLObjectElement];
			get = oldGetAttr[HTMLObjectElement];
		}
		if ((arguments[0]!=null)&&(arguments[0].getAttribute!=null)&&(get.apply(arguments[0],["specialId"])!=null))
		{
			arguments[0].removeAttribute("specialId");
		}
		return func.apply(this,arguments);
	};
	allElementsType[i].prototype.appendChild = function(){
		var func = oldAppendChild[this.constructor];
		var get = oldGetAttr[this.constructor];
		if (func==undefined) 
		{
			func = oldAppendChild[HTMLObjectElement];
			get = oldGetAttr[HTMLObjectElement];
		}
		if ((arguments[0]!=null)&&(arguments[0].getAttribute!=null)&&(get.apply(arguments[0],["specialId"])!=null))
		{
			arguments[0].removeAttribute("specialId");
		}
		return func.apply(this,arguments);
	};
	allElementsType[i].prototype.replaceChild = function(){
	//replacedNode = parentNode.replaceChild(newChild, oldChild);
		var func = oldReplaceChild[this.constructor];
		var get = oldGetAttr[this.constructor];
		if (func==undefined) 
		{
			func = oldReplaceChild[HTMLObjectElement];
			get = oldGetAttr[HTMLObjectElement];
		}
		if ((arguments[0]!=null)&&(arguments[0].getAttribute!=null)&&(get.apply(arguments[0],["specialId"])!=null))
		{
			arguments[0].removeAttribute("specialId");
		}
		return func.apply(this,arguments);
	};
	newAttributes = function(){
		var func = oldAttributes[this.constructor];
		if (func==undefined) func = oldAttributes[HTMLObjectElement];
		returnValue = func.apply(this,arguments);
		if (returnValue.getNamedItem('specialId')==null) return returnValue;
		cur_Attributes[returnValue.specialId.value] = this;
		returnValue.removeNamedItem('specialId');
		return returnValue;
	};
	allElementsType[i].prototype.__defineGetter__('attributes',newAttributes);
	///////////////////////////////////////////////////
	if (oldInnerHTMLGetter)
	{
		allElementsType[i].prototype.__defineGetter__('innerHTML',function(str){
			var callerInfo = getCallerInfo("innerHTML");
			if (callerInfo==null) return oldInnerHTMLGetter.call(this,str);
			var thispathA = getXPathA(this);
			var thispathR = getXPathR(this);
			if (thispathA!="")
			{
				seqID++;
				if (recordedDOMActions['Read innerHTML of this element: '+thispathA+'!'+callerInfo]!=true) 
				{ 
					recordedDOMActions['Read innerHTML of this element: '+thispathA+'!'+callerInfo]=true; 
					record[DOMRecord].push({what:thispathA,when:seqID,who:callerInfo,whatR:thispathR,extraInfo:"innerHTML read"});
				}
			}
			//strip specialId from all children.
			clearSpecialId(this);
			return oldInnerHTMLGetter.call(this,str);
		});
	}
	if (oldTextContentGetter)
	{
		allElementsType[i].prototype.__defineGetter__('textContent',function(str){
		var callerInfo = getCallerInfo("textContent");
		if (callerInfo==null) return oldTextContentGetter.call(this,str);
		var thispathA = getXPathA(this);
		var thispathR = getXPathR(this);
		if (thispathA!="")
		{
			seqID++;
			if (recordedDOMActions['Read textContent of this element: '+thispathA+'!'+callerInfo]!=true) 
			{ 
				recordedDOMActions['Read textContent of this element: '+thispathA+'!'+callerInfo]=true; 
				record[DOMRecord].push({what:thispathA,when:seqID,who:callerInfo,whatR:thispathR,extraInfo:"textContent read"});
			}
		}
		return oldTextContentGetter.call(this,str);
		});
	}
	//allElementsType[i].prototype.__defineGetter__('attributes',function(){record.push(getXPathCollection(oldAttributes.apply(this)));return oldAttributes.apply(this);});		//attribute nodes are detached from the DOM tree. Currently we do not support mediation of this.
}

function writePolicy()
{	
	var posturl = "http://chromium.cs.virginia.edu:12348/cgi-bin/DOMAR.rb";
	if (window.___record==undefined) return;
	var url = document.URL;
	var domain = document.domain;
	domain = domain.replace(/(.*)\.(.*)\.(.*)$/,"$2.$3");
	if (url.indexOf("?")>0)
	{
		//Now we ignore the GET parameters
		url = url.substr(0,url.indexOf("?"));
	}
	//urlfile = url.replace(/[^a-zA-Z0-9]/g,"");	//\W also does the trick.
	urlfile = url.substr(0,240);						//restrict the file length
	domain = domain.replace(/[^a-zA-Z0-9]/g,"");
	domain = domain.substr(0,240);
	var i;
	var rawdata = window._record.getRecord();
	// If rawdata doesn't have anything, don't send anything.
	if ((rawdata[0].length==0)&&(rawdata[1].length==0)&&(rawdata[2].length==0)) return;
	// From here down: writing bytes to file. file is nsIFile, data is a string
	var rawstring = "";
	for (i = 0; i < rawdata[0].length; i++)
	{
		//0 means DOM node accesses;
		if ((rawdata[0][i].what!="")&&(rawdata[0][i].who!="trusted"))
		{
			//Rigth now we only track accesses on element node, text node and attribute node. If the node is 'others', xpath is gonna return "",
			//so we ignore it here.
			//We also ignore sequence info now.
			rawstring = rawstring + rawdata[0][i].whatR;
			//if ((rawdata[0][i].whatR)&&(rawdata[0][i].whatR!="")) rawstring = rawstring +" <=:| "+rawdata[0][i].whatR;
			rawstring = rawstring +" <=:| "+rawdata[0][i].what;
			rawstring = rawstring + " |:=> "+rawdata[0][i].who;
			if ((rawdata[0][i].extraInfo)&&(rawdata[0][i].extraInfo!="")) 
			{
				eI = rawdata[0][i].extraInfo;
				eI = eI.replace(/[\r\n]/g,"");
				rawstring = rawstring +" <=|:| " + eI;
			}
			rawstring += "\n\n";
		}
	}
	rawstring = rawstring + "\nEnd of DOM node access\n---------------------------------------\n";
	for (i = 0; i < rawdata[1].length; i++)
	{
		//1 means window accesses;
		if ((rawdata[1][i].what!="")&&(rawdata[1][i].who!="trusted"))
		{
			rawstring = rawstring + rawdata[1][i].what+" |:=> "+rawdata[1][i].who+"\n\n";
		}
	}
	rawstring = rawstring + "\nEnd of window special property access\n---------------------------------------\n";
	for (i = 0; i < rawdata[2].length; i++)
	{
		//2 means document accesses;
		if ((rawdata[2][i].what!="")&&(rawdata[2][i].who!="trusted"))
		{
			rawstring = rawstring + rawdata[2][i].what+" |:=> "+rawdata[2][i].who+"\n\n";
		}
	}
	rawstring = rawstring + "\nEnd of document special property access\n";						
	//AJAX to server
	var payload = "id="+escape(filecnt)+"&url="+escape(urlfile)+"&domain="+escape(domain)+"&trace="+escape(rawstring);		
	var http = new XMLHttpRequest();
	http.open("POST", posturl, false);
	http.setRequestHeader("Content-type", "application/x-www-form-urlencoded");
	http.send(payload);
};

window.addEventListener('beforeunload',writePolicy,true);
//window.setTimeout("_record.writePolicy2();",5000);
//document.head.removeChild(oldGetTagName.call(document,'script')[0]);			//remove myself
return (function(){this.getRecord = function(){return record;}; this.writePolicy2 = writePolicy; this.Push = function(a){if (a!="") trustedDomains.push(a)}; this.setId = function(id){if (id!="") filecnt = id;}; this.cur_Attributes = cur_Attributes; this.Get = function() {return trustedDomains}; return this;});
}

__record = new ___record();
_record = __record();
