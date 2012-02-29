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
var training = false;
if (document.head.parentNode.getAttribute('specialId')!=null) training = true;		//FIXME: this is ad hoc right now.
var enableV = training;						//used to remember the vicinity of the accessed nodes for automatic policy relearning.
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
//Enumerates all types of elements to mediate properties like parentNode
//According to DOM spec level2 by W3C, HTMLBaseFontElement not defined in FF.
var allElementsType = [HTMLElement,HTMLHtmlElement,HTMLHeadElement,HTMLLinkElement,HTMLTitleElement,HTMLMetaElement,HTMLBaseElement,HTMLStyleElement,HTMLBodyElement,HTMLFormElement,HTMLSelectElement,HTMLOptGroupElement,HTMLOptionElement,HTMLInputElement,HTMLTextAreaElement,HTMLButtonElement,HTMLLabelElement,HTMLFieldSetElement,HTMLLegendElement,HTMLUListElement,HTMLDListElement,HTMLDirectoryElement,HTMLMenuElement,HTMLLIElement,HTMLDivElement,HTMLParagraphElement,HTMLHeadingElement,HTMLQuoteElement,HTMLPreElement,HTMLBRElement,HTMLFontElement,HTMLHRElement,HTMLModElement,HTMLAnchorElement,HTMLImageElement,HTMLParamElement,HTMLAppletElement,HTMLMapElement,HTMLAreaElement,HTMLScriptElement,HTMLTableElement,HTMLTableCaptionElement,HTMLTableColElement,HTMLTableSectionElement,HTMLTableRowElement,HTMLTableCellElement,HTMLFrameSetElement,HTMLFrameElement,HTMLIFrameElement,HTMLObjectElement,HTMLSpanElement];
//These need to be here because getXPath relies on this.
var oldParentNode = Element.prototype.__lookupGetter__('parentNode');
var oldNextSibling = Element.prototype.__lookupGetter__('nextSibling');
var oldPreviousSibling = Element.prototype.__lookupGetter__('previousSibling');
var oldChildNodes = Element.prototype.__lookupGetter__('childNodes');
var oldGetAttribute = Element.prototype.getAttribute;

findPos = function(obj) 
{
	var curleft = curtop = 0;
	var width = height = 0;
	if (obj.offsetWidth) width = obj.offsetWidth;
	if (obj.offsetHeight) height = obj.offsetHeight;
	if (obj.offsetParent) {	
		do {
			curleft += obj.offsetLeft;
			curtop += obj.offsetTop;	
		} while (obj = obj.offsetParent);
	}
	return [curleft,curtop,width,height];
};
var getV = function(elt)
{
	return getTrueXPath(elt);

/*
	result = "";
	eltC = oldChildNodes.apply(elt);
	i = 0;
	if (eltC&&(eltC.length>0))
	{
		while (i < eltC.length)
		{
			if (eltC[i].nodeType == 1) result += (">" + eltC[i].tagName);
			else if (eltC[i].nodeType == 3) result += (">"+"TEXT");
			else if (eltC[i].nodeType == 2) result += (">"+"ATTR");
			i++;
		}
	}
	
	eltN = oldNextSibling.apply(elt);
	if (eltN)
	{
		if (eltN.nodeType == 1) result += ("<>"+eltN.tagName);
		else if (eltN.nodeType == 3) result += ("<>"+"TEXT");
		else if (eltN.nodeType == 2) result += ("<>"+"ATTR");
	}
	
	eltP = oldPreviousSibling.apply(elt);
	if (eltP)
	{
		if (eltP.nodeType == 1) result += ("<<>"+eltP.tagName);
		else if (eltP.nodeType == 3) result += ("<<>"+"TEXT");
		else if (eltP.nodeType == 2) result += ("<<>"+"ATTR");
	}
	
	return result;
	*/
}
 
var getTrueXPath = function(elt)
{
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
	 //if ((path=="")&&(elt!=null)) alert(elt);		//for debug purposes.
     if (path.substr(0,5)!="/HTML") return "";		//right now, if this node is not originated from HTMLDocument (e.g., some script calls createElement which does not contain any private information, we do not record this access.
	 return path;
};

var getXPath = function(elt)
{
	if (!training) return getTrueXPath(elt);
	var path = "";
    for (; elt && (elt.nodeType == 1||elt.nodeType == 3||elt.nodeType == 2); elt = oldParentNode.apply(elt))
    {
		if ((elt.nodeType ==1)&&(oldGetAttribute.apply(elt,['specialId'])!=null))
		{
			path = "//" + oldGetAttribute.apply(elt,['specialId']) + path;
			break;
		}
		idx = getElementIdx(elt);
		if (elt.nodeType ==1) xname = elt.tagName;
		else if (elt.nodeType == 3) xname = "TEXT";
		else if (elt.nodeType == 2) xname = "ATTR";
		if (idx > 1) xname += "[" + idx + "]";
		path = "/" + xname + path;
    }
	//if ((path=="")&&(elt!=null)) alert(elt);		//for debug purposes.
    if (!((path.substr(0,5)=="/HTML")||(path.substr(0,2)=="//"))) return "";		//right now, if this node is not originated from HTMLDocument (e.g., some script calls createElement which does not contain any private information, we do not record this access.
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
/*
var getXPathCollection = function (collection) {
	if (collection.length>10) return "More than 10 elements!";		//Sometimes the trace gets too big. We try to avoid that.
	path = "";
	var i = 0;
	for (; i < collection.length; i++)
	{
		var thispath = getXPath(collection[i]);
		if (thispath!="")
		{
			path = path + thispath +"; ";
		}
	}
	return path;
}
*/
//utilities:
/*
	If we only care about the top of the stack, which is not necessarily the case. Third-party scripts maybe called in the middle, e.g. Analytics provide APIs for host to call.  If this happens, we want to have a way to at least show that which third-party scripts touched which element.
		
var getCallerInfo = function() {
    try {
        this.undef();
        return null;
    } catch (e) {
		var lastline = e.stack;
		var ignored = "";
		if (lastline.length>3000) lastline = lastline.substr(lastline.length-3000,lastline.length);		//Assumes the total call stack is less than 3000 characters. avoid the situation when arguments becomes huge and regex operation virtually stalls the browser.  This could very well happen when innerHTML is changed. For example, flickr.com freezes our extension without this LOC.
		if (lastline!=e.stack) ignored = "; stack trace > 3000 chars.";					//notify the record that this message is not complete.
        lastline = lastline.replace(/[\s\S]*\n(.*)\n$/m,"$1");		//getting rid of other lines
		//var penultimateline = e.stack.replace(/[\s\S]*\n(.*)\n(.*)\n$/m,"$1");
		lastline = lastline.replace(/[\s\S]*@(.*)$/,"$1");				//get rid of the whole arguments
		//penultimateline = penultimateline.replace(/[\s\S]*@(.*)$/,"$1");
		if (lastline.match(/\?(.*)/,""))
		{
			lineNo = lastline.replace(/.*\:(.*)$/,"$1");				//extract the line number
			lastline = lastline.replace(/\?(.*)/,"");					//get rid of all the GET parameters
			lastline = lastline + ":" + lineNo;
		}
		
		//The following two cases are to indicate two corner cases which we do not cover for now. Flash-DOM access is very prevalent but it would be a disaster to focus on this.  Old setAttribute way of setting eventhandlers is deprecated and less used. For now we ignore these cases.
		//if (lastline.match(/:1$/)){
			//if (!lastline.match(/js:1$/))
			//{
				//alert(e.stack);
				//This probably is an event handler registered using old API (setAttribute onclick). FF cannot return correctly who registered it.
				//However according to MDN this registering method is deprecated.
				//Also worth noticing is that not all non js's 1st line access indicates an eventhandler.
			//}
		//}
		//if (lastline.match(/:0$/)) {
			//When actionscript in Flash/Flex tries to call related APIs, e.stack will return URI:0 as top stack, which is incorrect. However we ignore this bug because we are not specifically looking at Actionscript accesses.
			//We ignore this case for now.
			//alert(e.stack);
		//}
		
		return lastline+ignored;
    }
};
*/
//if getCallerInfo returns null, all recording functions will not record current access.
var getCallerInfo = function(caller) {
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
			ignored = "; stack trace > 3000 chars.";					//notify the record that this message is not complete.
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
				untrustedStack += curLine;
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
//New DOM-ECMAScript API
if (oldGetId)
{
	var newGetId = function(){
	var thispath = getXPath(oldGetId.apply(document,arguments));
	if (thispath!="")
	{
	//If this node is attached to the root DOM tree, but not something created out of nothing.
		//To record the sequence
		
		//To record the calling stack
		var callerInfo = getCallerInfo("getElementById");
		if (callerInfo!=null)
		//To record the acutal content.
		{
			seqID++;
			if (recordedDOMActions[thispath+callerInfo]!=true)
			{
				recordedDOMActions[thispath+callerInfo]=true;
				record[DOMRecord].push({what:thispath,when:seqID,who:callerInfo,v:(enableV?getV(oldGetId.apply(document,arguments)):"")});
			}
		}
	}
	return oldGetId.apply(document,arguments);
	};
}
if (oldGetClassName)
{
	var newGetClassName = function(){
	//record.push('Called document.getElementsByClassName('+arguments[0]+');');	//This is only going to add a English prose to record.
	//var thispath = getXPathCollection(oldGetClassName.apply(document,arguments));
	//if (thispath!="")
	//{
		var callerInfo = getCallerInfo("getElementsByClassName");
		if (callerInfo!=null)
		{
			seqID++;
			if (recordedDOMActions["getElementsByClassName called on document, Class: "+arguments[0]+callerInfo]!=true)
			{
				recordedDOMActions["getElementsByClassName called on document, Class: "+arguments[0]+callerInfo]=true;
				record[DOMRecord].push({what:"getElementsByClassName called on document, Class: "+arguments[0], when:seqID,who:callerInfo});
			}
		}
	//}
	return oldGetClassName.apply(document,arguments);
	};
}
if (oldGetTagName)
{
	var newGetTagName = function(){
	//record.push('Called document.getElementsByTagName('+arguments[0]+');');	//This is only going to add a English prose to record.
	//var thispath = getXPathCollection(oldGetTagName.apply(document,arguments));
	//if (thispath!="")
	//{
		var callerInfo = getCallerInfo("getElementsByTagName");	
		if (callerInfo!=null){
			seqID++;
			if (recordedDOMActions["getElementsByTagName called on document, Tag: "+arguments[0]+callerInfo]!=true)
			{
				recordedDOMActions["getElementsByTagName called on document, Tag: "+arguments[0]+callerInfo]=true;
				record[DOMRecord].push({what:"getElementsByTagName called on document, Tag: "+arguments[0], when:seqID,who:callerInfo});
			}
		}
	//}
	return oldGetTagName.apply(document,arguments);
	};
}
if (oldGetTagNameNS)
{
	var newGetTagNameNS = function(){
	//record.push('Called document.getElementsByTagNameNS('+arguments[0]+');');	//This is only going to add a English prose to record.
	//var thispath = getXPathCollection(oldGetTagNameNS.apply(document,arguments));
	//if (thispath!="")
	//{
		var callerInfo = getCallerInfo("getElementsByTagNameNS");	
		if (callerInfo!=null){
		seqID++;
		if (recordedDOMActions["getElementsByTagNameNS called on document, NS: "+arguments[0]+" Tag: "+arguments[1]+callerInfo]!=true)
			{
				recordedDOMActions["getElementsByTagNameNS called on document, NS: "+arguments[0]+" Tag: "+arguments[1]+callerInfo]=true;
				record[DOMRecord].push({what:"getElementsByTagNameNS called on document: NS: "+arguments[0]+" Tag: "+arguments[1], when:seqID,who:callerInfo});
			}
		}
	//}
	return oldGetTagNameNS.apply(document,arguments);
	};
}
if (oldGetName)
{
	var newGetName = function(){
	//record.push('Called document.getElementsByName('+arguments[0]+');');	//This is only going to add a English prose to record.
	//var thispath = getXPathCollection(oldGetName.apply(document,arguments));
	//if (thispath!="")
	//{	
		var callerInfo = getCallerInfo("getElementsByName");	
		if (callerInfo!=null){
			seqID++;
			if (recordedDOMActions["getElementsByName called on document, Name: "+arguments[0]+callerInfo]!=true)
			{
				recordedDOMActions["getElementsByName called on document, Name: "+arguments[0]+callerInfo]=true;
				record[DOMRecord].push({what:"getElementsByName called on document, Name: "+arguments[0], when:seqID,who:callerInfo});
			}
		}
	//}
	return oldGetName.apply(document,arguments);
	};
}

//Get original property accessors
var oldFirstChild = Element.prototype.__lookupGetter__('firstChild');
var oldLastChild = Element.prototype.__lookupGetter__('lastChild');
var oldChildren = Element.prototype.__lookupGetter__('children');
var oldAttributes = Element.prototype.__lookupGetter__('attributes');
//innerHTML
oldInnerHTMLGetter = HTMLElement.prototype.__lookupGetter__('innerHTML');
oldTextContentGetter = HTMLElement.prototype.__lookupGetter__('textContent');
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
		var callerInfo = getCallerInfo("cookie_getter");	
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
		var callerInfo = getCallerInfo("cookie_setter");	
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
		var callerInfo = getCallerInfo("document.images");	
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
		var callerInfo = getCallerInfo("document.anchors");	
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
		var callerInfo = getCallerInfo("document.links");	
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
		var callerInfo = getCallerInfo("document.forms");	
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
		var callerInfo = getCallerInfo("document.applets");	
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
		var callerInfo = getCallerInfo("document.URL");	
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
		var callerInfo = getCallerInfo("document.domain");	
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
		var callerInfo = getCallerInfo("document.title");	
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
		var callerInfo = getCallerInfo("document.referrer");	
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
		var callerInfo = getCallerInfo("document.lastModified");	
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
oldUserAgent = Navigator.prototype.__lookupGetter__("userAgent");
oldPlatform = Navigator.prototype.__lookupGetter__("platform");
oldAppCodeName = Navigator.prototype.__lookupGetter__("appCodeName");
oldAppVersion = Navigator.prototype.__lookupGetter__("appVersion");
oldAppName = Navigator.prototype.__lookupGetter__("appName");
oldCookieEnabled = Navigator.prototype.__lookupGetter__("cookieEnabled");
oldAvailHeight = Screen.prototype.__lookupGetter__("availHeight");
oldAvailWidth = Screen.prototype.__lookupGetter__("availWidth");
oldColorDepth = Screen.prototype.__lookupGetter__("colorDepth");
oldHeight = Screen.prototype.__lookupGetter__("height");
oldPixelDepth = Screen.prototype.__lookupGetter__("pixelDepth");
oldWidth = Screen.prototype.__lookupGetter__("width");
//define new window special property accessors:
if (oldUserAgent) { 
	var newUserAgent = function(){ 
		var callerInfo = getCallerInfo("userAgent"); 
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
		var callerInfo = getCallerInfo("platform"); 
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
		var callerInfo = getCallerInfo("appCodeName"); 
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
		var callerInfo = getCallerInfo("appVersion"); 
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
		var callerInfo = getCallerInfo("appName"); 
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
		var callerInfo = getCallerInfo("cookieEnabled"); 
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
		var callerInfo = getCallerInfo("availWidth"); 
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
		var callerInfo = getCallerInfo("availHeight"); 
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
		var callerInfo = getCallerInfo("colorDepth"); 
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
		var callerInfo = getCallerInfo("height"); 
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
		var callerInfo = getCallerInfo("width"); 
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
		var callerInfo = getCallerInfo("pixeldepth"); 
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

for (; i<allElementsType.length; i++)
{
	//store element.getElementsByTagName to old value
	oldEGetTagName[i] = allElementsType[i].prototype.getElementsByTagName;
	oldEGetClassName[i] = allElementsType[i].prototype.getElementsByClassName;
	oldEGetTagNameNS[i] = allElementsType[i].prototype.getElementsByTagNameNS;
	
	allElementsType[i].prototype.__defineGetter__('parentNode',function(){var thispath = getXPath(oldParentNode.apply(this)); var callerInfo = getCallerInfo("parentNode"); if ((thispath!="")&&(callerInfo!=null)) {seqID++; if (recordedDOMActions[thispath+callerInfo]!=true) { recordedDOMActions[thispath+callerInfo]=true; record[DOMRecord].push({what:thispath,when:seqID,who:callerInfo,v:(enableV?getV(oldParentNode.apply(this)):"")});}} return oldParentNode.apply(this);});
	
	allElementsType[i].prototype.__defineGetter__('nextSibling',function(){var thispath = getXPath(oldNextSibling.apply(this)); var callerInfo = getCallerInfo("nextSibling"); if ((thispath!="")&&(callerInfo!=null)) {seqID++; if (recordedDOMActions[thispath+callerInfo]!=true) { recordedDOMActions[thispath+callerInfo]=true; record[DOMRecord].push({what:thispath,when:seqID,who:callerInfo,v:(enableV?getV(oldNextSibling.apply(this)):"")});}} return oldNextSibling.apply(this);});
	
	allElementsType[i].prototype.__defineGetter__('previousSibling',function(){var thispath = getXPath(oldPreviousSibling.apply(this)); var callerInfo = getCallerInfo("previousSibling"); if ((thispath!="")&&(callerInfo!=null)) {seqID++; if (recordedDOMActions[thispath+callerInfo]!=true) { recordedDOMActions[thispath+callerInfo]=true; record[DOMRecord].push({what:thispath,when:seqID,who:callerInfo,v:(enableV?getV(oldPreviousSibling.apply(this)):"")});}} return oldPreviousSibling.apply(this);});
	
	allElementsType[i].prototype.__defineGetter__('firstChild',function(){var thispath = getXPath(oldFirstChild.apply(this)); var callerInfo = getCallerInfo("firstChild"); if ((thispath!="")&&(callerInfo!=null)) {seqID++; if (recordedDOMActions[thispath+callerInfo]!=true) { recordedDOMActions[thispath+callerInfo]=true; record[DOMRecord].push({what:thispath,when:seqID,who:callerInfo,v:(enableV?getV(oldFirstChild.apply(this)):"")});}} return oldFirstChild.apply(this);});
	
	allElementsType[i].prototype.__defineGetter__('lastChild',function(){var thispath = getXPath(oldLastChild.apply(this)); var callerInfo = getCallerInfo("lastChild"); if ((thispath!="")&&(callerInfo!=null)) {seqID++; if (recordedDOMActions[thispath+callerInfo]!=true) { recordedDOMActions[thispath+callerInfo]=true; record[DOMRecord].push({what:thispath,when:seqID,who:callerInfo,v:(enableV?getV(oldLastChild.apply(this)):"")});}} return oldLastChild.apply(this);});
	
	allElementsType[i].prototype.__defineGetter__('children',function(){var thispath = getXPath(this); var callerInfo = getCallerInfo("children"); if ((thispath!="")&&(callerInfo!=null)) {seqID++; if (recordedDOMActions["Children called on: "+thispath+callerInfo]!=true) { recordedDOMActions["Children called on: "+thispath+callerInfo]=true; record[DOMRecord].push({what:"Children called on: "+ thispath,when:seqID,who:callerInfo,v:(enableV?getV(this):"")});}} return oldChildren.apply(this);});
	
	allElementsType[i].prototype.__defineGetter__('childNodes',function(){var thispath = getXPath(this); var callerInfo = getCallerInfo("childNodes"); if ((thispath!="")&&(callerInfo!=null)) {seqID++; if (recordedDOMActions["childNodes called on: "+thispath+callerInfo]!=true) { recordedDOMActions["childNodes called on: "+thispath+callerInfo]=true; record[DOMRecord].push({what:"childNodes called on: "+thispath,when:seqID,who:callerInfo,v:(enableV?getV(this):"")});}} return oldChildNodes.apply(this);});	
}
var oldGetAttr = new Array();
var oldSetAttr = new Array();
var oldHasAttr = new Array();
var oldInsertBefore = new Array();
var oldAppendChild = new Array();
var oldReplaceChild = new Array();
//assign element.getElementsByTagName to new value
for (i=0; i<allElementsType.length; i++)
{
	oldGetAttr[i] = allElementsType[i].prototype.getAttribute;
	oldSetAttr[i] = allElementsType[i].prototype.setAttribute;
	oldHasAttr[i] = allElementsType[i].prototype.hasAttribute;
	oldInsertBefore[i] = allElementsType[i].prototype.insertBefore;
	oldAppendChild[i] = allElementsType[i].prototype.appendChild;
	oldReplaceChild[i] = allElementsType[i].prototype.replaceChild;
	allElementsType[i].prototype.getElementsByTagName = function(){
		var func = oldEGetTagName[50];		//HTMLObjectElement in FF has a bug. This is a ad hoc workaround.
		var j;
		for (j=0; j < allElementsType.length; j++)
		{
			if ((this.constructor==allElementsType[j])||(this.__proto__==allElementsType[j].prototype))
			{
				func = oldEGetTagName[j];
			}
		}
		//record.push('Called someElement.getElementsByTagName('+arguments[0]+');');	//This is only going to add a English prose to record.
		var thispath = getXPath(this);
		var callerInfo = getCallerInfo("getElementsByTagName");
		if ((thispath!="")&&(callerInfo!=null))
		{
			seqID++;
			if (recordedDOMActions["getElementsByTagName called on "+thispath+" Tag: "+arguments[0]+callerInfo]!=true) 
			{ 
				recordedDOMActions["getElementsByTagName called on "+thispath+" Tag: "+arguments[0]+callerInfo]=true; 
				record[DOMRecord].push({what:thispath,when:seqID,who:callerInfo,v:(enableV?getV(this):""),extraInfo:"getElementsByTagName, Tag:"+arguments[0]});			
			}
		}
		return func.apply(this,arguments);
	};
	allElementsType[i].prototype.getElementsByClassName = function(){
		var func;
		var j;
		for (j=0; j < allElementsType.length; j++)
		{
			if ((this.constructor==allElementsType[j])||(this.__proto__==allElementsType[j].prototype)) func = oldEGetClassName[j];
		}
		//record.push('Called someElement.getElementsByClassName('+arguments[0]+');');	//This is only going to add a English prose to record.
		var thispath = getXPath(this);
		var callerInfo = getCallerInfo("getElementsByClassName");
		if ((thispath!="")&&(callerInfo!=null))
		{
			seqID++;
			if (recordedDOMActions["getElementsByClassName called on "+thispath+" Class: "+arguments[0]+callerInfo]!=true) 
			{ 
				recordedDOMActions["getElementsByClassName called on "+thispath+" Class: "+arguments[0]+callerInfo]=true; 
				record[DOMRecord].push({what:thispath,when:seqID,who:callerInfo,v:(enableV?getV(this):""),extraInfo:"getElementsByClassName, Tag:"+arguments[0]});
			}
		}
		return func.apply(this,arguments);
	};
	allElementsType[i].prototype.getElementsByTagNameNS = function(){
		var func;
		var j;
		for (j=0; j < allElementsType.length; j++)
		{
			if ((this.constructor==allElementsType[j])||(this.__proto__==allElementsType[j].prototype)) func = oldEGetTagNameNS[j];
		}
		//record.push('Called someElement.getElementsByTagNameNS('+arguments[0]+');');	//This is only going to add a English prose to record.
		var thispath = getXPath(this);
		var callerInfo = getCallerInfo("getElementsByTagNameNS");
		if ((thispath!="")&&(callerInfo!=null))
		{
			seqID++;
			if (recordedDOMActions["getElementsByTagNameNS called on "+thispath+" NS: "+arguments[0]+" Tag: "+arguments[1]+callerInfo]!=true) 
			{ 
				recordedDOMActions["getElementsByTagNameNS called on "+thispath+" NS: "+arguments[0]+" Tag: "+arguments[1]+callerInfo]=true; 
				record[DOMRecord].push({what:thispath,when:seqID,who:callerInfo,v:(enableV?getV(this):""),extraInfo:"getElementsByTagNameNS, NS: "+arguments[0]+", Tag: "+arguments[1]});
			}
		}
		return func.apply(this,arguments);
	};
	allElementsType[i].prototype.getAttribute = function(){
		var func;
		var j;
		for (j=0; j < allElementsType.length; j++)
		{
			if ((this.constructor==allElementsType[j])||(this.__proto__==allElementsType[j].prototype)) func = oldGetAttr[j];
		}
		if ((arguments[0]!=null)&&(arguments[0].toLowerCase!=null)&&(arguments[0].toLowerCase()=="specialid"))
		{
			var thispath = getXPath(this);
			var callerInfo = getCallerInfo("getAttribute");
			if ((thispath!="")&&(callerInfo!=null))
			{
				seqID++;
				if (recordedDOMActions["getAttribute specialId called on "+thispath+callerInfo]!=true) 
				{ 
					recordedDOMActions["getAttribute specialId called on "+thispath+callerInfo]=true; 
					record[DOMRecord].push({what:thispath,when:seqID,who:callerInfo,v:(enableV?getV(this):""),extraInfo:"getAttribute specialId called"});
				}
			}
		}
		return func.apply(this,arguments);
	};
	allElementsType[i].prototype.setAttribute = function(){
		var func;
		var j;
		for (j=0; j < allElementsType.length; j++)
		{
			if ((this.constructor==allElementsType[j])||(this.__proto__==allElementsType[j].prototype)) func = oldSetAttr[j];
		}
		if ((arguments[0]!=null)&&(arguments[0].toLowerCase!=null)&&(arguments[0].toLowerCase()=="specialid"))
		{
			var thispath = getXPath(this);
			var callerInfo = getCallerInfo("setAttribute");
			if ((thispath!="")&&(callerInfo!=null))
			{
				seqID++;
				if (recordedDOMActions["setAttribute specialId called on "+thispath+" attr: "+arguments[1]+callerInfo]!=true) 
				{ 
					recordedDOMActions["setAttribute specialId called on "+thispath+" attr: "+arguments[1]+callerInfo]=true; 
					record[DOMRecord].push({what:thispath,when:seqID,who:callerInfo,v:(enableV?getV(this):""),extraInfo:"setAttribute specialId called, attr: "+arguments[1]});
				}
			}
		}
		return func.apply(this,arguments);
	};
	allElementsType[i].prototype.hasAttribute = function(){
		var func;
		var j;
		for (j=0; j < allElementsType.length; j++)
		{
			if ((this.constructor==allElementsType[j])||(this.__proto__==allElementsType[j].prototype)) func = oldHasAttr[j];
		}
		if ((arguments[0]!=null)&&(arguments[0].toLowerCase!=null)&&(arguments[0].toLowerCase()=="specialid"))
		{
			var thispath = getXPath(this);
			var callerInfo = getCallerInfo("hasAttribute");
			if ((thispath!="")&&(callerInfo!=null))
			{
				seqID++;
				if (recordedDOMActions["hasAttribute specialId called on "+thispath+callerInfo]!=true) 
				{ 
					recordedDOMActions["hasAttribute specialId called on "+thispath+callerInfo]=true; 
					record[DOMRecord].push({what:thispath,when:seqID,who:callerInfo,v:(enableV?getV(this):""),extraInfo:"hasAttribute specialId called"});
				}
			}
		}
		return func.apply(this,arguments);
	};
	allElementsType[i].prototype.insertBefore = function(){
	//var insertedElement = parentElement.insertBefore(newElement, referenceElement);
		var func;
		var get;
		var j;
		for (j=0; j < allElementsType.length; j++)
		{
			if ((this.constructor==allElementsType[j])||(this.__proto__==allElementsType[j].prototype)) 
			{ 
				func = oldInsertBefore[j]; 
				get = oldGetAttr[j];
			}
		}
		if ((arguments[0]!=null)&&(arguments[0].getAttribute!=null)&&(get.apply(arguments[0],["specialId"])!=null))
		{
			arguments[0].removeAttribute("specialId");
		}
		return func.apply(this,arguments);
	};
	allElementsType[i].prototype.appendChild = function(){
		var func;
		var get;
		var j;
		for (j=0; j < allElementsType.length; j++)
		{
			if ((this.constructor==allElementsType[j])||(this.__proto__==allElementsType[j].prototype)) 
			{ 
				func = oldAppendChild[j]; 
				get = oldGetAttr[j];
			}
		}
		if ((arguments[0]!=null)&&(arguments[0].getAttribute!=null)&&(get.apply(arguments[0],["specialId"])!=null))
		{
			arguments[0].removeAttribute("specialId");
		}
		return func.apply(this,arguments);
	};
	allElementsType[i].prototype.replaceChild = function(){
	//replacedNode = parentNode.replaceChild(newChild, oldChild);
		var func;
		var j;
		for (j=0; j < allElementsType.length; j++)
		{
			if ((this.constructor==allElementsType[j])||(this.__proto__==allElementsType[j].prototype)) 
			{ 
				func = oldReplaceChild[j]; 
				get = oldGetAttr[j];
			}
		}
		if ((arguments[0]!=null)&&(arguments[0].getAttribute!=null)&&(get.apply(arguments[0],["specialId"])!=null))
		{
			arguments[0].removeAttribute("specialId");
		}
		return func.apply(this,arguments);
	};
	if (oldInnerHTMLGetter)
	{
		allElementsType[i].prototype.__defineGetter__('innerHTML',function(str){
		var thispath = getXPath(this);
		var callerInfo = getCallerInfo("innerHTML");
		if ((thispath!="")&&(callerInfo!=null))
		{
			seqID++;
			if (recordedDOMActions['Read innerHTML of this element: '+thispath+'!'+callerInfo]!=true) 
			{ 
				recordedDOMActions['Read innerHTML of this element: '+thispath+'!'+callerInfo]=true; 
				record[DOMRecord].push({what:thispath,when:seqID,who:callerInfo,v:(enableV?getV(this):""),extraInfo:"innerHTML read"});
			}
		}
		return oldInnerHTMLGetter.call(this,str);
		});
	}
	if (oldTextContentGetter)
	{
		allElementsType[i].prototype.__defineGetter__('textContent',function(str){
		var thispath = getXPath(this);
		var callerInfo = getCallerInfo("textContent");
		if ((thispath!="")&&(callerInfo!=null))
		{
			seqID++;
			if (recordedDOMActions['Read textContent of this element: '+thispath+'!'+callerInfo]!=true) 
			{ 
				recordedDOMActions['Read textContent of this element: '+thispath+'!'+callerInfo]=true; 
				record[DOMRecord].push({what:thispath,when:seqID,who:callerInfo,v:(enableV?getV(this):""),extraInfo:"textContent read"});
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
	urlfile = url.replace(/[^a-zA-Z0-9]/g,"");	//\W also does the trick.
	urlfile = urlfile.substr(0,240);						//restrict the file length
	domain = domain.replace(/[^a-zA-Z0-9]/g,"");
	domain = domain.substr(0,240);
	var i;
	var rawdata = window._record.getRecord();
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
			//rawstring = rawstring + "When = "+rawdata[0][i].when+" What = "+rawdata[0][i].what+" Who = "+rawdata[0][i].who+"\n";
			rawstring = rawstring + rawdata[0][i].what;
			if ((rawdata[0][i].v)&&(rawdata[0][i].v!="")) rawstring = rawstring +" <=:| "+rawdata[0][i].v;
			rawstring = rawstring + " |:=> "+rawdata[0][i].who;
			if ((rawdata[0][i].extraInfo)&&(rawdata[0][i].extraInfo!="")) rawstring = rawstring +" <=|:| "+rawdata[0][i].extraInfo;
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

window.addEventListener('beforeunload',writePolicy,false);
//window.setTimeout("_record.writePolicy2();",5000);
//document.head.removeChild(oldGetTagName.call(document,'script')[0]);			//remove myself
return (function(){this.getRecord = function(){return record;}; this.writePolicy2 = writePolicy; this.Push = function(a){if (a!="") trustedDomains.push(a)}; this.setId = function(id){if (id!="") filecnt = id;}; this.Get = function() {return trustedDomains}; return this;});
}

__record = new ___record();
_record = __record();
