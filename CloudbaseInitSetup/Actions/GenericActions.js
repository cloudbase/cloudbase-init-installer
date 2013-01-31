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

function runCommandAction() {
    var exceptionMsg = null;

    try {
        var data = Session.Property("CustomActionData").split('|');
        var i = 0;
        var cmd = data[i++];
        var expectedRetValue = data.length > i ? data[i++] : 0;
        var exceptionMsg = data.length > i ? data[i++] : null;

        runCommand(cmd, expectedRetValue);
        return MsiActionStatus.Ok;
    }
    catch (ex) {
        if (exceptionMsg) {
            logMessageEx(exceptionMsg, MsgKind.Error + Icons.Critical + Buttons.OkOnly);
            // log also the original exception
            logMessage(ex.message);
        }
        else
            logException(ex);

        return MsiActionStatus.Abort;
    }
}

function replaceVarInFileAction() {
    try {
        var data = Session.Property("CustomActionData").split('|');
        var filePath = data[0];
        var patternStr = data[1];
        var patternOptions = data[2];
        var replacement = data[3];

        logMessage("Replacing \"" + patternStr + "\" with \"" + replacement + "\" in " + filePath);

        var regex = new RegExp(patternStr, patternOptions);
        replaceInFile(filePath, regex, replacement);

        return MsiActionStatus.Ok;
    }
    catch (ex) {
        logException(ex);
        return MsiActionStatus.Abort;
    }
}