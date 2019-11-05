﻿using System;
using System.Collections.Generic;
using System.Text;

namespace AzureCMCore
{
    public class DefaultUsageLogger : ITraceLogger
    {
        private readonly Action<Exception, string, object[]> actionError;
        private readonly Action<string, object[]> actionWarning;
        private readonly Action<string, object[]> actionInformation;

        public DefaultUsageLogger()
        {
            actionError = (Exception ex, string arg1, object[] arg2) =>
            {
                System.Diagnostics.Trace.TraceError(arg1, arg2);
            };
            actionWarning = (string arg1, object[] arg2) =>
            {
                System.Diagnostics.Trace.TraceWarning(arg1, arg2);
            };
            actionInformation = (string arg1, object[] arg2) =>
            {
                System.Diagnostics.Trace.TraceInformation(arg1, arg2);
            };

        }

        public DefaultUsageLogger(
            Action<string, object[]> actionInformation,
            Action<string, object[]> actionWarning,
            Action<Exception, string, object[]> actionError)
        {
            this.actionError = actionError;
            this.actionWarning = actionWarning;
            this.actionInformation = actionInformation;
        }

        public void LogError(Exception ex, string format, params object[] args)
        {
            actionError(ex, format, args);
        }

        public void LogWarning(string format, params object[] args)
        {
            actionWarning(format, args);
        }

        public void LogInformation(string format, params object[] args)
        {
            actionInformation(format, args);
        }
    }
}
