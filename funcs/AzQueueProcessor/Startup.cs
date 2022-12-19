using Microsoft.Azure.Functions.Extensions.DependencyInjection;

[assembly: FunctionsStartup(typeof(AzQueueProcessor.Startup))]

namespace AzQueueProcessor
{
    using AzQueueProcessor.Common.Extensions;
    using AzQueueProcessor.Common.Models;
    using Microsoft.Extensions.Configuration;
    using Microsoft.Extensions.DependencyInjection;
    using System;

    public class Startup : FunctionsStartup
    {
        public override void Configure(IFunctionsHostBuilder builder)
        {
            builder.Services.AddOptions<ManagedCredentials>()
              .Configure<IConfiguration>((settings, configuration) =>
              {
                  Console.WriteLine($"Retreiving configuration values from Azure settings.");
                  configuration.GetSection("Azure").Bind(settings);
              });

            builder.Services.AddSingleton<IManagedIdentityExtensions, ManagedIdentityExtensions>();
        }

        public override void ConfigureAppConfiguration(IFunctionsConfigurationBuilder builder)
        {
            base.ConfigureAppConfiguration(builder);
            if (builder.GetContext().EnvironmentName.Equals("Development"))
            {
                builder.ConfigurationBuilder.AddUserSecrets<Startup>(optional: true, reloadOnChange: false);
            }
            builder.ConfigurationBuilder.AddKeyVault();
        }
    }
}
