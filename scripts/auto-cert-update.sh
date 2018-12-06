#!/bin/bash

days=$(( ($(date -d "`/home/bitnami/aws-scripts-mon/ssl-cert-info.sh --host blog.blowhorn.com --dates|grep "valid till"| awk '{print $3}'`" +%s) - $(date --utc -d "now" +%s)) / 86400 ));

if [[ $days -le 10 ]];
then
curl -X POST -H 'Content-type: application/json' --data '{"text":"Certificate Expiry for blog.blowhorn.com has reached 10 days, So deploying a new certificate @anand (may expect a minute of Downtime) "}' https://hooks.slack.com/services/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

sudo /opt/bitnami/ctlscript.sh stop
n=$(sudo /opt/bitnami/ctlscript.sh status|grep -c "already running")
if [[ $n -eq 0 ]];
then
	sudo lego --email="anand@blowhorn.net" --domains="blog.blowhorn.com" --path="/etc/lego" run
	if find /etc/lego/certificates/ -type f -cmin -10 -iname "blog.blowhorn.com.key" | grep -q "blog.blowhorn.com.key";
	then
		echo "New Certificate has been created successfully, Deploying it"
	else
		curl - -X POST -H 'Content-type: application/json' --data '{"text":"@anand ERROR: Cannot find new certificates under /etc/lego/certificates/, Aborting the process and starting up the services with old certificate"}' https://hooks.slack.com/services/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
		sudo /opt/bitnami/ctlscript.sh start && curl - -X POST -H 'Content-type: application/json' --data '{"text":"@anand  DEBUG: Services Started, pls take care of certificate deploying process manually"}' https://hooks.slack.com/services/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
		exit 1
	fi
	echo "Swapping the certificates"
	sudo rm /opt/bitnami/apache2/conf/server.crt.old /opt/bitnami/apache2/conf/server.key.old /opt/bitnami/apache2/conf/server.csr.old
	sudo mv /opt/bitnami/apache2/conf/server.crt /opt/bitnami/apache2/conf/server.crt.old
	sudo mv /opt/bitnami/apache2/conf/server.key /opt/bitnami/apache2/conf/server.key.old
	sudo mv /opt/bitnami/apache2/conf/server.csr /opt/bitnami/apache2/conf/server.csr.old
	sudo ln -s /etc/lego/certificates/blog.blowhorn.com.key /opt/bitnami/apache2/conf/server.key
	sudo ln -s /etc/lego/certificates/blog.blowhorn.com.crt /opt/bitnami/apache2/conf/server.crt
	sudo chown root:root /opt/bitnami/apache2/conf/server*
	sudo chmod 600 /opt/bitnami/apache2/conf/server*
	sudo /opt/bitnami/ctlscript.sh start && curl -X POST -H 'Content-type: application/json' --data '{"text":"New certificate has been deployed for blog.blowhorn.com"}' https://hooks.slack.com/services/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
	sudo /opt/bitnami/ctlscript.sh status
else
	curl - -X POST -H 'Content-type: application/json' --data '{"text":"@anand Auto-cert-deployer cannot stop the ctlscript components properly in blog server, please do 'sudo /opt/bitnami/ctlscript.sh status' for more info"}' https://hooks.slack.com/services/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
fi
else
echo "Certificate Expiry for blog.blowhorn.com is $days"
fi
