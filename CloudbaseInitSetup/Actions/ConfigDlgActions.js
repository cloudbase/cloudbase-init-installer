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

function getSerialPortNames() {
    var serialPortNames = [];

    var wmiSvc = getWmiCimV2Svc();

    var serialPorts = wmiSvc.ExecQuery("SELECT * FROM Win32_SerialPort");
    for (var e = new Enumerator(serialPorts) ; !e.atEnd() ; e.moveNext()) {
        var serialPort = e.item();
        serialPortNames.push(serialPort.DeviceID);
    }

    return serialPortNames;
}

function setupLoggingSerialPortsComboBox() {
    var property = "LOGGINGSERIALPORTNAME";
    var view = getComboBoxView(property);

    deleteViewRecords(view);

    serialPortNames = getSerialPortNames();
    var index = 1;

    for (var i in serialPortNames) {
        serialPortName = serialPortNames[i];
        addComboBoxEntry(view, property, index++, serialPortName, serialPortName);
    }

    view.Close();
}

function initConfigDlgAction() {
    try {
        logMessage("Initializing ConfigDlg");

        setupLoggingSerialPortsComboBox();

        return MsiActionStatus.Ok;
    }
    catch (ex) {
        Session.Property("CA_EXCEPTION") = ex.message;
        logException(ex);
        return MsiActionStatus.Abort;
    }
}
