  ## Deployment Scripts
# whmcs_setup-debian12.sh
whmcs_setup-debian12.sh is a WHMCS Deployment script for Debian 12. Install Debian 12 then run the script after changing yourdomain.com to your domain name. You provide the whmcs.zip

# wordpress_deploy.sh
wordpress_deploy.sh is a Wordpress Deployment script for Debian 12. Install Debian 12 then run the script like in the example below.

`chmod 755 wordpress-autodeploy.sh'
`sudo ./wordpress-autodeploy.sh example.com`

The script will now:

1. Install and configure WordPress
2. Set up the domain name in Apache
3. Install and configure Let's Encrypt SSL
4. Automatically redirect HTTP to HTTPS
5. Save all credentials including the domain name
6. The final output will show the secure HTTPS URL for accessing WordPress.
