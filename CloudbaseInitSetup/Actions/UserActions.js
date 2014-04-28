// Copyright (c) 2014 Cloudbase Solutions Srl. All rights reserved.

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

function addUserToWinlogonSpecialAccountsAction() {
    try {
        var userName = Session.Property("CustomActionData");
        addUserToWinlogonSpecialAccounts(userName);
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
