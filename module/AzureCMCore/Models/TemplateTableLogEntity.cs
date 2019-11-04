using Microsoft.WindowsAzure.Storage.Table;
using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace AzureCMCore.Models
{
    /// <summary>
    /// TemplateTableLogModel class
    /// </summary>
    public class TemplateTableLogModel : TableEntity
    {
        /// <summary>
        /// parameterless constructor
        /// </summary>
        public TemplateTableLogModel() { }

        /// <summary>
        /// Initializes a new instance of the <see cref="TemplateTableLogModel" /> class.
        /// </summary>
        /// <param name="tableRowName">Name of the application.</param>
        public TemplateTableLogModel(string tableRowName)
        {
            this.PartitionKey = tableRowName;
            this.RowKey = tableRowName;
        }

        /// <summary>
        /// Gets or sets the name of the application.
        /// </summary>
        /// <value>
        /// The name of the application.
        /// </value>
        public string LogContent { get; set; }
    }
}
