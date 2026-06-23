#pragma once
#include <string>
#include <windows.h>
#include <cstring>
#include <cstdio>
#include <cstdarg>

namespace ATL {

// Minimal CString stub
class CStringT {
private:
    char* m_str;
    mutable int m_len;
public:
    CStringT() : m_str(nullptr), m_len(0) {}
    CStringT(const char* s) {
        if (s) { m_len = (int)strlen(s); m_str = new char[m_len + 1]; strcpy(m_str, s); }
        else { m_str = nullptr; m_len = 0; }
    }
    ~CStringT() { delete[] m_str; }
    CStringT(const CStringT& o) {
        m_len = o.m_len;
        m_str = o.m_str ? new char[m_len + 1] : nullptr;
        if (m_str) strcpy(m_str, o.m_str);
    }
    CStringT& operator=(const CStringT& o) {
        if (this != &o) { delete[] m_str; m_len = o.m_len; m_str = o.m_str ? new char[m_len + 1] : nullptr; if (m_str) strcpy(m_str, o.m_str); }
        return *this;
    }
    operator const char*() const { return m_str ? m_str : ""; }
    const char* GetString() const { return m_str ? m_str : ""; }
    int GetLength() const { return m_len; }
    bool IsEmpty() const { return m_len == 0 || !m_str; }
};

typedef CStringT CString;
typedef CStringT CStringA;

// CA2W: Convert ANSI/UTF-8 to Wide (Unicode)
class CA2W {
public:
    wchar_t* m_psz;
    CA2W(const char* str) : m_psz(nullptr) {
        if (str) {
            int len = MultiByteToWideChar(CP_UTF8, 0, str, -1, nullptr, 0);
            m_psz = new wchar_t[len];
            MultiByteToWideChar(CP_UTF8, 0, str, -1, m_psz, len);
        }
    }
    CA2W(const std::string& str) : m_psz(nullptr) {
        int len = MultiByteToWideChar(CP_UTF8, 0, str.c_str(), -1, nullptr, 0);
        m_psz = new wchar_t[len];
        MultiByteToWideChar(CP_UTF8, 0, str.c_str(), -1, m_psz, len);
    }
    ~CA2W() { delete[] m_psz; }
    operator const wchar_t*() const { return m_psz ? m_psz : L""; }
};

// CW2A: Convert Wide to UTF-8
class CW2A {
public:
    char* m_psz;
    CW2A(const wchar_t* str) : m_psz(nullptr) {
        if (str) {
            int len = WideCharToMultiByte(CP_UTF8, 0, str, -1, nullptr, 0, nullptr, nullptr);
            m_psz = new char[len];
            WideCharToMultiByte(CP_UTF8, 0, str, -1, m_psz, len, nullptr, nullptr);
        }
    }
    ~CW2A() { delete[] m_psz; }
    operator const char*() const { return m_psz ? m_psz : ""; }
};

}  // namespace ATL

using ATL::CString;
using ATL::CStringA;
using ATL::CA2W;
using ATL::CW2A;
