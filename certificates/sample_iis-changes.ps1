.\appcmd.exe set config "Default/serverAuth" -section:system.webServer/security/authentication/iisClientCertificateMappingAuthentication /enabled:"True" /oneToOneCertificateMappingsEnabled:"True"  /commit:apphost
 
.\appcmd.exe set config "Default/serverAuth" -section:system.webServer/security/authentication/iisClientCertificateMappingAuthentication /+"oneToOneMappings.[userName='svg-test',password='---asdfasdf----',certificate='CNlcyxDTj1DbDm']" /commit:apphost
 
.\appcmd.exe set config "Default/serverAuth" -section:system.webServer/security/access /sslFlags:"Ssl, SslNegotiateCert, Ssl128"  /commit:apphost 

iisreset