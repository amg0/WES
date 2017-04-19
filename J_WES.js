// This program is free software: you can redistribute it and/or modify
// it under the condition that it is for private or home useage and 
// this whole comment is reproduced in the source code file.
// Commercial utilisation is not authorized without the appropriate
// written agreement from amg0 / alexis . mermet @ gmail . com
// This program is distributed in the hope that it will be useful,
// but WITHOUT ANY WARRANTY; without even the implied warranty of
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. 

//-------------------------------------------------------------
// wes  Plugin javascript Tabs
//-------------------------------------------------------------
var wes_Svs = 'urn:upnp-org:serviceId:wes1';
var ip_address = data_request_url;

if (typeof String.prototype.format == 'undefined') {
	String.prototype.format = function()
	{
		var args = new Array(arguments.length);

		for (var i = 0; i < args.length; ++i) {
			// `i` is always valid index in the arguments object
			// so we merely retrieve the value
			args[i] = arguments[i];
		}

		return this.replace(/{(\d+)}/g, function(match, number) { 
			return typeof args[number] != 'undefined' ? args[number] : match;
		});
	};
};

//-------------------------------------------------------------
// Device TAB : Donate
//-------------------------------------------------------------	
function wes_Donate(deviceID) {
	var htmlDonate='For those who really like this plugin and feel like it, you can donate what you want here on Paypal. It will not buy you more support not any garantee that this can be maintained or evolve in the future but if you want to show you are happy and would like my kids to transform some of the time I steal from them into some <i>concrete</i> returns, please feel very free ( and absolutely not forced to ) to donate whatever you want.  thank you ! ';
	htmlDonate+='<form action="https://www.paypal.com/cgi-bin/webscr" method="post" target="_top"><input type="hidden" name="cmd" value="_donations"><input type="hidden" name="business" value="alexis.mermet@free.fr"><input type="hidden" name="lc" value="FR"><input type="hidden" name="item_name" value="Alexis Mermet"><input type="hidden" name="item_number" value="wes"><input type="hidden" name="no_note" value="0"><input type="hidden" name="currency_code" value="EUR"><input type="hidden" name="bn" value="PP-DonationsBF:btn_donateCC_LG.gif:NonHostedGuest"><input type="image" src="https://www.paypalobjects.com/en_US/FR/i/btn/btn_donateCC_LG.gif" border="0" name="submit" alt="PayPal - The safer, easier way to pay online!"><img alt="" border="0" src="https://www.paypalobjects.com/fr_FR/i/scr/pixel.gif" width="1" height="1"></form>';
	var html = '<div>'+htmlDonate+'</div>';
	set_panel_html(html);
}

//-------------------------------------------------------------
// Device TAB : Settings
//-------------------------------------------------------------	

function wes_Settings(deviceID) {
	var debug  = get_device_state(deviceID,  wes_Svs, 'Debug',1);
	var credentials = get_device_state(deviceID,  wes_Svs, 'Credentials',1);
	var poll = get_device_state(deviceID,  wes_Svs, 'RefreshPeriod',1);
	var pin = ""

	// get_device_state(deviceID,  wes_Svs, 'PIN',1);
	var html =
    '                                                           \
      <div id="wes-settings">                                           \
        <form id="wes-settings-form">                        \
					<div class="form-group">																	\
						<label for="wes-username">User Name</label>		\
						<input type="text" class="form-control" id="wes-username" placeholder="User">	\
					</div>																										\
					<div class="form-group">																	\
						<label for="wes-pwd">Password</label>			\
						<input type="password" class="form-control" id="wes-pwd" placeholder="Password">	\
					</div>																								\
					<div class="form-group">																	\
						<label for="wes-RefreshPeriod">Polling in sec</label>			\
						<input type="number" min="1" max="600" class="form-control" id="wes-RefreshPeriod" placeholder="5">	\
					</div>																								\																							\
					<button id="wes-submit" type="submit" class="btn btn-default">Submit</button>	\
				</form>                                                 \
      </div>                                                    \
    '		
	set_panel_html(html);
	var arr = atob(credentials).split(":");
	jQuery( "#wes-username" ).val(arr[0]);
	jQuery( "#wes-pwd" ).val(arr[1]);
	jQuery( "#wes-RefreshPeriod" ).val(poll);
		
	jQuery( "#wes-settings-form" ).on("submit", function(event) {
		event.preventDefault();
		var usr = jQuery( "#wes-username" ).val();
		var pwd = jQuery( "#wes-pwd" ).val();
		var poll = jQuery( "#wes-RefreshPeriod" ).val();
		
		var encode = btoa( "{0}:{1}".format(usr,pwd) );
		saveVar( deviceID,  wes_Svs, "Credentials", encode, 0 )
		saveVar( deviceID,  wes_Svs, "RefreshPeriod", poll, 0 )
		return false;
	})
}


//-------------------------------------------------------------
// Variable saving ( log , then full save )
//-------------------------------------------------------------
function saveVar(deviceID,  service, varName, varVal, reload)
{
	set_device_state(deviceID, wes_Svs, varName, varVal, 0);	// lost in case of luup restart
}



//-------------------------------------------------------------
// Helper functions to build URLs to call VERA code from JS
//-------------------------------------------------------------
function buildVeraURL( deviceID, fnToUse, varName, varValue)
{
	var urlHead = '' + ip_address + 'id=lu_action&serviceId=urn:micasaverde-com:serviceId:HomeAutomationGateway1&action=RunLua&Code=';
	if (varValue != null)
		return urlHead + fnToUse + '("' + wes_Svs + '", "' + varName + '", "' + varValue + '", ' + deviceID + ')';

	return urlHead + fnToUse + '("' + wes_Svs + '", "' + varName + '", "", ' + deviceID + ')';
}

function buildVariableSetUrl( deviceID, varName, varValue)
{
	var urlHead = '' + ip_address + 'id=variableset&DeviceNum='+deviceID+'&serviceId='+wes_Svs+'&Variable='+varName+'&Value='+varValue;
	return urlHead;
}

function buildUPnPActionUrl(deviceID,service,action,params)
{
	var urlHead = ip_address +'id=action&output_format=json&DeviceNum='+deviceID+'&serviceId='+service+'&action='+action;//'&newTargetValue=1';
	if (params != undefined) {
		jQuery.each(params, function(index,value) {
			urlHead = urlHead+"&"+index+"="+value;
		});
	}
	return urlHead;
}

function buildHandlerUrl(deviceID,command,params)
{
	//http://192.168.1.5:3480/data_request?id=lr_IPhone_Handler
	var urlHead = ip_address +'id=lr_WES_Handler&command='+command+'&DeviceNum='+deviceID;
	jQuery.each(params, function(index,value) {
		urlHead = urlHead+"&"+index+"="+encodeURIComponent(value);
	});
	return encodeURI(urlHead);
}
