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

function getWmiCimV2Svc() {
    return GetObject("winmgmts:\\\\.\\root\\cimv2");
}

function getNetworkAdapters() {
    var property = "NETWORKADAPTERNAME";
    var view = getComboBoxView(property);

    deleteViewRecords(view);

    var wmiSvc = getWmiCimV2Svc();
    var networkAdapters = wmiSvc.ExecQuery("SELECT * FROM Win32_NetworkAdapter WHERE AdapterTypeId = 0 AND PhysicalAdapter = True")

    var index = 1;
    for (var e = new Enumerator(networkAdapters) ; !e.atEnd() ; e.moveNext()) {
        var networkAdapter = e.item();
        addComboBoxEntry(view, property, index++, networkAdapter.Name, networkAdapter.Name);
    }

    view.Close();
}

function initConfigDlgAction() {
    try {
        logMessage("Initializing ConfigDlg");

        getNetworkAdapters();

        return MsiActionStatus.Ok;
    }
    catch (ex) {
        Session.Property("CA_EXCEPTION") = ex.message;
        logException(ex);
        return MsiActionStatus.Abort;
    }
}