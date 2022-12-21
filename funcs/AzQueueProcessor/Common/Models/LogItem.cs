using System;
using System.Collections.Generic;

namespace AzQueueProcessor.Common.Models
{
    public class LogItem
    {
        public string Message { get; set; }

        public string Operation { get; set; }

        public string FileName { get; set; }

        public DateTime EventTimestamp { get; set; }

        public string CustomerID { get; set; }

        public string Tags { get; set; }

        public string ProcessorVersion { get; set; }

        public Guid CorrelationId { get; set; }

        public IList<string> GetTags()
        {
            if (!string.IsNullOrEmpty(Tags))
            {
                return Tags.Split(new char[] { ',' }, StringSplitOptions.RemoveEmptyEntries);
            }

            return new string[] { };
        }
    }
}
