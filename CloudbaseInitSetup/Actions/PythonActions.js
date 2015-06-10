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

function deleteLocalCRTDlls(path) {
    var fileNames = ["Microsoft.VC90.CRT.manifest", "msvcm90.dll", "msvcp90.dll", "msvcr90.dll"];

    var fso = new ActiveXObject("Scripting.FileSystemObject");
    for (var i in fileNames) {
        var filePath = path + fileNames[i];
        if (fso.FileExists(filePath))
            try {
                fso.DeleteFile(filePath);
            }
            catch (ex) {
            // Ignore it
            }
    }
}

function updatePythonShellInScriptsAction() {
    try {
        logMessage("Replacing Python shell path in *-script.py files");

        var data = Session.Property("CustomActionData").split('|');
        var pythonScriptsFolder = data[0];
        var pythonExePath = data[1];

        replaceInFolder(pythonScriptsFolder, /.+-script.py$/i, /^#!.+python.exe/igm, "#!\"" + pythonExePath + "\"");
        updatePythonScriptExes(pythonExePath, "cloudbase-init = cloudbaseinit.shell:main");

        return MsiActionStatus.Ok;
    }
    catch (ex) {
        logException(ex);
        return MsiActionStatus.Abort;
    }
}

function deleteLocalCRTDllsAction() {
    try {
        logMessage("Deleting local VC++ CRT DLLs");

        var path = Session.Property("CustomActionData");
        deleteLocalCRTDlls(path);

        return MsiActionStatus.Ok;
    }
    catch (ex) {
        logException(ex);
        return MsiActionStatus.Abort;
    }
}