/*
 * filedialog.c
 */


#include <windows.h>
#include <tchar.h>

int getNewFile (HWND hDlg, UINT uMsg, WPARAM wParam, LPARAM lParam)
{
	OPENFILENAME ofn;       // common dialog box structure
	TCHAR szFile[260] = { 0 };       // if using TCHAR macros

	// Initialize OPENFILENAME
	ZeroMemory(&ofn, sizeof(ofn));
	ofn.lStructSize = sizeof(ofn);
	ofn.hwndOwner = hDlg;
	ofn.lpstrFile = szFile;
	ofn.nMaxFile = sizeof(szFile);
	ofn.lpstrFilter = _T("All\0*.*\0Text\0*.TXT\0");
	ofn.nFilterIndex = 1;
	ofn.lpstrFileTitle = NULL;
	ofn.nMaxFileTitle = 0;
	ofn.lpstrInitialDir = NULL;
	ofn.Flags = OFN_PATHMUSTEXIST | OFN_FILEMUSTEXIST;

	if (GetOpenFileName(&ofn) == TRUE)
	{
		// use ofn.lpstrFile
	}
	return 0;
}


INT_PTR CALLBACK DialogProc(HWND hDlg, UINT uMsg, WPARAM wParam, LPARAM lParam)
{
  switch(uMsg)
  {
  case WM_COMMAND:
    switch(LOWORD(wParam))
    {
    case IDCANCEL:
      SendMessage(hDlg, WM_CLOSE, 0, 0);
      return TRUE;
    }
    break;

  case WM_CLOSE:
    if(MessageBox(hDlg, TEXT("Close the program?"), TEXT("Close"),
      MB_ICONQUESTION | MB_YESNO) == IDYES)
    {
      DestroyWindow(hDlg);
    }
    return TRUE;

  case WM_DESTROY:
    PostQuitMessage(0);
    return TRUE;
  }

  return FALSE;
}

int get_file_dialog(HINSTANCE hInst, HINSTANCE h0, LPTSTR lpCmdLine, int nCmdShow)
{
	HWND hDlg;
	MSG msg;
	BOOL ret;

	if(!IsDialogMessage(hDlg, &msg)) {
	TranslateMessage(&msg);
	DispatchMessage(&msg);
	}

	return 0;
}
