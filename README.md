  ## Deployment Scripts
# whmcs_setup-debian12.sh
whmcs_setup-debian12.sh is a WHMCS Deployment script for Debian 12. Install Debian 12 then run the script after changing yourdomain.com to your domain name. You provide the whmcs.zip

# wordpress_deploy.sh
wordpress_deploy.sh is a Wordpress Deployment script for Debian 12. Install Debian 12 then run the script like in the example below.

`sudo ./wordpress-autodeploy.sh example.com`
1. The script will now:
2. Install and configure WordPress
3. Set up the domain name in Apache
4. Install and configure Let's Encrypt SSL
5. Automatically redirect HTTP to HTTPS
6. Save all credentials including the domain name
7. The final output will show the secure HTTPS URL for accessing WordPress.
