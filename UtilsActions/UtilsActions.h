#pragma once

#include <string>
#include <vector>

std::wstring GenerateRandomPassword();
void GetUserSid(const std::wstring& username, PSID &pSid);
std::vector<std::wstring> GetUserRights(const std::wstring& username);
void AssignUserRights(const std::wstring& username, const std::vector<std::wstring> rights);
