using AzureCM.Module.Utilities;
using System;
using System.Management.Automation;
using System.Reflection;
using System.Threading;


namespace AzureCM.Module.Base
{
    public abstract class AzureCmdlet : PSCmdlet, IAzureCmdLet
    {
        /// <summary>
        /// If True then only write verbose statements to the log and do not perform any action
        /// </summary>
        [Parameter(Mandatory = false)]
        public SwitchParameter DoNothing { get; set; }

        /// <summary>
        /// initializer a logger
        /// </summary>
        internal ConfigurationLogger logger = new ConfigurationLogger();

        /// <summary>
        /// The application setting config manager
        /// </summary>
        internal ConfigurationReader appSettings { get; private set; }

        private string m_cmdLetName { get; set; }
        internal string CmdLetName
        {
            get
            {
                if (string.IsNullOrEmpty(m_cmdLetName))
                {
                    var runningAssembly = Assembly.GetExecutingAssembly();
                    m_cmdLetName = this.GetType().Name;
                }
                return m_cmdLetName;
            }
        }

        /// <summary>
        /// Processed before the Execute
        /// </summary>
        protected override void BeginProcessing()
        {
            base.BeginProcessing();
            LogVerbose(">>> Begin {0} at {1}", this.CmdLetName, DateTime.Now);
        }

        /// <summary>
        /// Initializers the logger from the cmdlet
        /// </summary>
        protected virtual void PreInitialize()
        {
            var runningDirectory = this.SessionState.Path.CurrentFileSystemLocation;
            var runningAssembly = Assembly.GetExecutingAssembly();

            var appConfig = string.Format("{0}\\{1}.config", runningDirectory, runningAssembly.ManifestModule.Name).Replace("\\", @"\");
            if (System.IO.File.Exists(appConfig))
            {
                LogVerbose("AppSettings file found at {0}", appConfig);
                appSettings = new ConfigurationReader(appConfig);
            }
        }

        /// <summary>
        /// Execute custom cmdlet code
        /// </summary>
        public virtual void ExecuteCmdlet()
        {
        }

        /// <summary>
        /// Process SPO HealthCheck and validation context
        /// </summary>
        protected override void ProcessRecord()
        {
            try
            {
                PreInitialize();
                ExecuteCmdlet();
            }
            catch (Exception ex)
            {
                WriteError(new ErrorRecord(ex, "EXCEPTION", ErrorCategory.WriteError, null));
            }
        }

        /// <summary>
        /// End Processing cleanup or write logs
        /// </summary>
        protected override void EndProcessing()
        {
            base.EndProcessing();
            LogVerbose("<<< End {0} at {1}", CmdLetName, DateTime.Now);
        }

        /// <summary>
        /// retrieve app setting from app.config
        /// </summary>
        /// <param name="settingName"></param>
        /// <returns></returns>
        protected virtual string GetAppSetting(string settingName)
        {
            if (appSettings != null)
            {
                return appSettings.GetAppSetting(settingName);
            }
            return null;
        }

        /// <summary>
        /// retrieve connection string from app.config
        /// </summary>
        /// <param name="settingName"></param>
        /// <returns></returns>
        protected virtual string GetConnectionString(string settingName)
        {
            if (appSettings != null)
            {
                return appSettings.GetConnectionSetting(settingName);
            }
            return null;
        }

        /// <summary>
        /// Log: ERROR
        /// </summary>
        /// <param name="ex"></param>
        /// <param name="category"></param>
        /// <param name="message"></param>
        /// <param name="args"></param>
        protected virtual void LogError(Exception ex, ErrorCategory category, string message, params object[] args)
        {
            logger.Error(ex, message, args);
            WriteError(new ErrorRecord(ex, "HALT", category, null));
        }

        /// <summary>
        /// Log: DEBUG
        /// </summary>
        /// <param name="message"></param>
        /// <param name="args"></param>
        protected virtual void LogDebugging(string message, params object[] args)
        {
            logger.Debugging(message, args);
            WriteDebug(string.Format(message, args));
        }

        /// <summary>
        /// Writes a warning message to the cmdlet and logs to directory
        /// </summary>
        /// <param name="message"></param>
        /// <param name="args"></param>
        protected virtual void LogWarning(string message, params object[] args)
        {
            logger.Warning(string.Format(message, args));
            WriteWarning(string.Format(message, args));
        }

        /// <summary>
        /// Log: VERBOSE
        /// </summary>
        /// <param name="message"></param>
        /// <param name="args"></param>
        protected virtual void LogVerbose(string message, params object[] args)
        {
            logger.Information(message, args);
            WriteVerbose(string.Format(message, args));
        }
    }
}
