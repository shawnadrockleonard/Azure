using System;
using System.Collections.Generic;
using System.Text;

namespace AzQueueProcessor.Common.Models
{
    public class ManagedCredentials
    {
        public string TenantId { get; set; }
        public string SubscriptionId { get; set; }
        public string ClientId { get; set; }
        public string ClientSecret { get; set; }
    }
}
