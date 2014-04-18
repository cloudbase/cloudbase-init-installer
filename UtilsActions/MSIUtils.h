#pragma once

#include <vector>
#include <Ntstatus.h>
#include <LsaLookup.h>

class MessageException : public std::exception
{
public:
	virtual UINT GetCode() const = 0;
	virtual std::wstring GetMessage() const = 0;
};

class ParametersException : public MessageException
{
private:
	std::wstring m_message;

public:
	ParametersException(const std::wstring& message) : m_message(message)
	{
	}

	virtual UINT GetCode() const
	{
		return 0;
	}

	virtual std::wstring GetMessage() const
	{
		return m_message;
	}
};

class Win32Exception : public MessageException
{
private:
	HRESULT m_hres;

public:
	Win32Exception(HRESULT hres) : m_hres(hres)
	{}

	Win32Exception() : m_hres(::GetLastError())
	{}

	virtual UINT GetCode() const
	{
		return m_hres;
	}

	virtual std::wstring GetMessage() const
	{
		std::wstring retVal;
		PWSTR errorText = NULL;

		::FormatMessage(FORMAT_MESSAGE_FROM_SYSTEM
			| FORMAT_MESSAGE_ALLOCATE_BUFFER
			| FORMAT_MESSAGE_IGNORE_INSERTS,
			NULL,
			m_hres,
			MAKELANGID(LANG_NEUTRAL, SUBLANG_DEFAULT),
			(PWSTR)&errorText,
			0,
			NULL);

		retVal = errorText;
		::LocalFree(errorText);

		return errorText;
	}
};

MSIHANDLE GetComboBoxView(MSIHANDLE hDatabase, PCWSTR propertyName);
void AddComboBoxEntry(MSIHANDLE hView, PCWSTR propertyName, int index, PCWSTR value, PCWSTR text);
void DeleteViewRecords(MSIHANDLE hView);
void CloseView(MSIHANDLE hView);
void LogMessage(MSIHANDLE hInstall, PCWSTR message);
void LogWarning(MSIHANDLE hInstall, PCWSTR message);
void LogException(MSIHANDLE hInstall, UINT code, PCWSTR message);
void LogException(MSIHANDLE hInstall, const MessageException& ex);
void LogException(MSIHANDLE hInstall, const std::exception& ex);
void GetGUID(PWSTR guid);
void Split(PCWSTR str, WCHAR delim, std::vector<std::wstring> &elems);
void SplitCustomData(MSIHANDLE hInstall, std::vector<std::wstring> &data, WCHAR delim = L'|');
void WriteLogFile(PWSTR path, PCWSTR msg);
void WriteLogFile(PWSTR path, PCSTR msg);
void CheckRetVal(HRESULT hres);
std::wstring Trim(const std::wstring& str, const std::wstring& whitespace = L" \t");
bool IsElevated();
void CheckLsaRetValue(NTSTATUS retValue);
void WStringToLsaUnicodeString(const std::wstring& str, LSA_UNICODE_STRING& lsaUnicodeStr);
