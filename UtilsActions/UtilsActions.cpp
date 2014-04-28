// UtilsActions.cpp : Defines the exported functions for the DLL application.
//

#include "stdafx.h"
#include "UtilsActions.h"
#include "MSIUtils.h"

#include <Ntsecapi.h>

#include <sstream>
#include <algorithm>

using namespace std;

#define PASSWORD_LENGTH 20
#define PASSWORD_MSI_PROPERTY_NAME_PROPERTY L"GENERATED_PASSWORD_PROPERTY_NAME"
#define PASSWORD_MSI_DEFAULT_PROPERTY_NAME L"GENERATED_PASSWORD"

wstring GenerateRandomPassword()
{
	HCRYPTPROV hProvider = 0;

    try
    {
	    if (!::CryptAcquireContext(&hProvider, 0, 0, PROV_RSA_FULL, CRYPT_VERIFYCONTEXT | CRYPT_SILENT))
            throw Win32Exception();

	    const DWORD dwLength = PASSWORD_LENGTH;
	    BYTE pbBuffer[dwLength] = {};

	    if (!::CryptGenRandom(hProvider, dwLength, pbBuffer))
            throw Win32Exception();

        wstringstream passwordss;
	    for (DWORD i = 0; i < dwLength; ++i)
		    passwordss << std::hex << static_cast<unsigned int>(pbBuffer[i]);
        // Add a non alphanumeric character
        passwordss << L"$";

	    ::CryptReleaseContext(hProvider, 0);

        return passwordss.str();
    }
    catch(exception&)
    {
        if(hProvider)
	        ::CryptReleaseContext(hProvider, 0);
        throw;
    }
}

void GetUserSid(const wstring& username, PSID &pSid)
{
	PWSTR referencedDomainName = NULL;
	pSid = NULL;

	try
	{
		DWORD cchReferencedDomainName = 0;
		DWORD cbSid = 0;
		SID_NAME_USE sidNameUse = SidTypeUser;

		::LookupAccountName(NULL, username.c_str(), NULL, &cbSid, NULL, &cchReferencedDomainName, &sidNameUse);
		DWORD err = ::GetLastError();
		if (err != ERROR_INSUFFICIENT_BUFFER)
			throw Win32Exception();

		pSid = (PSID)::GlobalAlloc(GMEM_FIXED, cbSid);
		if (!pSid)
			throw Win32Exception();

		referencedDomainName = (PWSTR)::GlobalAlloc(GMEM_FIXED, cchReferencedDomainName * sizeof(WCHAR));
		if (!referencedDomainName)
			throw Win32Exception();

		if (!::LookupAccountName(NULL, username.c_str(), pSid, &cbSid, referencedDomainName, &cchReferencedDomainName, &sidNameUse))
			throw Win32Exception();

		::GlobalFree(referencedDomainName);
	}
	catch (exception&)
	{
		if (referencedDomainName)
			::GlobalFree(referencedDomainName);
		if (pSid)
			::GlobalFree(pSid);
		throw;
	}
}

vector<wstring> GetUserRights(const wstring& username)
{
	LSA_HANDLE hPolicy = NULL;
	PLSA_UNICODE_STRING usRights = NULL;
	PSID pSid = NULL;

	try
	{
		GetUserSid(username, pSid);

		LSA_OBJECT_ATTRIBUTES objectAttr = { 0 };
		CheckLsaRetValue(::LsaOpenPolicy(NULL, &objectAttr,
			POLICY_LOOKUP_NAMES | POLICY_VIEW_LOCAL_INFORMATION,
			&hPolicy));

		vector<wstring> rights;

		ULONG rightsCount = 0;
		NTSTATUS retValue = ::LsaEnumerateAccountRights(hPolicy, pSid, &usRights, &rightsCount);
		if (retValue != STATUS_OBJECT_NAME_NOT_FOUND)
		{
			CheckLsaRetValue(retValue);
			for (ULONG i = 0; i < rightsCount; i++)
			{
				wstring str(usRights[i].Buffer, usRights[i].Length / sizeof(WCHAR));
				rights.push_back(str);
			}
		}

		::GlobalFree(pSid);
		if (usRights)
			::LsaFreeMemory(usRights);
		::LsaClose(hPolicy);

		return rights;
	}
	catch (exception&)
	{
		if (pSid)
			::GlobalFree(pSid);
		if (usRights)
			::LsaFreeMemory(usRights);
		if (hPolicy)
			::LsaClose(hPolicy);
		throw;
	}
}

void AssignUserRights(const wstring& username, const vector<wstring> rights)
{
	LSA_HANDLE hPolicy = NULL;
	PLSA_UNICODE_STRING usRights = NULL;
	PSID pSid = NULL;

	try
	{
		GetUserSid(username, pSid);

		LSA_OBJECT_ATTRIBUTES objectAttr = { 0 };
		CheckLsaRetValue(::LsaOpenPolicy(NULL, &objectAttr,
			POLICY_ALL_ACCESS,
			&hPolicy));

		PLSA_UNICODE_STRING usRights = (PLSA_UNICODE_STRING)::GlobalAlloc(GMEM_FIXED, sizeof(LSA_UNICODE_STRING)* rights.size());
		if (!usRights)
			throw Win32Exception();

		int i = 0;
		for (vector<wstring>::const_iterator it = rights.begin(); it != rights.end(); ++it)
			WStringToLsaUnicodeString(*it, usRights[i++]);

		CheckLsaRetValue(::LsaAddAccountRights(hPolicy, pSid, usRights, rights.size()));

		::GlobalFree(pSid);
		::GlobalFree(usRights);
		::LsaClose(hPolicy);
	}
	catch (exception&)
	{
		if (pSid)
			::GlobalFree(pSid);
		if (usRights)
			::GlobalFree(usRights);
		if (hPolicy)
			::LsaClose(hPolicy);
		throw;
	}
}

UINT __stdcall GenerateRandomPasswordAction(MSIHANDLE hInstall)
{
	UINT retValue = ERROR_INSTALL_FAILURE;

    try
    {
        wstring& password = GenerateRandomPassword();

        wstring propertyName = GetPropertyValue(hInstall, PASSWORD_MSI_PROPERTY_NAME_PROPERTY);
        if(propertyName.empty())
            propertyName = PASSWORD_MSI_DEFAULT_PROPERTY_NAME;

        LogMessage(hInstall, (L"Random password property name: " + propertyName).c_str());

        CheckRetVal(::MsiSetProperty(hInstall, propertyName.c_str(), password.c_str()));

        LogMessage(hInstall, L"Random password generated");

        retValue = ERROR_SUCCESS;
    }
    catch(MessageException& ex)
    {
        LogException(hInstall, ex);
    }
    catch(exception& ex)
    {
        LogException(hInstall, ex);
    }

    return retValue;
}

UINT __stdcall AssignUserRightsAction(MSIHANDLE hInstall)
{
	UINT retValue = ERROR_INSTALL_FAILURE;

    try
    {
		vector<wstring> data;
		SplitCustomData(hInstall, data);

        const wstring& username = data[0];
        vector<wstring> requestedRights;
        Split(data[1].c_str(), L',', requestedRights);

        const vector<wstring> assignedRights = GetUserRights(username);

        vector<wstring> rightsToBeAssigned;
        for(vector<wstring>::const_iterator it = requestedRights.begin(); it != requestedRights.end(); ++it)
        {
            const wstring& requestedRight = *it; 
            if (find(assignedRights.begin(), assignedRights.end(), requestedRight) == assignedRights.end())
            {
                rightsToBeAssigned.push_back(requestedRight);
                LogMessage(hInstall, (L"User right to be assigned: " + requestedRight).c_str());
            }
        }

		if (rightsToBeAssigned.size() > 0)
            AssignUserRights(username, rightsToBeAssigned);

        LogMessage(hInstall, L"User rights assigned");

        retValue = ERROR_SUCCESS;
    }
    catch(MessageException& ex)
    {
        LogException(hInstall, ex);
    }
    catch(exception& ex)
    {
        LogException(hInstall, ex);
    }

    return retValue;
}
