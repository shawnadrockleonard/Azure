# client/server certificate information 

# Project includes:

Consumer Application
- .NET WEb Application to act as a proxy
- WPF Application to mimic a client


Service Application
- Sample application with 2 WCF endpoints
- Sample application with 1 ASMX endpoint

Powershell
- Powershell files to automate various portions of the creation and deployment

## Sources

- https://docs.microsoft.com/en-us/previous-versions/windows/it-pro/windows-server-2003/cc736326(v=ws.10)  (CertReq Syntax)
- https://docs.microsoft.com/en-us/previous-versions/windows/it-pro/windows-server-2012-R2-and-2012/dn296456%28v%3dws.11%29 (2012 syntax)
- https://docs.microsoft.com/en-us/previous-versions/windows/it-pro/windows-server-2012-R2-and-2012/dn296456%28v%3dws.11%29#certreq--submit (Submitting via CertReq)
- https://support.microsoft.com/en-us/help/931351/how-to-add-a-subject-alternative-name-to-a-secure-ldap-certificate (How to create a SAN request with CertReq.exe)
- https://www.sslplus.eu/wiki-en/Generating_a_CSR_in_MS_Windows_(using_certreq) (Generating a CSR including SANS)
- https://cryptoreport.websecurity.symantec.com/checker/views/csrCheck.jsp (symantec CSR)

https://www.locktar.nl/programming/webservices/connect-soapui-wcf-service-certificate-authentication/
https://www.youtube.com/watch?v=vzHtJ33cIng



### Generate the WSDL and Service Reference files for C#

svcutil.exe .\WcfSvcUtil\SYSTEMQueryNIEMwcf.wsdl /t:code /l:c# /o:"Reference.cs" /n:*,wcfwebapp.ServiceReference2



### SOAP UI Test Payload

Configure SOAP UI for Client certificate authorization
http://geekswithblogs.net/gvdmaaden/archive/2011/02/24/how-to-configure-soapui-with-client-certificate-authentication.aspx



https://statecli02.shawniq.com/SYSTEMQueryNIEMwcf.svc
text/xml; charset=utf-8

``` xml
<soap:Envelope xmlns:soap="http://www.w3.org/2003/05/soap-envelope" xmlns:tem="http://tempuri.org/" xmlns:wcf="http://schemas.datacontract.org/2004/07/WcfService1">
   <soap:Header xmlns:wsa="http://www.w3.org/2005/08/addressing">
	<wsa:To>https://localhost:44321/SYSTEMQueryNIEMwcf.svc</wsa:To>
</soap:Header>
   <soap:Body>
      <tem:RetrieveQuery>
         <!--Optional:-->
         <tem:SystemQuery>
            <!--Optional:-->
            <wcf:context>soap context</wcf:context>
            <!--Optional:-->
            <wcf:name>shawns test</wcf:name>
         </tem:SystemQuery>
      </tem:RetrieveQuery>
   </soap:Body>
</soap:Envelope>
```
