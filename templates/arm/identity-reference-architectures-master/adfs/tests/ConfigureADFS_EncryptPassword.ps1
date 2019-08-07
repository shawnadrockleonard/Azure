$Key = (7,4,2,3,56,35,254,252,1,9,2,32,42,45,33,233,1,34,123,7,6,53,35,143)

$AdminSecurePassword = ConvertTo-SecureString AweS0me@PW -AsPlainText -Force 
ConvertFrom-SecureString $AdminSecurePassword -Key $key > adminpass.key

$ADFSSecurePassword = ConvertTo-SecureString 6BDdgAy7KkbmEuo7s7WP -AsPlainText -Force 
ConvertFrom-SecureString $ADFSSecurePassword -Key $key > adfspass.key