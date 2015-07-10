// Copyright (c) 2012 Cloudbase Solutions Srl. All rights reserved.

// Start Common.js content
/*
    Since the actions in this file are executed after the installation has been completed,
    the Common.js file is not available anymore and thus the content must be added here.
*/

// http://msdn.microsoft.com/en-us/library/sfw6660x(VS.85).aspx
var Buttons =
{
    OkOnly: 0,
    OkCancel: 1,
    AbortRetryIgnore: 2,
    YesNoCancel: 3
};

var Icons =
{
    Critical: 16,
    Question: 32,
    Exclamation: 48,
    Information: 64
}

var MsgKind =
{
    Error: 0x01000000,
    Warning: 0x02000000,
    User: 0x03000000,
    Log: 0x04000000
};

// http://msdn.microsoft.com/en-us/library/aa371254(VS.85).aspx
var MsiActionStatus =
{
    None: 0,
    Ok: 1, // success
    Cancel: 2,
    Abort: 3,
    Retry: 4, // aka suspend?
    Ignore: 5  // skip remaining actions; this is not an error.
};

// spool an informational message into the MSI log, if it is enabled.
function logMessage(msg) {
    var record = Session.Installer.CreateRecord(0);
    record.StringData(0) = "CustomActions: " + msg;
    Session.Message(MsgKind.Log, record);
}

function logMessageEx(msg, type) {
    var record = Session.Installer.CreateRecord(0);
    record.StringData(0) = msg;
    Session.Message(type, record);
}

// Pop a message box.  also spool a message into the MSI log, if it is enabled.
function logException(exc) {
    var record = Session.Installer.CreateRecord(0);
    record.StringData(0) = exc.message == "" ? "An exception occurred: 0x" + decimalToHexString(exc.number) : exc.message;
    Session.Message(MsgKind.Error + Icons.Critical + Buttons.OkOnly, record);

    // Log the full exception as well
    record.StringData(0) = "CustomAction exception details: 0x" + decimalToHexString(exc.number) + " : " + exc.message;
    Session.Message(MsgKind.Log, record);
}

function decimalToHexString(number) {
    if (number < 0)
        number = 0xFFFFFFFF + number + 1;
    return number.toString(16).toUpperCase();
}

function throwException(num, msg) {
    throw {
        number: num,
        message: msg
    };
}

function trim(str) {
    return str ? str.replace(/^\s\s*/, '').replace(/\s\s*$/, '') : "";
}

function contains(a, obj) {
    for (var i = 0; i < a.length; i++) {
        if (a[i] === obj) {
            return true;
        }
    }
    return false;
}

function getWmiCimV2Svc() {
    return GetObject("winmgmts:\\\\.\\root\\cimv2");
}

var OSArchitectures = {
    X86: "32",
    X64: "64"
}

function getWindowsArchitecture() {
    var wmiSvc = getWmiCimV2Svc();
    var q = wmiSvc.InstancesOf("Win32_Processor");
    var os = new Enumerator(q).item();
    // NOTE: does not work on Windows XP / 2003
    return os.AddressWidth
}

function runCommand(cmd, expectedReturnValue, envVars, windowStyle, waitOnReturn) {
    var shell = new ActiveXObject("WScript.Shell");
    logMessage("Running command: " + cmd);

    if (envVars) {
        var env = shell.Environment("Process");
        for (var k in envVars)
            env(k) = envVars[k];
    }

    if (typeof windowStyle == 'undefined')
        windowStyle = 0;

    if (typeof waitOnReturn == 'undefined')
        waitOnReturn = true;

    var retVal = shell.run(cmd, windowStyle, waitOnReturn);

    if (waitOnReturn && expectedReturnValue != undefined && expectedReturnValue != null && retVal != expectedReturnValue)
        throwException(-1, "Command failed. Return value: " + retVal.toString());

    logMessage("Command completed. Return value: " + retVal);

    return retVal;
}

function replaceInFile(fileName, pattern, replacement) {
    var fso = new ActiveXObject("Scripting.FileSystemObject");
    var infs = fso.OpenTextFile(fileName, 1);
    var text = infs.ReadAll();
    infs.Close();

    text = text.replace(pattern, replacement);

    var outfs = fso.OpenTextFile(fileName, 2);
    outfs.Write(text);
    outfs.Close();
}

function getShortPath(path) {
    var fso = new ActiveXObject("Scripting.FileSystemObject");
    return fso.GetFile(path).ShortPath;
}

// End Common.js content


function runCommandElevated(cmd, wait) {
    elevateCmd = "\"" + Session.Property("BINFOLDER") + "\\Elevate.exe\"";
    if (wait)
        elevateCmd += " -wait";
    elevateCmd += " " + cmd;

    runCommand(elevateCmd, null, null, 0, false);
}

function runSysprepAction() {
    try {
        // Make sure that the service doesn't start before the setup ends
        cmd = "\"" + Session.Property("BINFOLDER") + "\\SetSetupComplete.cmd\"";
        runCommandElevated(cmd, true);

        cmd = "\"%SystemRoot%\\System32\\Sysprep\\sysprep.exe\" /generalize /oobe";

        var confFolder = Session.Property("CLOUDBASEINITCONFFOLDER");
        // Sysprep.exe doesn't work with paths containing spaces
        var unattendXmlPath = confFolder + "\\Unattend.xml";
        cmd += " \\\"/unattend:" + unattendXmlPath + "\\\"";

        var shutdown = parseInt(Session.Property("SYSPREPSHUTDOWN"));
        if (!shutdown)
            cmd += " /quit";

        runCommandElevated(cmd, false);

        return MsiActionStatus.Ok;
    }
    catch (ex) {
        exceptionMsg = "Sysprep failed";
        logMessageEx(exceptionMsg, MsgKind.Error + Icons.Critical + Buttons.OkOnly);
        // log also the original exception
        logMessage(ex.message);
 
        return MsiActionStatus.Abort;
    }
}

function updateUnattendXmlAction() {
    try {
        logMessage("Updating Unattend.xml file");

        var data = Session.Property("CustomActionData").split('|');

        var i = 0;
        var installDir = data[i++];
        var confFolder = data[i++];
        var versionNt64 = data[i++];

        var arch = "x86";
        if (versionNt64)
            arch = "amd64";

        var unattendXmlPath = confFolder + "Unattend.xml";

        replaceInFile(unattendXmlPath, /%INSTALLDIR%/g, installDir);
        replaceInFile(unattendXmlPath, /%CLOUDBASEINITCONFFOLDER%/g, confFolder);
        replaceInFile(unattendXmlPath, /%ARCH%/g, arch);

        return MsiActionStatus.Ok;
    }
    catch (ex) {
        logException(ex);
        return MsiActionStatus.Abort;
    }
}
