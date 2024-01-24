IP_GUESS=$(ifconfig | grep 192 | tail -n 1 | awk '{print $2}')
echo "Adding $IP_GUESS to /etc/hosts.  you should edit it if that's wrong"

sudo bash -c "cat << EOF >> /etc/hosts
# ORY Minikube SSO stack
$IP_GUESS    mail.test.info
$IP_GUESS    ory.test.info
EOF"
