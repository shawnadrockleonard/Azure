using System;
using System.Collections.Generic;
using System.Text;

namespace AzQueueProcessor.Common.Models
{
    public class TableLogItem : LogItem
    {
        public string PartitionKey { get; set; }

        public string RowKey { get; set; }

        public string Level { get; set; }

    }
}
