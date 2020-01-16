using System;
using System.Management.Automation;

namespace PemCore
{
    [Cmdlet(VerbsCommon.Get, "HelloWorld")]
    public class GetHelloWorld : Cmdlet
    {
        private string _name;
        [Parameter(Mandatory = true)]
        public string Name
        {
            get { return _name; }
            set { _name = value; }
        }
        protected override void ProcessRecord()
        {
            WriteObject("Hey " + this.Name);
        }
    }
}
