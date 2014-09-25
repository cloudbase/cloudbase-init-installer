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

function getNetworkAdapters() {
    var property = "NETWORKADAPTERNAME";
    var view = getComboBoxView(property);

    deleteViewRecords(view);

    var osVersion = getWindowsVersion()

    var wmiSvc = getWmiCimV2Svc();

    var query = "SELECT * FROM Win32_NetworkAdapter WHERE AdapterTypeId = 0 AND MACAddress IS NOT NULL"
    if (osVersion[0] >= 6)
        query += " AND PhysicalAdapter = True"

    var networkAdapters = wmiSvc.ExecQuery(query)
    var index = 1;
    for (var e = new Enumerator(networkAdapters) ; !e.atEnd() ; e.moveNext()) {
        // On XP / 2003 check the DeviceID to avoid including Miniport and other not relevant adapters
        var networkAdapter = e.item();
        if (osVersion[0] >= 6 || networkAdapter.PNPDeviceID.indexOf("PCI") == 0)
            addComboBoxEntry(view, property, index++, networkAdapter.Name, networkAdapter.Name);
    }

    view.Close();
}

function initConfigDlgAction() {
    try {
        logMessage("Initializing ConfigDlg");

        getNetworkAdapters();
        setupLoggingSerialPortsComboBox();

        return MsiActionStatus.Ok;
    }
    catch (ex) {
        Session.Property("CA_EXCEPTION") = ex.message;
        logException(ex);
        return MsiActionStatus.Abort;
    }
}

function setUserGroupsAction() {
    try{
        var usergroupsProperty = Session.Property("USERGROUPS");

        if (!usergroupsProperty){
            var administratorsProperty = Session.Property("ACCOUNT_ADMINISTRATORS_NAME");
            Session.Property("USERGROUPS") = administratorsProperty;
        }

        return MsiActionStatus.Ok;
    }
    catch (ex) {
        logException(ex);
        return MsiActionStatus.Abort;
    }
}
