// Copyright (c) 2012 Cloudbase Solutions Srl. All rights reserved.

// Begin common utils (as there's no practival way to include a separate script)

// Awful workaround to include common js features
var commonIncludeFileName = "82311161-875A-4587-A86C-9784581D8F56.js";
function loadCommonIncludeFile(fileName) {
    var shell = new ActiveXObject("WScript.Shell");
    var windir = shell.ExpandEnvironmentStrings("%WINDIR%");
    var path = windir + "\\Temp\\" + fileName;
    var fso = new ActiveXObject("Scripting.FileSystemObject");
    return fso.OpenTextFile(path, 1).ReadAll();
}
eval(loadCommonIncludeFile(commonIncludeFileName));
// End workaround

function runSysprepAction() {
    try {
        cmd = "\"%SystemRoot%\\System32\\Sysprep\\sysprep.exe\" /generalize /oobe";

        var confFolder = Session.Property("CLOUDBASEINITCONFFOLDER");
        // Sysprep.exe doesn't work with paths containing spaces
        var unattendXmlPath = getShortPath(confFolder + "\\Unattend.xml")
        cmd += " /unattend:\"" + unattendXmlPath + "\"";

        var shutdown = parseInt(Session.Property("SYSPREPSHUTDOWN"));
        if (!shutdown)
            cmd += " /quit";

        elevateCmd = Session.Property("BINFOLDER") + "\\Elevate_";

        osArch = getWindowsArchitecture();
        if (osArch == OSArchitectures.X64)
            elevateCmd += "x64";
        else
            elevateCmd += "x86";

        cmd = "\"" + elevateCmd + "\" " + cmd;

        runCommand(cmd, null, null, 0, false);
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
