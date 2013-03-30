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
        var confFolder = Session.Property("CLOUDBASEINITCONFFOLDER");
        // Sysprep.exe doesn't work with paths containing spaces
        var unattendXmlPath = getShortPath(confFolder + "\\unattend.xml")
        cmd = "\"%SystemRoot%\\Sysnative\\Sysprep\\sysprep.exe\" /generalize /oobe /unattend:\"" + unattendXmlPath + "\"";

        runCommand(cmd, null, null, 5, false);
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
