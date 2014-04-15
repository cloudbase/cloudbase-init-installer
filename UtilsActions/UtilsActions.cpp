// UtilsActions.cpp : Defines the exported functions for the DLL application.
//

#include "stdafx.h"
#include "UtilsActions.h"
#include "MSIUtils.h"

#include <sstream>

using namespace std;

#define PASSWORD_LENGTH 20
#define PASSWORD_MSI_PROPERTY L"GENERATED_PASSWORD"

UINT __stdcall GenerateRandomPassword(MSIHANDLE hInstall)
{
	UINT retValue = ERROR_INSTALL_FAILURE;

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

        retValue = ::MsiSetProperty(hInstall, PASSWORD_MSI_PROPERTY, passwordss.str().c_str());

        LogMessage(hInstall, L"Random password generated");
    }
    catch(MessageException& ex)
    {
        LogException(hInstall, ex);
    }

    if(hProvider)
	    ::CryptReleaseContext(hProvider, 0);

    return retValue;
}