

#pragma once

#include <windows.h>
#include <string>


int SystemCapture(
    std::string         CmdLine,    //Command Line
    std::string         CmdRunDir,  //set to '.' for current directory
    std::string& ListStdOut, //Return List of StdOut
    std::string& ListStdErr, //Return List of StdErr
    uint32_t& RetCode);
