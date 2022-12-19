using Newtonsoft.Json;
using System;

namespace AzQueueProcessor.Common.Models
{
    public class JPOFileInfo
    {
        [JsonProperty("correlationid")]
        public Guid CorrelationId { get; set; }

        [JsonProperty("customerid")]
        public string CustomerID { get; set; } = "";

        [JsonProperty("tags")]
        public string Tags { get; set; } = "";

        [JsonProperty("origin")]
        public string Origin { get; set; } = "";

        [JsonProperty("fileName")]
        public string FileName { get; set; } = "";

        [JsonProperty("messagereceivedtimestamp")]
        public string MessageReceivedTimestamp { get; set; } = "";

        [JsonProperty("messagetimestamp")]
        public DateTime MessageDate { get; set; } = DateTime.Now;

        [JsonProperty("description")]
        public string Description { get; set; } = "";

        [JsonProperty("sasuri")]
        public string SasUri { get; set; } = "";

    }
}
