cat << EOT >> ~/.ssh/config

Host ${hostname}
     HostName ${hostname}
     User ${user}
     IdentityFile ${identityfile}
EOT