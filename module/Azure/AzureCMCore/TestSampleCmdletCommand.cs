using AzureCMCore.Base;
using System;
using System.Management.Automation;
using System.Management.Automation.Internal;
using System.Management.Automation.Runspaces;

namespace AzureCMCore
{
    [Cmdlet(VerbsDiagnostic.Test,"SampleCmdlet")]
    [CmdletHelpAttribute("Sample Cmdlet")]
    [OutputType(typeof(FavoriteStuff))]
    public class TestSampleCmdletCommand : AzureCmdlet
    {
        [Parameter(
            Mandatory = true,
            Position = 0,
            ValueFromPipeline = true,
            ValueFromPipelineByPropertyName = true)]
        public int FavoriteNumber { get; set; }

        [Parameter(
            Position = 1,
            ValueFromPipelineByPropertyName = true)]
        [ValidateSet("Cat", "Dog", "Horse")]
        public string FavoritePet { get; set; } = "Dog";



        // This method will be called for each input received from the pipeline to this cmdlet; if no input is received, this method is not called
        protected override void ProcessRecord()
        {
            base.ProcessRecord();

            WriteObject(new FavoriteStuff { 
                FavoriteNumber = FavoriteNumber,
                FavoritePet = FavoritePet
            });
        }

    }

    public class FavoriteStuff
    {
        public int FavoriteNumber { get; set; }
        public string FavoritePet { get; set; }
    }
}
