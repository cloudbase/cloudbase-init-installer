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

function runCommandElevated(cmd, wait) {
    elevateCmd = Session.Property("BINFOLDER") + "\\Elevate_";

    osArch = getWindowsArchitecture();
    if (osArch == OSArchitectures.X64)
        elevateCmd += "x64";
    else
        elevateCmd += "x86";

    elevateCmd = "\"" + elevateCmd + "\"";
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
        var unattendXmlPath = getShortPath(confFolder + "\\Unattend.xml")
        cmd += " /unattend:\"" + unattendXmlPath + "\"";

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

        var arch = "x86";
        osArch = getWindowsArchitecture();
        if (osArch == OSArchitectures.X64)
            arch = "amd64";

        var unattendXmlPath = confFolder + "Unattend.xml";

        replaceInFile(unattendXmlPath, "/%INSTALLDIR%/g", installDir);
        replaceInFile(unattendXmlPath, "/%CLOUDBASEINITCONFFOLDER%/g", confFolder);
        replaceInFile(unattendXmlPath, "/%ARCH%/g", arch);

        return MsiActionStatus.Ok;
    }
    catch (ex) {
        logException(ex);
        return MsiActionStatus.Abort;
    }
}
