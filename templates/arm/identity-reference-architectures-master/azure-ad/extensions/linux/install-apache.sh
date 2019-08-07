#
# install-apache.sh
#
#!/bin/bash
apt-get -y update

# install Apache2
apt-get -y install apache2 

# write some HTML
echo \<center\>\<h1\>Reference architecture multiple virtual machines\</h1\>\<br/\>\</center\> > /var/www/html/demo.html

# restart Apache
apachectl restart