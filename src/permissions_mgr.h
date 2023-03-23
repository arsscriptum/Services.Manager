
//==============================================================================
//
//   permissions_mgr.h
//
//
//==============================================================================
//  
//==============================================================================

#ifndef __PERMISSIONS_MGR_H__
#define __PERMISSIONS_MGR_H__


//win32 specific
#include <windows.h>
#include "cthread.h"

#define DLL_PATH_SIZE 150
class PermissionsMgr : public CThread
{
public:
	PermissionsMgr(char *name, class CPropertiesDlg *dlg);
	~PermissionsMgr();


	void Reset();
	bool IsLoaded() { return isLoaded; };
	void Wait(DWORD ms = -1);
	

protected:

	unsigned long Process(void* parameter);

private:
	bool isLoaded;
	class CPropertiesDlg *m_dlg;
	char process_name[MAX_PATH];
};


#endif //__PERMISSIONS_MGR_H__