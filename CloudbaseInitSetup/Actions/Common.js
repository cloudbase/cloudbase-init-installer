// Copyright (c) 2012 Cloudbase Solutions Srl. All rights reserved.

var MsiViewModify =
{
    Refresh: 0,
    Insert: 1,
    Update: 2,
    Assign: 3,
    Replace: 4,
    Merge: 5,
    Delete: 6,
    InsertTemporary: 7,   // cannot permanently modify the MSI during install
    Validate: 8,
    ValidateNew: 9,
    ValidateField: 10,
    ValidateDelete: 11
};

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

var FSO_FOR_READING = 1;
var FSO_FOR_WRITING = 2;
var FSO_FOR_APPENDING = 8;

var FSO_SPECIAL_FOLDER_WINDOWS = 0;
var FSO_SPECIAL_FOLDER_SYSTEM = 1;
var FSO_SPECIAL_FOLDER_TEMP = 2;

var SID_ADMINISTRATORS = "S-1-5-32-544";
var SID_USERS = "S-1-5-32-545";

String.prototype.endsWith = function (suffix) {
    return this.indexOf(suffix, this.length - suffix.length) !== -1;
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

function newGuid() {
    var tl = new ActiveXObject("Scriptlet.TypeLib");
    return tl.Guid;
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

function setPropertyIfNotSet(propertyName, value) {
    if (Session.Property(propertyName) == "")
        Session.Property(propertyName) = value;
}

function getSafeArray(jsArr) {
    var dict = new ActiveXObject("Scripting.Dictionary");
    for (var i = 0; i < jsArr.length; i++)
        dict.add(i, jsArr[i]);
    return dict.Items();
}

function invokeWMIMethod(svc, methodName, inParamsValues, wmiSvc, jobOutParamName) {
    logMessage("Invoking " + methodName);

    var inParams = null;
    if (inParamsValues) {
        for (var k in inParamsValues) {
            if (!inParams)
                inParams = svc.Methods_(methodName).InParameters.SpawnInstance_();
            var val = inParamsValues[k];
            if (val instanceof Array)
                inParams[k] = getSafeArray(val);
            else
                inParams[k] = val;
        }
    }

    var outParams = svc.ExecMethod_(methodName, inParams);
    if (outParams.ReturnValue == 4096) {
        var job = wmiSvc.Get(outParams[jobOutParamName]);
        waitForJob(wmiSvc, job);
    }
    else if (outParams.ReturnValue != 0)
        throwException(-1, methodName + " failed. Return value: " + outParams.ReturnValue.toString());

    return outParams;
}

function getWmiCimV2Svc() {
    return GetObject("winmgmts:\\\\.\\root\\cimv2");
}

function getWindowsArchitecture() {
    var wmiSvc = getWmiCimV2Svc();
    var q = wmiSvc.InstancesOf("Win32_OperatingSystem")
    var os = new Enumerator(q).item()
    // NOTE: does not work on Windows XP / 2003
    return os.OSArchitecture
}

function getWindowsVersion() {
    var wmiSvc = getWmiCimV2Svc();
    var q = wmiSvc.InstancesOf("Win32_OperatingSystem")
    var os = new Enumerator(q).item()
    return os.Version.split('.')
}

function createPath(path) {
    var fso = new ActiveXObject("Scripting.FileSystemObject");
    var currPath = "";
    var pathParts = path.split("\\");
    for (var i in pathParts) {
        currPath += pathParts[i] + "\\";
        if (!fso.FolderExists(currPath))
            fso.CreateFolder(currPath);
    }
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

    if (typeof expectedReturnValue == 'undefined')
        expectedReturnValue = 0;

    var retVal = shell.run(cmd, windowStyle, waitOnReturn);

    if (waitOnReturn && expectedReturnValue != undefined && expectedReturnValue != null && retVal != expectedReturnValue)
        throwException(-1, "Command failed. Return value: " + retVal.toString());

    logMessage("Command completed. Return value: " + retVal);

    return retVal;
}

function sleep(interval) {
    // WScript.Sleep is not supported in MSI's WSH. Here's a workaround for the moment.

    // interval is ignored
    var numPings = 2;
    cmd = "ping -n " + numPings + " 127.0.0.1";

    var shell = new ActiveXObject("WScript.Shell");
    shell.run(cmd, 0, true);
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

function replaceInFolder(folderPath, fileNamePattern, pattern, replacement) {
    var fso = new ActiveXObject("Scripting.FileSystemObject");
    var folder = fso.GetFolder(folderPath);

    for (var e = new Enumerator(folder.Files) ; !e.atEnd() ; e.moveNext()) {
        var file = e.item();
        if (fileNamePattern.test(file.Name))
            replaceInFile(file.Path, pattern, replacement);
    }
}

function addComboBoxEntry(view, propertyName, index, value, text) {
    logMessage("Adding combobox option: " + propertyName + ", " + index.toString() + ", " + value + ", " + text);

    var record = Session.Installer.CreateRecord(4);
    record.StringData(1) = propertyName;
    record.IntegerData(2) = index;
    record.StringData(3) = value;
    record.StringData(4) = text;
    view.Modify(MsiViewModify.InsertTemporary, record);
}

function getComboBoxView(property) {
    var view = Session.Database.OpenView("SELECT * FROM `ComboBox` where `ComboBox`.`Property` = '" + property + "'");
    view.Execute();
    return view;
}

function deleteViewRecords(view) {
    var record;
    while ((record = view.Fetch()) != null) {
        view.Modify(MsiViewModify.Delete, record);
    }
}

function getShortPath(path) {
    var fso = new ActiveXObject("Scripting.FileSystemObject");
    return fso.GetFile(path).ShortPath;
}

function checkBoxValueToBool(str) {
    return (str && str.length > 0 ? true : false).toString();
}

function writeConfigFile(path, configSections) {
    var fso = new ActiveXObject("Scripting.FileSystemObject");
    var fs = fso.OpenTextFile(path, 2, true);

    logMessage("Writing file " + path);

    for (section in configSections) {
        fs.WriteLine("[" + section + "]");
        config = configSections[section]
        for (var k in config)
            fs.WriteLine(k + "=" + config[k]);
    }
    fs.Close();
}

function appendFile(srcPath, destPath) {
    var fso = new ActiveXObject("Scripting.FileSystemObject");

    fs = fso.OpenTextFile(srcPath, FSO_FOR_READING);
    fd = fso.OpenTextFile(destPath, FSO_FOR_APPENDING);

    while (!fs.AtEndOfStream) {
        var l = fs.ReadLine();
        fd.WriteLine(l);
    }

    fs.Close();
    fd.Close();
}

function generateSelfSignedX509Cert(opensslBinPath, x509CertFilePath, commonName, keyFilePath) {
    var fso = new ActiveXObject("Scripting.FileSystemObject");
    var combineCertKey = false;

    var certPath = fso.GetParentFolderName(x509CertFilePath);

    if (typeof keyFilePath == 'undefined') {
        keyFilePath = fso.BuildPath(certPath, "key.pem");
        combineCertKey = true;
    }

    var opensslConf = fso.BuildPath(certPath, fso.GetTempName());

    f = fso.CreateTextFile(opensslConf, true);
    f.WriteLine("[ req ]\n" +
                "prompt = no\n" +
                "basicConstraints = CA:false\n" +
                "distinguished_name = self_signed_distinguished_name\n" +
                "[ self_signed_distinguished_name ]\n" +
                "commonName = " + commonName + "\n" +
                "stateOrProvinceName = Self Signed\n" +
                "countryName = --\n" +
                "emailAddress = selfsigned@selfsigned\n" +
                "organizationName = Self Signed\n");
    f.Close();

    var env = { "OPENSSL_CONF": opensslConf }
    var opensslPath = fso.BuildPath(opensslBinPath, "openssl.exe");

    var cmd = "\"" + opensslPath + "\" req -x509 -nodes -days 3650 -newkey rsa:2048 " +
              "-keyout \"" + keyFilePath + "\" " +
              "-out \"" + x509CertFilePath + "\"";

    runCommand(cmd, 0, env);

    fso.DeleteFile(opensslConf, true);

    if (combineCertKey) {
        appendFile(keyFilePath, x509CertFilePath);
        fso.DeleteFile(keyFilePath, true);
    }
}

function removeUsersACEFromPath(path) {
    var fso = new ActiveXObject("Scripting.FileSystemObject");
    f = fso.GetSpecialFolder(FSO_SPECIAL_FOLDER_SYSTEM);

    var icaclsPath = fso.BuildPath(f, "icacls.exe");
    runCommand(icaclsPath + " \"" + path + "\" /inheritance:d");
    runCommand(icaclsPath + " \"" + path + "\" /remove:g *" + SID_USERS);
}

function getNativeSystem32Dir() {
    var shell = new ActiveXObject("WScript.Shell");
    var sysdir = shell.ExpandEnvironmentStrings("%WINDIR%\\SYSNATIVE");

    var fso = new ActiveXObject("Scripting.FileSystemObject");
    if (!fso.FolderExists(sysdir))
        sysdir = shell.ExpandEnvironmentStrings("%WINDIR%\\System32");

    return sysdir;
}

function removeUserFromWinlogonSpecialAccounts(userName) {
    runCommand(getNativeSystem32Dir() + "\\reg.exe DELETE \"HKLM\\Software\\Microsoft\\Windows NT\\CurrentVersion\\Winlogon\\SpecialAccounts\\UserList\" /f /v " + userName);
}

function addUserToWinlogonSpecialAccounts(userName) {
    runCommand(getNativeSystem32Dir() + "\\reg.exe ADD \"HKLM\\Software\\Microsoft\\Windows NT\\CurrentVersion\\Winlogon\\SpecialAccounts\\UserList\" /f /t REG_DWORD /d 0 /v " + userName);
}

function updatePythonScriptExes(pythonExePath, specs) {
    // Update executables
    var cmd = '"' + pythonExePath + '" -c "import os; import sys;' +
    '"from pip._vendor.distlib import scripts;' +
    'specs = \'' + specs + '\';' +
    'scripts_path = os.path.join(os.path.dirname(sys.executable), \'Scripts\');' +
    'm = scripts.ScriptMaker(None, scripts_path);' +
    'm.executable = sys.executable;m.make(specs)"';
    runCommand(cmd);
}

var commonIncludeFileName = "82311161-875A-4587-A86C-9784581D8F56.js";
var commonIncludeBinaryNamePrefix = 'ActionsCommon';

function getCommonIncludeFilePath() {
    // Cannot use the user's %TEMP% folder as the file needs to be accessed also by non impersonated scripts
    var shell = new ActiveXObject("WScript.Shell");
    var windir = shell.ExpandEnvironmentStrings("%WINDIR%");
    return windir + "\\Temp\\" + commonIncludeFileName;
}

// Awful workaround to include common js features
function createCommonIncludeFileAction() {
    var view = Session.Database.OpenView("SELECT `Name`, `Data` FROM `Binary`");
    view.Execute();

    var record;
    while ((record = view.Fetch()) != null) {
        view.Modify(MsiViewModify.Delete, record);
        var name = record.StringData(1);

        if (name.indexOf(commonIncludeBinaryNamePrefix) == 0)
            break;
    }

    if (!record)
        throwException(-1, 'Cannot find binary data starting with: ' + commonIncludeBinaryNamePrefix);

    var size = record.DataSize(2);
    var data = record.ReadStream(2, size, 2);

    var commonIncludeFilePath = getCommonIncludeFilePath();

    var fso = new ActiveXObject("Scripting.FileSystemObject");
    var fs = fso.OpenTextFile(commonIncludeFilePath, 2, true);
    fs.Write(data);
    fs.Close();

    return MsiActionStatus.Ok;
}

function deleteCommonIncludeFileAction() {
    var fso = new ActiveXObject("Scripting.FileSystemObject");
    var commonIncludeFilePath = getCommonIncludeFilePath();

    if (fso.FileExists(commonIncludeFilePath)) {
        fso.DeleteFile(commonIncludeFilePath, true);
    }

    return MsiActionStatus.Ok;
}
