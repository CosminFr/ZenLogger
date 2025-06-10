# 🧾 ZenLogger

A lightweight, extensible, and thread-safe logging implementation for Delphi applications, built with simplicity, traceability, and performance in mind.

ZenLogger introduces a clean `ILogger` interface and multiple interchangeable logger implementations, suitable for anything from simple CLI tools to complex multithreaded GUI applications.

#### 🚀 Features

- Five log levels: *Error*, *Warning*, *Info*, *Debug*, *Trace*
- Pluggable logger kinds: *Null*, *Standard*, *Console*, *Async*, *ThreadSafe*, *Mock*
- File rotation with retention policy
- Trace logger extension with profiling support
- Sync and async implementations
- Thread-safe with minimal file locking
- Centralized initialization via `LogManager`


## 🔧 Usage Overview

Copy source files to your project, include ZenLogger in uses clause and start using it.  

**Using [Default Configuration](#%EF%B8%8F-configuration)**
```pascal
uses ZenLogger;

procedure FooBar()
begin
  Log.Info('FooBar started.');
  try
    ...
    Log.Debug('Stage values for FooBar: Text="%s"; Index=%d', [sText, i]);
    ...
  except
    on E: Exception do begin
      Log.Error('Error in FooBar: ', E);
      raise; //log but don't ignore it!
    end;
end;
```


**Your preferred Configuration**  
To use a different logger within your project, make sure the logger is included in the project (*.dpr) file and set the default values before using the *Log.\** functions.

```pascal
uses ZenLogger, AsyncLogger, ...

begin
  InitializeLogger(LOG_KIND_ASYNC, LL_DEBUG, '', '', 1);
  Log.Info('Application started.');
  ...
end;
```

> [!TIP]
> Have "Logging" options included with your project settings instead of hardcoded values. <br>
> Especially *LogLevel* and *LogPath*! Your clients should be able to change them without asking for a special build.


**Use Trace Logger**  
To automatically add ClassName & MethodName in every log call, use a localized "trace" logger:
```pascal
procedure TFoo.Bar;
var Log: ILogger;
begin
  Log := GetTraceLogger(ClassName, 'Bar');
  Log.Info('Step 1 - ...');
  // Code
end;
```
Every log line above will include `TFoo.Bar: ` as a "context" for the log message. This is especialy useful in complex inheritance cases.

Additionally, it automatically handles the *Enter*/*Exit* trace messages (when log level is *Trace*). See [🧭 Trace Logger & Profiling](#-trace-logger--profiling) for details.


#### Why ZenLogger?
There are almost as many logger implementations as there are large projects or frameworks. Why adding another one?

Some are too complex, or require installation (services or DLLs), or are not thread-safe, or not playing nice locking the files and/or crashing the whole app if tampering with the log file in notepad.

The bottom line is if you have a good logger, you are not reading this and ZenLogger is not for you.

ZenLogger was made to be simple to use, yet fast, thread safe and customizable. Use it "as is" or extend to your specific needs.

#### Can ZenLogger be used with old code?
There are many different ways to adapt to old code. Some ideas:
- *Extend the ILogger interface*: Create an extension of ILooger interface with whatever "LogMsg" functions are used everywhere in the code and implement the new logger kind. It's quite easy, just format the line as needed and let the base class handle the logging.
  In time, the code can use the clean ILogger interface (or not). Either way, they would both lead to the same log.
> [!Tip]
> Remove the old units to ensure there is only one log implementation. Otherwise, it could become very messy and confusing.

- *Internally use the new Logger*: Replace the old logging implementation with calls to the new ZenLogger. As the ZenLogger is initialized, you could also slowly change the code to directly use the ZenLogger (or not).
- *Use LogFileStream directly*: Ignore most of the ZenLogger boilerplate and change the log file access from previous logging implementation. Open source code advantage. You can easily see and emulate the internals of ZenLogger file access.

If unsure, or prefer an external consultant to handle the conversion, feel free to contact me for a quote at: contact@zendev4d.com. 


## 📈 Log Levels

| Level     | Purpose                                                               |
|-----------|-----------------------------------------------------------------------|
| *Error*   | Indicates a serious problem that has caused a failure in part of the application (e.g. exceptions or critical failures)  |
| *Warning* | Highlights a potential issue or unexpected behavior that isn't immediately harmful but may lead to problems              |
| *Info*    | Provides general operational messages that track the application’s progress  |
| *Debug*   | Gives detailed diagnostic information useful for debugging (e.g. internal state changes, variable values) |
| *Trace*   | The most detailed level, showing step-by-step execution or fine-grained application flow, typically used for in-depth troubleshooting |



## 🧱 Logger Kinds

| Logger Kind   | Description                                                                 |
|---------------|-----------------------------------------------------------------------------|
| *Null*        | Ignores all messages.                                                       |
| *Standard*    | Logs directly to file (sync). Base class for file-based logging.            |
| *Console*     | Logs to console or `OutputDebugString` depending on app type.               |
| *Async*       | Queues messages and writes in background using `TTask`.                     |
| *ThreadSafe*  | Adds mutex locking and thread ID to logs. Useful for concurrency debugging. |
| *Mock*        | Used for unit testing where the a log file is not needed. Instead, the mock logger fires events  |


#### 🚫 Null Logger

The `Null Logger` is an easy way to disable all logs from the application. 


#### 📂 "Standard" File Logging

`TFileLogger` is synchronous, thread-safe and reliable logging to file.

- File name: `{LogName}_yyyy-mm-dd.log`
- Auto-deletes files older than `DaysKeep`
- Safe for general use and crash diagnostics

`TFileLogger` is the base class for all file loggers.

#### 🖥 Console Logger

For CLI *(command-line interface)* programs that rely on console output, `TConsoleLogger` detects if the standard console output is available and sends logs directly to the terminal in real-time.
Otherwise, it uses `OutputDebugString` API function sending logs to a *debugger*.


#### ⚡ Async Logger

- Uses a thread-safe queue + background `TTask` to write logs
- Significantly faster than standard logger
- Log file written in batches

#### 🧵 Thread-Safe Logger
The name is a misnomer, as all other loggers are thread-safe. This was an early attempt, but remained due its usefulness when debugging multi-threaded apps.
- Adds `TH-<ThreadID>` to each log entry
- Better visibility when diagnosing thread-related issues
- Enforces exclusive file access using a mutex

#### 🧪 Mock Logger

`TMockLogger` is used for unit testing, allowing validation of log calls without actual output. 

Use `TMockLogger.RegisterMockHandler` to register event handlers before hand.

Instead or writing logs, it triggers those registered events to validate what it should have been sent to the log.


#### 🧭 Trace Logger & Profiling

`ITraceLogger` wraps a method or scope to log execution entry, exit, and duration.

```pascal
procedure TSortThread.ArraySwap(I, J: Integer);
begin
  var Log := GetTraceLogger(ClassName, 'ArraySwap', fLogger).Trace;
  Log.Debug('Swapping %d, %d', [I, J]);
  // Do the swap...
end;
```

When `LogLevel = LL_TRACE`, adds:

- Enter/Exit "Trace" log lines
- Elapsed time
- Profiling stats

```
20:15:30.350 TRACE..... >>> TQuickSort.ArraySwap  
20:15:30.350 DEBUG..... TQuickSort.ArraySwap: Swapping 735, 998  
20:15:30.350 TRACE..... <<< TQuickSort.ArraySwap (2 ms)  
20:15:30.350 TRACE..... <<< TQuickSort.Execute (31.279 sec)  
```

🔬 Tip: Use `.Trace` to track performance even when `LogLevel` is lower.
```
Function: TQuickSort.Execute
  Exec Count: 1
  Total Time: 31.279 s
Function: TQuickSort.ArraySwap
  Exec Count: 2668
  Total Time: 9.095 s
    Max Time: 17 ms
    Min Time: 3 ms
    Avg Time: 3 ms
```

---


## 🛠️ Configuration

Global logger is initialized on first use, or via:

```
procedure InitializeLogger(LogKind, LogLevel, LogName, LogPath, DaysKeep);
```

All parameters are optional. With no params, it's used to explicitly initialize the global logger using the default configuration:

| Configuration Variable   | Default Value  | Description                                                     |
|--------------------------|----------------|-----------------------------------------------------------------|
| Default_LogKind          | 1 = *Standard* | The basic file logger. Thread safe, synchronous logging.        |
| Default_LogLevel         | 3 = *Info*     | see [Log Levels](#-log-levels).                                 |
| Default_LogName          | '' <empty>     | if empty - use the file name from `ModuleName` (app or library) |
| Default_LogPath          | '' <empty>     | if empty - use the path as above.                               |
| Default_DaysKeep         | 30             | Keep for a month, just in case there are delays in reporting issues. |

Set these before logging begins, or call `ReleaseLogger` to force re-initialization from updated defaults.

> [!Note]
> It make more sense to read these from your application configuration (file/registry).<br>
> Your clients should be able to set the retention period, location and log level. Turn it down to *Warnings* and *Errors*, or turn it up to *Debug* (or *Trace*) while investigating issues.

---
## 🧬 Demo Projects

Check the `/Demo` folder:
- `Sort Algorithms`: shows `TraceLogger` usage
- `Multi Thread`: compares logger kinds side-by-side

---

## 📜 License

Dual-licensed:
- **GPL v3 licence** - You may choose to use for free, under the restrictions of the **GPL v3 licence**, or 
- Purchase a **commercial licence**. Which grants you the right to use in your own applications, royalty free, without any requirement to disclose your source code nor any modifications to any other party. 

Please consider supportting this project by donating ("Buy me a coffee", "Thanks.dev", "Paypal").

---

## 🙏 Contributions

Feel free to submit pull requests, report bugs or suggest improvements. This project is intended to stay small but powerful.
