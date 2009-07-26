/*
 * The MIT License
 *
 * Copyright (c) 2009 Alonso Andres
 *
 * Permission is hereby granted, free of charge, to any person obtaining a copy
 * of this software and associated documentation files (the "Software"), to deal
 * in the Software without restriction, including without limitation the rights
 * to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
 * copies of the Software, and to permit persons to whom the Software is
 * furnished to do so, subject to the following conditions:
 *
 * The above copyright notice and this permission notice shall be included in
 * all copies or substantial portions of the Software.
 *
 * THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
 * IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
 * FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
 * AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
 * LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
 * OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
 * THE SOFTWARE.
 */

/*
 * Based on socketBridge
 * http://matthaynes.net/blog/2008/07/17/socketbridge-flash-javascript-socket-bridge/
 */
import AnsiToHtml;

class HMUDBridge {

    static var socket = new flash.net.Socket();
    static var JSObj = "hMUDClient";

    static function main()
    {
        if (flash.external.ExternalInterface.available) {
            /* Calls the javascript load method once the SWF has loaded */
            flash.external.ExternalInterface.call(JSObj+".loaded");

            /* \xA0 is the NBSP character. oddly enough, that's the only way
               I could make the line breaks work correctly in IE7. So here
               we are telling AnsiToHtml to use this char instead of common
               spaces when generating the HTML. */
            if (flash.external.ExternalInterface.call("iAmIE"))
                AnsiToHtml.spaceString = "\xA0";
            else
                AnsiToHtml.spaceString = " ";

            /*
             * Event listeners
             */

            /* CONNECT */
            socket.addEventListener(flash.events.Event.CONNECT, function(e) : Void {
                    trace("CONNECT");
                    flash.external.ExternalInterface.call(JSObj+".connected");
                }
            );

            /* CLOSE */
            socket.addEventListener(flash.events.Event.CLOSE, function(e) : Void {
                    trace("CLOSE");
                    flash.external.ExternalInterface.call(JSObj+".disconnected");
                }
            );


            /* IO_ERROR */
            socket.addEventListener(flash.events.IOErrorEvent.IO_ERROR, function(e) : Void {
                    trace("IO_ERROR: " +  e.text);
                    flash.external.ExternalInterface.call(JSObj+".ioError", e.text);
                }
            );

            /* SECURITY_ERROR */
            socket.addEventListener(flash.events.SecurityErrorEvent.SECURITY_ERROR, function(e) : Void {
                    trace("SECURITY_ERROR: " +  e.text);
                    flash.external.ExternalInterface.call(JSObj+".securityError", e.text);
                }
            );

            /* SOCKET_DATA */
            socket.addEventListener(flash.events.ProgressEvent.SOCKET_DATA, function(e) : Void {
                    //var msg = socket.readUTFBytes(socket.bytesAvailable);

                    if (socket.bytesAvailable < 1)
                        return;

                    trace("SOCKET_DATA: " + socket.bytesAvailable + " bytes.");
                    var bytes = new flash.utils.ByteArray();
                    socket.readBytes(bytes);
                    var msg = bytes.toString();

                    /*
                     * { START of ugly section
                     *
                     * FIXME: perform a TRUE telnet protocol parsing here, and reproduce beeps etc.
                     */
                    // Parse telnet options (I'm lazy, just get last telnet option)
                    // IAC WILL ECHO 
                    if (~/(^|[^\xFF])\xFF\xFB\x01[^\xFF]*$/.match(msg))
                        flash.external.ExternalInterface.call(JSObj+".echo_off");
                    // IAC WONT ECHO
                    else if (~/(^|[^\xFF])\xFF\xFC\x01[^\xFF]*$/.match(msg))
                        flash.external.ExternalInterface.call(JSObj+".echo_on");

                    // now get rid of those telnet chars.
                    msg = ~/\xFF[\xFC\xFB]\x01/g.replace(msg, "");
                    // escaped IAC, that is: IAC IAC = \xFF
                    msg = ~/\xFF\xFF/g.replace(msg, "\xFF");
                    /*
                     * } END of ugly section
                     */

                    // Ansi To Html!
                    msg = AnsiToHtml.parse(msg);
                    flash.external.ExternalInterface.call(JSObj+".receive", ~/\\/g.replace(msg, "\\\\"));
                }
            );

            /*
             * Set External Interface Callbacks
             */
            flash.external.ExternalInterface.addCallback("connected", connected);
            flash.external.ExternalInterface.addCallback("connect", connect);
            flash.external.ExternalInterface.addCallback("close", close);
            flash.external.ExternalInterface.addCallback("command", command);
            //flash.external.ExternalInterface.addCallback("saveLog", saveLog);
        } else {
            trace("Flash external interface not available");
        }   
    }
    
    static function connected() {
    	return socket.connected;
    }

    static function connect(host, port, policyPort)
    {
        flash.external.ExternalInterface.call(JSObj+".connecting");

        trace("Load policy from xmlsocket://" + host + ":" + policyPort);
        flash.system.Security.loadPolicyFile("xmlsocket://" + host + ":" + policyPort);

    	trace("Connecting to socket server at " + host + ":" + port);
        socket.connect(host, port);    	
    }
    
    static function close() {
    	if (socket.connected) {
            trace("Closing current connection");
            socket.close();
        } else {
            trace("Cannot disconnect to server because there is no connection!");
        }
    }

    static function command(msg) {
    	if (socket.connected) {
            var iac = ~/\xFF/g;
            var nl = ~/[\r\n]/g;
            msg = iac.replace(msg, "\xFF\xFF"); /* doubling IAC character (Telnet Protocol) */
            msg = nl.replace(msg, "");		/* removing newlines */
            trace("Writing '" + msg + "' to server");
            socket.writeMultiByte(msg + "\r\n", "iso-8859-1");
            socket.flush();
        } else {
            trace("Cannot write to server because there is no connection!");		
        }
    }    

    /*
     * FIXME: Damn! Flash 10 will only open a file dialog if the code runs under a
     *        user event, the problem is: we are using external interface, Flash
     *        does not recognize user events from there! Think in a solution...
     *        (positioning the flash player under the mouse cursor and making it
     *        accept a click?)

    static function saveLog(log) {
        try {
            var file = new flash.net.FileReference();
            //configureListeners(file);
            //file.save(log, "log-" + Date.now().toString());
            file.save(log, "log.html");
        } catch( unknown : Dynamic ) {
           trace("Unknown exception : "+Std.string(unknown));
           flash.external.ExternalInterface.call(JSObj+".receive", Std.string(unknown));
        }

    }
    */
}