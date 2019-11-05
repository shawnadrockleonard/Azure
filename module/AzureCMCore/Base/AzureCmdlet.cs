using AzureCMCore.oAuth;
using Microsoft.Extensions.Configuration;
using System;
using System.Diagnostics;
using System.Globalization;
using System.IO;
using System.Management.Automation;
using System.Reflection;

namespace AzureCMCore.Base
{
    public abstract class AzureCmdlet : PSCmdlet
    {
        internal static IConfigurationRoot Configuration;
        internal static AppSettings AuthenticationSettings;

        /// <summary>
        /// If True then only write verbose statements to the log and do not perform any action
        /// </summary>
        [Parameter(Mandatory = false)]
        public SwitchParameter DoNothing { get; set; }


        // This method gets called once for each cmdlet in the pipeline when the pipeline starts executing
        protected override void BeginProcessing()
        {
            Information("Begin!");
            BootstrapConfiguration();
        }

        // This method will be called for each input received from the pipeline to this cmdlet; if no input is received, this method is not called
        protected override void ProcessRecord()
        {
            Information("Record!");
        }


        // This method will be called once at the end of pipeline execution; if no input is received, this method is not called
        protected override void EndProcessing()
        {
            Information("End!");
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
                message = string.Format(CultureInfo.CurrentCulture, fmt, vars);
            }
            else
            {
                message = fmt;
            }

            Trace.TraceInformation(message);
            WriteVerbose(message);
        }

        /// <summary>
        /// Logs the specified message as a warning statement
        /// </summary>
        /// <param name="message">The message to be logged</param>
        /// <param name="ex">The exception to be included in the log</param>
        public void Warning(string message, Exception ex = null)
        {
            if (ex != null)
            {
                message = $"{message} with exception: {ex.Message}";
            }
            Trace.TraceWarning(message);
            WriteWarning(message);
        }

        /// <summary>
        /// Logs the specified message as a warning statement
        /// </summary>
        /// <param name="fmt">The message to be logged</param>
        /// <param name="vars">collection of values to be injected in string format</param>
        public void Warning(string fmt, params object[] vars)
        {
            Warning(string.Format(CultureInfo.CurrentCulture, fmt, vars));
        }

        /// <summary>
        /// Logs the specified message as an error
        /// </summary>
        /// <param name="ex">The exception to be logged</param>
        /// <param name="message">The message to be logged</param>
        public void Error(Exception ex, string message)
        {
            Trace.TraceError(message);
            WriteError(new ErrorRecord(ex, "errorId", ErrorCategory.NotSpecified, null)
            {
                ErrorDetails = new ErrorDetails(message)
            });
        }

        /// <summary>
        /// Logs the exception with the specified message
        /// </summary>
        /// <param name="ex"></param>
        /// <param name="fmt"></param>
        /// <param name="vars"></param>
        public void Error(Exception ex, string fmt, params object[] vars)
        {
            if (ex == null)
            {
                throw new ArgumentNullException(nameof(ex));
            }

            Trace.TraceError(fmt, vars);
            Trace.TraceError("Exception: {0}", ex.Message);
            WriteError(new ErrorRecord(ex, "errorId", ErrorCategory.NotSpecified, null)
            {
                ErrorDetails = new ErrorDetails(ex.StackTrace)
            });
        }

        public void Error(Exception ex, ErrorCategory category, string message, params object[] args)
        {
            if (ex == null)
            {
                throw new ArgumentNullException(nameof(ex));
            }

            Trace.TraceError(message, args);
            Trace.TraceError("Exception: {0}", ex.Message);
            WriteError(new ErrorRecord(ex, "HALT", category, null));
        }

        private static void BootstrapConfiguration()
        {
            string env = Environment.GetEnvironmentVariable("ASPNETCORE_ENVIRONMENT");

            if (string.IsNullOrWhiteSpace(env))
            {
                env = "Development";
            }

            var builder = new ConfigurationBuilder()
                .SetBasePath($"{Directory.GetCurrentDirectory()}/module/AzureCMCore")
                .AddJsonFile("appsettings.json")
                .AddUserSecrets<AzureCmdlet>()
                .AddEnvironmentVariables();

            if (env == "Development")
            {
                builder.AddUserSecrets<AzureCmdlet>();
            }

            AuthenticationSettings = new AppSettings();
            Configuration = builder.Build();
            Configuration.Bind("Authentication", AuthenticationSettings);
        }

        internal string GetAppSetting(string appSetting)
        {
            return Configuration[appSetting];
        }
    }
}
