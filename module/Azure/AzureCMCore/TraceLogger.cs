using System;
using System.Collections.Generic;
using System.Diagnostics;
using System.Runtime.CompilerServices;
using System.Text;

namespace AzureCMCore
{
    public static class TraceLogger
    {
        private static SourceLevels TraceLevel { get; set; }

        static TraceLogger()
        {
        }


        private static string Format(string msg)
        {
            return string.Format("{0}\t{1}", DateTime.Now.ToString("yyyy/MM/dd HH:mm:ss"), msg);
        }

        private static string Format(string message, string memberName, string filePath, int lineNumber)
        {
            return $"Message: {Format(message)}, MemberName: {memberName}, FilePath: {filePath}, LineNumber: {lineNumber}";
        }


        public static void Verbose(string message, int id = 16, [CallerMemberName]string memberName = "", [CallerFilePath] string filePath = "", [CallerLineNumber]int lineNumber = 0)
        {
            Trace.TraceInformation(Format(message, memberName, filePath, lineNumber));
        }

        public static void Information(string message, int id = 8, [CallerMemberName]string memberName = "", [CallerFilePath] string filePath = "", [CallerLineNumber]int lineNumber = 0)
        {
            Trace.TraceInformation(Format(message, memberName, filePath, lineNumber));
        }

        public static void Warning(string message, int id = 4, [CallerMemberName]string memberName = "", [CallerFilePath] string filePath = "", [CallerLineNumber]int lineNumber = 0)
        {
            Trace.TraceWarning(Format(message, memberName, filePath, lineNumber));
        }

        public static void Error(string message, int id = 2, [CallerMemberName]string memberName = "", [CallerFilePath] string filePath = "", [CallerLineNumber]int lineNumber = 0)
        {
            Trace.TraceError(Format(message, memberName, filePath, lineNumber));
        }

        public static void Critical(string message, int id = 1, [CallerMemberName]string memberName = "", [CallerFilePath] string filePath = "", [CallerLineNumber]int lineNumber = 0)
        {
            Trace.TraceError(Format(message, memberName, filePath, lineNumber));
        }

        public static void Start(string service, int id = 256, [CallerMemberName]string memberName = "", [CallerFilePath] string filePath = "", [CallerLineNumber]int lineNumber = 0)
        {
            Trace.TraceInformation(Format("Starting - " + service, memberName, filePath, lineNumber));
        }

        public static void Stop(string service, int id = 512, [CallerMemberName]string memberName = "", [CallerFilePath] string filePath = "", [CallerLineNumber]int lineNumber = 0)
        {
            Trace.TraceInformation(Format("Stoping - " + service, memberName, filePath, lineNumber));
        }

    }

}