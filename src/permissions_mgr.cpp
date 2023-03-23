
//==============================================================================
//
//   injectors.cpp

//
//==============================================================================
//  
//==============================================================================


#include "stdafx.h"
#include "permissions_mgr.h"
#include "log.h"
#include "command.h"
#include <stdio.h>
#include <Windows.h>
#include <tlhelp32.h>
#include "PropertiesDlg.h"

#include <AtlBase.h>
#include <atlconv.h>

PermissionsMgr::PermissionsMgr(char* name, CPropertiesDlg *dlg)
{
	LOG_TRACE("PermissionsMgr::PermissionsMgr", "        0x%.8X", dlg);
    memset(process_name, 0, MAX_PATH);
    strncpy(process_name, name, MAX_PATH - 1);
	m_dlg = dlg;
	isLoaded = false;
}

PermissionsMgr::~PermissionsMgr()
{
	Reset();
}

void PermissionsMgr::Reset()
{
	LOG_TRACE("PermissionsMgr::Reset", "Resetting");
}
void PermissionsMgr::Wait(DWORD ms) 
{

};

unsigned long PermissionsMgr::Process(void* parameter)
{
    //m_dlg->DisablePermissionsBox();
    m_dlg->AddPermissionsText(_T("Querying Service Permissions..."));
    int            rc;
    uint32_t       RetCode;
    std::string         ListStdOut;
    std::string         ListStdErr;

    LOG_TRACE("PermissionsMgr::Process", "Process Starting");

    char cmdline_string[MAX_PATH];
    memset(cmdline_string, 0, MAX_PATH);
    strncpy(cmdline_string, "sc.exe sdshow ", MAX_PATH - 1);
    strncat(cmdline_string, process_name, MAX_PATH - 1);
    rc = SystemCapture(
        cmdline_string,    //Command Line
        ".",                                     //CmdRunDir
        ListStdOut,                              //Return List of StdOut
        ListStdErr,                              //Return List of StdErr
        RetCode                                  //Return Exit Code
    );
    if (rc < 0) {

        LOG_TRACE("PermissionsMgr::Process", "ERROR: SystemCapture");
    }

    LOG_TRACE("PermissionsMgr::Process", "STDOUT: %s", ListStdOut.c_str());
    LOG_TRACE("PermissionsMgr::Process", "STDERR: %s", ListStdErr.c_str());
    LOG_TRACE("PermissionsMgr::Process", "Process Done");

    CA2W ca2w(ListStdOut.c_str());
    std::wstring w = ca2w;
   
    printf("%s = %ls", ListStdOut.c_str(), w.c_str());
    m_dlg->AddPermissionsText(w.c_str());
    return 0;
}





