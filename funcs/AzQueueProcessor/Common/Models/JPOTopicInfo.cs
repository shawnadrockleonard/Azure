using Newtonsoft.Json;
using System;
using System.Collections.Generic;
using System.Text;

namespace AzQueueProcessor.Common.Models
{
    public class JPOTopicInfo
    {
        [JsonProperty("correlationId")]
        public Guid CorrelationId { get; set; }

        [JsonProperty("origin")]
        public string Origin { get; set; } = "";

        [JsonProperty("sasUri")]
        public string SasUri { get; set; } = "";

        [JsonProperty("fileName")]
        public string FileName { get; set; } = "";

        [JsonProperty("date")]
        public DateTime MessageDate { get; set; } = DateTime.Now;

        [JsonProperty("description")]
        public string Description { get; set; } = "";

        [JsonProperty("customerID")]
        public string CustomerID { get; set; } = "";
    }
}
