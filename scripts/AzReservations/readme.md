# Reservations
Azure reservations in collaboration with Azure Advisor is a great way to evaluate your run rate, expected cost, and to in turn ensure you are getting the best output for your money.   In this folder are 3 scriptlets which will help download your information into CSV format for later use in your reporting system.

## Prerequesites
You must be a contributor or reader on Reservation Orders.  It is preferred that you are assigned at the Order level so that you can query the orders and reservations assigned to an order.  With the contributor role you can grant access, purchase reservations under the order, or split the order.

### Scriptlets

#### get-reservations.ps1
- AzEnvironment (Options: AzureCloud or AzureUSGovernment)
- CommonParameters (Whatif, Verbose, Debug)

``` posh 

# Will query Reservation Orders for which you have been granted 'Access Policies' reader or higher
    $orders = .\scripts\reservations\get-reservations.ps1 -Verbose

# Will query Reservation Orders for which you have been granted 'Access Policies' reader or higher
# In the Government Cloud
    $orders = .\scripts\reservations\get-reservations.ps1 -AzEnvironment AzureUSGovernment -Verbose

```


#### parse-reservations.ps1
The scriptlet will parse the JSON results from 'get-reservations.ps1'  Please note: if the json file does not exist this will exit the script with a terminating error.  The intent of this script is to parse the JSON from the get-reservation into separate CSV files for consumption in your reporting.
- CommonParameters (Whatif, Verbose, Debug)

``` posh

# Parse the JSON file from the get-reservation.ps1 into 2 separate CSV files for reporting purposes.
    .\scripts\reservations\parse-reservations.ps1 -Verbose

```


#### set-reservations.ps1
The scriptlet will assign permissions to all the Reservations to which you have access policies granted.
- BillingObjectId is the AzureAD object id which can be a User, Group, Service Principal
- CommonParameters (Whatif, Verbose, Debug)

``` posh

# Add the Az role 'owner' to the BillingObjectId
    .\scripts\reservations\set-reservations.ps1 -BillingObjectId <guid> -Verbose

# Add the Az role 'reader' to the BillingObjectId
    .\scripts\reservations\set-reservations.ps1 -BillingObjectId <guid> -ReservationRoleName reader -Verbose 

```