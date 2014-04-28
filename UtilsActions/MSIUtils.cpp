#include "stdafx.h"
#include "MSIUtils.h"
#include <comdef.h>
#include <Wbemidl.h>
#include <Ntsecapi.h>
#include <typeinfo>
#include <iostream>
#include <fstream>
#include <sstream>
#include <exception>

using namespace std;

#ifdef _DEBUG
void WriteLogFile(PWSTR path, PCWSTR msg)
{
	wofstream myfile;
	myfile.open (path, ios_base::app);
	myfile << msg << L"\n";
	myfile.close();
}

void WriteLogFile(PWSTR path, PCSTR msg)
{
	ofstream myfile;
	myfile.open (path, ios_base::app);
	myfile << msg << "\n";
	myfile.close();
}
#endif

MSIHANDLE GetComboBoxView(MSIHANDLE hDatabase, PCWSTR propertyName)
{
	PCWSTR formatStr = L"SELECT * FROM `ComboBox` WHERE `Property` = '%s'";
	WCHAR query[1024];
	swprintf_s(query, sizeof(query) / sizeof(WCHAR), formatStr, propertyName);

	MSIHANDLE hView = NULL;
	CheckRetVal(::MsiDatabaseOpenView(hDatabase, query, &hView));
	CheckRetVal(::MsiViewExecute(hView, 0));

	return hView;
}

void AddComboBoxEntry(MSIHANDLE hView, PCWSTR propertyName, int index, PCWSTR value, PCWSTR text)
{
	PMSIHANDLE hRec = ::MsiCreateRecord(4);
	if(!hRec)
		throw Win32Exception();

	CheckRetVal(::MsiRecordSetString(hRec, 1, propertyName));
	CheckRetVal(::MsiRecordSetInteger(hRec, 2, index));
	CheckRetVal(::MsiRecordSetString(hRec, 3, value));
	CheckRetVal(::MsiRecordSetString(hRec, 4, text));
	CheckRetVal(::MsiViewModify(hView, MSIMODIFY_INSERT_TEMPORARY, hRec));
}

void DeleteViewRecords(MSIHANDLE hView)
{
	MSIHANDLE hRec = NULL;
	UINT retValue = 0;
	while((retValue = ::MsiViewFetch(hView, &hRec)) == ERROR_SUCCESS)
	{
		CheckRetVal(::MsiViewModify(hView, MSIMODIFY_DELETE, hRec));
		::MsiCloseHandle(hRec);
	}

	if(retValue != ERROR_NO_MORE_ITEMS)
		throw Win32Exception();
}

void CloseView(MSIHANDLE hView)
{
	::MsiViewClose(hView);
	::MsiCloseHandle(hView);
}

void GetGUID(PWSTR guid)
{
	UUID uuid;
	::ZeroMemory(&uuid, sizeof(UUID));
	CheckRetVal(::UuidCreate(&uuid));
	RPC_WSTR wszUuid = NULL;
	CheckRetVal(::UuidToString(&uuid, &wszUuid));

	wsprintf(guid, L"{%s}", (PCWSTR)wszUuid);

	// Set uppercase
	for(int i = 0; guid[i] != 0; i++)
		if(guid[i] >= 97 && guid[i] <= 122)
			guid[i] -= 32;

	::RpcStringFree(&wszUuid);
	wszUuid = NULL;
}

void LogMessage(MSIHANDLE hInstall, PCWSTR message)
{
	PMSIHANDLE hRec = ::MsiCreateRecord(1);
	if(!hRec)
		throw Win32Exception();
	CheckRetVal(::MsiRecordSetString(hRec, 0, message));
	::MsiProcessMessage(hInstall, INSTALLMESSAGE(INSTALLMESSAGE_INFO), hRec);
}

void LogWarning(MSIHANDLE hInstall, PCWSTR message)
{
	PMSIHANDLE hRec = ::MsiCreateRecord(1);
	if(!hRec)
		throw Win32Exception();

	CheckRetVal(::MsiRecordSetString(hRec, 0, message));
	::MsiProcessMessage(hInstall, INSTALLMESSAGE(INSTALLMESSAGE_ERROR|MB_OK|MB_ICONWARNING), hRec);
}

void LogException(MSIHANDLE hInstall, UINT code, PCWSTR message)
{
	PMSIHANDLE hRec = ::MsiCreateRecord(1);
	if(!hRec)
		throw Win32Exception();

	CheckRetVal(::MsiRecordSetString(hRec, 0, message));
	::MsiProcessMessage(hInstall, INSTALLMESSAGE(INSTALLMESSAGE_ERROR|MB_OK|MB_ICONERROR), hRec);

	WCHAR msg[1024];
	wsprintf(msg, L"CustomAction exception details: 0x%x %s", code, message);
	CheckRetVal(::MsiRecordSetString(hRec, 0, msg));
	::MsiProcessMessage(hInstall, INSTALLMESSAGE(INSTALLMESSAGE_INFO), hRec);
}

void LogException(MSIHANDLE hInstall, const MessageException& ex)
{
	LogException(hInstall, ex.GetCode(), ex.GetMessage().c_str());
}

void LogException(MSIHANDLE hInstall, const exception& ex)
{
    string what(ex.what());
    wstring msg(what.begin(), what.end());
    LogException(hInstall, 0, msg.c_str());
}

void Split(PCWSTR str, WCHAR delim, vector<wstring> &elems) {
	wstringstream ss(str);
	wstring item;
	while(std::getline(ss, item, delim)) {
		elems.push_back(item);
	}

	// Add an empty item if str ends with the delimiter
	int l = lstrlen(str);
	if(l > 0 && str[l - 1] == delim)
		elems.push_back(L"");
}

wstring GetPropertyValue(MSIHANDLE hInstall, PCWSTR propertyName)
{
	WCHAR data[2048];
	DWORD bufSize = sizeof(data) / sizeof(WCHAR);
	CheckRetVal(::MsiGetProperty(hInstall, propertyName, data, &bufSize));
    return data;
}

void SplitCustomData(MSIHANDLE hInstall, vector<wstring> &data, WCHAR delim)
{
	Split(GetPropertyValue(hInstall, L"CustomActionData").c_str(), delim, data);
}

void CheckRetVal(HRESULT hres)
{
	if(FAILED(hres))
		throw Win32Exception(hres);
}

wstring Trim(const wstring& str, const wstring& whitespace)
{
	const auto strBegin = str.find_first_not_of(whitespace);
	if (strBegin == std::string::npos)
		return L""; // no content

	const auto strEnd = str.find_last_not_of(whitespace);
	const auto strRange = strEnd - strBegin + 1;

	return str.substr(strBegin, strRange);
}

bool IsElevated()
{
	DWORD dwSize = 0;
	HANDLE hToken = NULL;
	bool isElevated = false;
	TOKEN_ELEVATION tokenInformation;

	if(!OpenProcessToken(GetCurrentProcess(), TOKEN_QUERY, &hToken))
		return false;

	if(GetTokenInformation(hToken, TokenElevation, &tokenInformation, sizeof(TOKEN_ELEVATION), &dwSize))
		isElevated = (bool)tokenInformation.TokenIsElevated;

	CloseHandle(hToken);

	return isElevated;
}

void CheckLsaRetValue(NTSTATUS retValue)
{
    if(retValue != STATUS_SUCCESS)
        throw  Win32Exception(::LsaNtStatusToWinError(retValue));
}

void WStringToLsaUnicodeString(const wstring& str, LSA_UNICODE_STRING& lsaUnicodeStr)
{
    // str lifetime must encompass lsaUnicodeStr's!
    lsaUnicodeStr.Buffer = (PWSTR)str.c_str();
    lsaUnicodeStr.Length = str.length() * sizeof(WCHAR);
    lsaUnicodeStr.MaximumLength = (str.length() + 1) * sizeof(WCHAR);
}

