using System;
using System.Collections.Generic;
using System.Diagnostics;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace AzureCM.Module.Utilities
{
    /// <summary>
    /// The Logger class provides wrapper methods to the LogManager.
    /// </summary>
    public class ConfigurationLogger
    {
        /// <summary>
        /// Initializes the <see cref="Logger"/> class.
        /// </summary>
        public ConfigurationLogger()
        {
        }

        /// <summary>
        /// Logs the specified message as a debug statement
        /// </summary>
        /// <param name="fmt">The message to be logged</param>
        /// <param name="vars"></param>
        public void Debugging(string fmt, params object[] vars)
        {
            var message = string.Format(fmt, vars);
            System.Diagnostics.Trace.TraceInformation(message);
        }

        /// <summary>
        /// Logs the specified formatted message string with arguments
        /// </summary>
        /// <param name="fmt"></param>
        /// <param name="vars"></param>
        public void Information(string fmt, params object[] vars)
        {
            string message;
            if (vars != null && vars.Length > 0)
            {
                message = string.Format(fmt, vars);
            }
            else
            {
                message = fmt;
            }

            Trace.TraceInformation(message);
        }

        /// <summary>
        /// Logs the specified message as a warning statement
        /// </summary>
        /// <param name="message">The message to be logged</param>
        /// <param name="ex">The exception to be included in the log</param>
        public void Warning(string message, Exception ex = null)
        {
            Trace.TraceWarning(message);
        }

        /// <summary>
        /// Logs the specified message as a warning statement
        /// </summary>
        /// <param name="fmt">The message to be logged</param>
        /// <param name="vars">collection of values to be injected in string format</param>
        public void Warning(string fmt, params object[] vars)
        {
            Warning(string.Format(fmt, vars));
        }

        /// <summary>
        /// Logs the specified message as an error
        /// </summary>
        /// <param name="ex">The exception to be logged</param>
        /// <param name="message">The message to be logged</param>
        public void Error(Exception ex, string message)
        {
            Trace.TraceError(message);
        }

        /// <summary>
        /// Logs the exception with the specified message
        /// </summary>
        /// <param name="ex"></param>
        /// <param name="fmt"></param>
        /// <param name="vars"></param>
        public void Error(Exception ex, string fmt, params object[] vars)
        {
            Trace.TraceError(fmt, vars);
            System.Diagnostics.Trace.TraceError("Exception: {0}", ex.Message);
        }

        /// <summary>
        /// Simple exception formatting: for a more comprehensive version see 
        ///     http://code.msdn.microsoft.com/windowsazure/Fix-It-app-for-Building-cdd80df4
        /// </summary>
        /// <param name="exception"></param>
        /// <param name="fmt"></param>
        /// <param name="vars"></param>
        /// <returns></returns>
        private string FormatExceptionMessage(Exception exception, string fmt, object[] vars)
        {
            var sb = new StringBuilder();
            sb.Append(string.Format(fmt, vars));
            sb.Append(" Exception: ");
            sb.Append(exception.ToString());
            return sb.ToString();
        }
    }
}
