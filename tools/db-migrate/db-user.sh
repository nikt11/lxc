#!/bin/bash
# DB user migration script
# Rootnode, http://rootnode.net
#
# Copyright (C) 2012 Marcin Hlybin
# All rights reserved.
#
# NOTICE
# Remember to set 'default-character-set=utf8' in *.cnf files

# Steps:
# 1. stop mysql_redir in user container
# 2. dump all user databases
# 3. import user databases to db1
# 4. copy grants 
# 5. change mysql_redir configuration
# 6. start mysql_redir

# Configuration
MYSQL_LOCAL="mysql --defaults-file=/root/db-migrate/local.cnf"    
MYSQL_REMOTE="mysql --defaults-file=/root/db-migrate/remote.cnf"
MYSQLDUMP_LOCAL="mysqldump --defaults-file=/root/db-migrate/local.cnf --add-drop-database --skip-comments --disable-keys --no-autocommit"
SSH="/root/db-migrate/remote.sh"

# Get user name from command line
user_name=$1

# Check user name
if [ -z "$user_name" ] 
then
	echo "Usage: $0 USER"
	exit 1
fi

# Get uid
uid=$(lxc uid $user_name)

# Display user info
echo -e "\033[1mProcessing user $user_name ($uid)\033[0m"

# Stop mysql_redir
echo "Stopping mysql_redir..."
lxc ssh $user_name svc -d /etc/service/mysql_redir 2>/dev/null

# Copy all user databases
databases=$( $MYSQL_LOCAL -Nse "show databases like 'my${uid}_%'" )
for database in $databases
do
	echo " * Copying database $database..."
	$MYSQLDUMP_LOCAL -B $database | $MYSQL_REMOTE
done

# Set user grants
users=$( $MYSQL_LOCAL -Nse "SELECT user FROM mysql.user WHERE user LIKE 'my${uid}_%'" )
for user in $users
do
	echo " * Setting grants for $user"
	grants=$( $MYSQL_LOCAL -Nse "SHOW GRANTS FOR '$user'" | tr '\n' ';' )
	echo "$grants" | $MYSQL_REMOTE 
done

# Change redir startup script
echo "Changing mysql_redir startup script..."
cat > /lxc/user/$user_name/rootfs/home/etc/service/mysql_redir/run <<EOF
#!/bin/bash
# Redir for mysql database

MYSQL_HOST='mysql.db1.rootnode.net'
MYSQL_PORT='3306'
LOCAL_PORT='3306'

exec redir --lport=\$LOCAL_PORT --cport=\$MYSQL_PORT --caddr=\$MYSQL_HOST
EOF

# Start mysql_redir
echo "Starting mysql_redir..."
lxc ssh $user_name svc -u /etc/service/mysql_redir 2>/dev/null
