// stdafx.cpp : source file that includes just the standard includes
//	srvman.pch will be the pre-compiled header
//	stdafx.obj will contain the pre-compiled type information

#include "stdafx.h"
#include "command.h"
#include "log.h"

//C++11
#include <thread>

using namespace std;

int SystemCapture(
    string         CmdLine,    //Command Line
    string         CmdRunDir,  //set to '.' for current directory
    string& ListStdOut, //Return List of StdOut
    string& ListStdErr, //Return List of StdErr
    uint32_t& RetCode)    //Return Exit Code
{
    int                  Success;
    SECURITY_ATTRIBUTES  security_attributes;
    HANDLE               stdout_rd = INVALID_HANDLE_VALUE;
    HANDLE               stdout_wr = INVALID_HANDLE_VALUE;
    HANDLE               stderr_rd = INVALID_HANDLE_VALUE;
    HANDLE               stderr_wr = INVALID_HANDLE_VALUE;
    PROCESS_INFORMATION  process_info;
    STARTUPINFOA          startup_info;
    thread               stdout_thread;
    thread               stderr_thread;

    security_attributes.nLength = sizeof(SECURITY_ATTRIBUTES);
    security_attributes.bInheritHandle = TRUE;
    security_attributes.lpSecurityDescriptor = nullptr;

    if (!CreatePipe(&stdout_rd, &stdout_wr, &security_attributes, 0) ||
        !SetHandleInformation(stdout_rd, HANDLE_FLAG_INHERIT, 0)) {
        return -1;
    }

    if (!CreatePipe(&stderr_rd, &stderr_wr, &security_attributes, 0) ||
        !SetHandleInformation(stderr_rd, HANDLE_FLAG_INHERIT, 0)) {
        if (stdout_rd != INVALID_HANDLE_VALUE) CloseHandle(stdout_rd);
        if (stdout_wr != INVALID_HANDLE_VALUE) CloseHandle(stdout_wr);
        return -2;
    }

    ZeroMemory(&process_info, sizeof(PROCESS_INFORMATION));
    ZeroMemory(&startup_info, sizeof(STARTUPINFO));

    startup_info.cb = sizeof(STARTUPINFO);
    startup_info.hStdInput = 0;
    startup_info.hStdOutput = stdout_wr;
    startup_info.hStdError = stderr_wr;

    if (stdout_rd || stderr_rd)
        startup_info.dwFlags |= STARTF_USESTDHANDLES;

    // Make a copy because CreateProcess needs to modify string buffer
    char      CmdLineStr[MAX_PATH];
    strncpy(CmdLineStr, CmdLine.c_str(), MAX_PATH);
    CmdLineStr[MAX_PATH - 1] = 0;

    Success = CreateProcessA(
        nullptr,
        CmdLineStr,
        nullptr,
        nullptr,
        TRUE,
        0,
        nullptr,
        CmdRunDir.c_str(),
        &startup_info,
        &process_info
    );
    CloseHandle(stdout_wr);
    CloseHandle(stderr_wr);

    if (!Success) {
        CloseHandle(process_info.hProcess);
        CloseHandle(process_info.hThread);
        CloseHandle(stdout_rd);
        CloseHandle(stderr_rd);
        return -4;
    }
    else {
        CloseHandle(process_info.hThread);
    }

    if (stdout_rd) {
        stdout_thread = thread([&]() {
            DWORD  n;
            const size_t bufsize = 1000;
            char         buffer[bufsize];
            for (;;) {
                n = 0;
                int Success = ReadFile(
                    stdout_rd,
                    buffer,
                    (DWORD)bufsize,
                    &n,
                    nullptr
                );
                printf("STDERR: Success:%d n:%d\n", Success, (int)n);
                if (!Success || n == 0)
                    break;
                string s(buffer, n);
                printf("STDOUT:(%s)\n", s.c_str());
                ListStdOut += s;
            }
            printf("STDOUT:BREAK!\n");
            });
    }

    if (stderr_rd) {
        stderr_thread = thread([&]() {
            DWORD        n;
            const size_t bufsize = 1000;
            char         buffer[bufsize];
            for (;;) {
                n = 0;
                int Success = ReadFile(
                    stderr_rd,
                    buffer,
                    (DWORD)bufsize,
                    &n,
                    nullptr
                );
                printf("STDERR: Success:%d n:%d\n", Success, (int)n);
                if (!Success || n == 0)
                    break;
                string s(buffer, n);
                printf("STDERR:(%s)\n", s.c_str());
                ListStdErr += s;
            }
            printf("STDERR:BREAK!\n");
            });
    }

    WaitForSingleObject(process_info.hProcess, INFINITE);
    if (!GetExitCodeProcess(process_info.hProcess, (DWORD*)&RetCode))
        RetCode = -1;

    CloseHandle(process_info.hProcess);

    if (stdout_thread.joinable())
        stdout_thread.join();

    if (stderr_thread.joinable())
        stderr_thread.join();

    CloseHandle(stdout_rd);
    CloseHandle(stderr_rd);

    return 0;
}
