@if "%DEBUG%" == "" @echo off

@rem -----------------------------------------------------------------------
@rem Copyright 2009-2011 the original author or authors.
@rem
@rem Licensed under the Apache License, Version 2.0 (the "License");
@rem you may not use this file except in compliance with the License.
@rem You may obtain a copy of the License at
@rem
@rem     http://www.apache.org/licenses/LICENSE-2.0
@rem
@rem Unless required by applicable law or agreed to in writing, software
@rem distributed under the License is distributed on an "AS IS" BASIS,
@rem WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
@rem See the License for the specific language governing permissions and
@rem limitations under the License.
@rem -----------------------------------------------------------------------

setlocal
:begin

@rem ----------------------------------------
@rem Save script path
@rem ----------------------------------------

set DIRNAME=%~dp0
if "%DIRNAME%" == "" set DIRNAME=.\

@rem ----------------------------------------
@rem Parse arguments
@rem ----------------------------------------

:loop_args
    if "%1" == "" (
        goto break_loop_args
    ) else if "%1" == "-v" (
        set GROOVYSERV_OPTS=%GROOVYSERV_OPTS% -Dgroovyserver.verbose=true
    ) else if "%1" == "-q" (
        set OPT_QUIET=YES
    ) else if "%1" == "-p" (
        if "%2" == "" (
            echo ERROR: Port number must be specified. >&2
            goto end
        )
        set GROOVYSERVER_PORT=%2
        shift
    ) else if "%1" == "-k" (
        echo ERROR: groovyserver.bat does not support %1. >&2
        goto end
    ) else if "%1" == "-r" (
        echo ERROR: groovyserver.bat does not support %1. >&2
        goto end
    ) else (
        echo usage: groovyserver.bat [options]
        echo options:
        echo   -v       verbose output to the log file
        echo   -q       suppress starting messages
        echo  ^(-k       unsupported in groovyserver.bat^)
        echo  ^(-r       unsupported in groovyserver.bat^)
        echo   -p port  specify the port to listen
        goto end
    )
    shift
goto loop_args
:break_loop_args

@rem ----------------------------------------
@rem Find groovy command
@rem ----------------------------------------

if defined GROOVY_HOME (
    call :info_log Groovy home directory: "%GROOVY_HOME%"
    call :setup_GROOVY_BIN_from_GROOVY_HOME
) else (
    call :info_log Groovy home directory: ^(none^)
    call :setup_GROOVY_BIN_from_PATH
)

@rem ----------------------------------------
@rem Resolve GROOVYSERV_HOME
@rem ----------------------------------------

set GROOVYSERV_HOME=%DIRNAME%..\
if not exist "%GROOVYSERV_HOME%lib\groovyserv-*.jar" (
    echo ERROR: Not found a valid GROOVYSERV_HOME directory: "%GROOVYSERV_HOME%" >&2
    goto end
)
call :info_log GroovyServ home directory: "%GROOVYSERV_HOME%"

@rem ----------------------------------------
@rem Find groovyclient command
@rem ----------------------------------------

set GROOVYCLIENT_BIN=%GROOVYSERV_HOME%bin\groovyclient.exe
if not exist "%GROOVYCLIENT_BIN%" (
    echo ERROR: Not found a groovyclient command in GROOVYSERV_HOME: "%GROOVYCLIENT_BIN%" >&2
    goto end
)

@rem ----------------------------------------
@rem GroovyServ's work directory
@rem ----------------------------------------

set GROOVYSERV_WORK_DIR=%USERPROFILE%\.groovy\groovyserv\
if not exist "%GROOVYSERV_WORK_DIR%" (
    mkdir "%GROOVYSERV_WORK_DIR%"
)
call :info_log GroovyServ work directory: "%GROOVYSERV_WORK_DIR%"

@rem ----------------------------------------
@rem Port and PID and Cookie
@rem ----------------------------------------

if not defined GROOVYSERVER_PORT (
    set GROOVYSERVER_PORT=1961
)
if defined GROOVYSERV_OPTS (
    set GROOVYSERV_OPTS=%GROOVYSERV_OPTS% -Dgroovyserver.port=%GROOVYSERVER_PORT%
) else (
    set GROOVYSERV_OPTS=-Dgroovyserver.port=%GROOVYSERVER_PORT%
)
set GROOVYSERV_COOKIE_FILE=%GROOVYSERV_WORK_DIR%cookie-%GROOVYSERVER_PORT%

@rem ----------------------------------------
@rem Setup classpath
@rem ----------------------------------------

if defined CLASSPATH (
    call :info_log Original classpath: %CLASSPATH%
    set CLASSPATH=%CLASSPATH%;%GROOVYSERV_HOME%lib\*
) else (
    call :info_log Original classpath: ^(none^)
    set CLASSPATH=%GROOVYSERV_HOME%lib\*
)
call :info_log GroovyServ default classpath: "%CLASSPATH%"

@rem ----------------------------------------
@rem Setup other variables
@rem ----------------------------------------

@rem -server option for JVM (for performance) (experimental)
if defined JAVA_OPT (
    set JAVA_OPTS=-server %JAVA_OPTS%
) else (
    set JAVA_OPTS=-server
)

@rem -------------------------------------------
@rem Check duplicated invoking
@rem -------------------------------------------

@rem if connecting to server is succeed, return successfully
call :is_server_available
if not errorlevel 1 (
    echo WARN: groovyserver is already running on port %GROOVYSERVER_PORT% >&2
    goto end
)

@rem -------------------------------------------
@rem Invoke server
@rem -------------------------------------------

if exist "%GROOVYSERV_COOKIE_FILE%" del "%GROOVYSERV_COOKIE_FILE%"
if defined DEBUG (
    %GROOVY_BIN% %GROOVYSERV_OPTS% -e "org.jggug.kobo.groovyserv.GroovyServer.main(args)"
    goto end
) else (
    @rem The start command somehow doesn't update errorleve when it's succeed.
    @rem So before start commaand is invoked, make errorlevel reset explicitly.
    call :reset_errorlevel
    start ^
        "groovyserver[port:%GROOVYSERVER_PORT%]" ^
        /MIN ^
        %GROOVY_BIN% ^
        %GROOVYSERV_OPTS% ^
        -e "println('Groovyserver^(port %GROOVYSERVER_PORT%^) is running');println('Close this window to stop');org.jggug.kobo.groovyserv.GroovyServer.main(args)"
    if errorlevel 1 (
        echo ERROR: Failed to invoke groovyserver >&2
        goto end
    )
)

@rem -------------------------------------------
@rem Wait for available
@rem -------------------------------------------

call :info_log_without_linebreak Starting
:loop_wait_for_available
    call :info_log_without_linebreak .
    call :sleep_1sec

    @rem if connecting to server is succeed, return successfully
    call :is_server_available
    if not errorlevel 1 (
        goto break_check_invocation
    )
goto loop_wait_for_available
:break_check_invocation
call :info_log_empty

@rem -------------------------------------------
@rem Endpoint
@rem -------------------------------------------

:end
endlocal
exit /B %ERRORLEVEL%

@rem -------------------------------------------
@rem Common function
@rem -------------------------------------------

:info_log
setlocal
    if not "%OPT_QUIET%" == "YES" echo %*
endlocal
exit /B

:info_log_empty
setlocal
    if not "%OPT_QUIET%" == "YES" echo.
endlocal
exit /B

:info_log_without_linebreak
setlocal
    @rem trickey way to echo without newline
    if not "%OPT_QUIET%" == "YES" SET /P X=%*< NUL 1>&2
endlocal
exit /B

:sleep_1sec
setlocal
    @rem trickey way to wait one second
    ping -n 2 127.0.0.1 > NUL
endlocal
exit /B

@rem ERRORLEVEL will be modified
:is_server_available
    "%GROOVYCLIENT_BIN%" %GROOVYSERV_OPTS% -Cwithout-invoking-server -e "" > NUL 2>&1
exit /B %ERRORLEVEL%

@rem GROOVY_BIN will be modified
:setup_GROOVY_BIN_from_GROOVY_HOME
    set GROOVY_BIN=%GROOVY_HOME%\bin\groovy.bat
    if not exist "%GROOVY_BIN%" (
        echo ERROR: Not found a valid GROOVY_HOME directory: "%GROOVY_HOME%" >&2
        goto end
    )

    @rem Replace long name to short name for start command
    rem for %%A in ("%GROOVY_BIN%") do set GROOVY_BIN=%%~sA

    call :info_log Groovy command path: "%GROOVY_BIN%" ^(found at GROOVY_HOME^)
exit /B

@rem GROOVY_BIN will be modified
:setup_GROOVY_BIN_from_PATH
    call :find_groovy_from_path_and_setup_GROOVY_BIN groovy.bat
    if not defined GROOVY_BIN (
        echo ERROR: Not found a groovy command. Required either PATH having groovy command or GROOVY_HOME >&2
        goto end
    )
    call :info_log Groovy command path: "%GROOVY_BIN%" ^(found at PATH^)
exit /B

@rem GROOVY_BIN will be modified
:find_groovy_from_path_and_setup_GROOVY_BIN
    set GROOVY_BIN=%~$PATH:1
exit /B

@rem ERRORLEVEL will be modified
:reset_errorlevel
exit /B 0

