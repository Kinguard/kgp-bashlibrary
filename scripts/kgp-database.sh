
export LOGLEVEL=8
export LOGNAME="kgp-database"

# For debug output to stdout
#
#logoutput()
#{
#	echo "$1"
#}

if [ -e /usr/share/kgp-bashlibrary/scripts/kgp-logging.sh ]
then
	source /usr/share/kgp-bashlibrary/scripts/kgp-logging.sh
else
	CURDIR=`realpath $0`
	SB=`dirname $CURDIR`
	if [ -e ${SB}/kgp-logging.sh ]
	then
		source ${SB}/kgp-logging.sh
	else
		# Try local dir as final attempt
		source ./kgp-logging.sh
	fi
fi

log_debug "Loading kgp-database library"

DBCONFDIR=/var/opi/etc
MYSQL=`which mysql`
E_BADARGS=65

#
# Generate (database) config for application
#
# Usage: genconf "appname"
#
genconf()
{
	log_debug "Generate config for $1"
	local EXPECTED_ARGS=1
	local E_BADARGS=65
	local conffile="$1.conf"

	if [ $# -ne $EXPECTED_ARGS ]
	then
		log_err "Usage: $0 appname"
		return $E_BADARGS
	fi

	if [ ! -e $DBCONFDIR/$conffile ]
	then
		DB_PASS=$(pwgen -N1 -s 24)
cat > $DBCONFDIR/$conffile << eof
_DBC_DBUSER_=$1
_DBC_DBPASS_=$DB_PASS
_DBC_DBHOST_=localhost
_DBC_DBNAME_=$1
eof

	fi
}


dbrunning()
{
	pidof -q mysqld
}

#
# Delete database
#
# Usage: dropdb "appname"
#
dropdb()
{
	log_debug "Drop database $1"
	local EXPECTED_ARGS=1

	if ! dbrunning
	then
		log_debug "DB not running"
		return 0
	fi

	if [ $# -ne $EXPECTED_ARGS ]
	then
		log_err "Usage: $0 appname"
		return $E_BADARGS
	fi
	
	if [ -e "$DBCONFDIR/$1.conf" ]
	then
		. $DBCONFDIR/$1.conf
	else
		log_err "Missing configuration"
		return $E_BADARGS
	fi
	
	if [ -z ${_DBC_DBNAME_+x} ]
	then
		log_err "Missing dbname"
		return $E_BADARGS
	fi
	
	if [ -z ${_DBC_DBUSER_+x} ]
	then
		log_err "Missing dbuser"
		return $E_BADARGS
	fi
	
	# Should we really grant usage here?
	local Q0="GRANT USAGE ON *.* TO '$_DBC_DBUSER_'@'localhost';"
	local Q1="DROP DATABASE IF EXISTS $_DBC_DBNAME_;"
	local Q2="DROP USER '$_DBC_DBUSER_'@'localhost';"
	local Q3="FLUSH PRIVILEGES;"
	local SQL="${Q0}${Q1}${Q2}${Q3}"
	
	$MYSQL -uroot -e "$SQL"
}

#
# Create new database for application
#
# Usage: createdb "appname"
#
createdb()
{
	local EXPECTED_ARGS=1

	log_debug "Create database for $1"

	if ! dbrunning
	then
		log_debug "DB not running"
		return 0
	fi

	if [ $# -ne $EXPECTED_ARGS ]
	then
		log_err "Usage: $0 appname"
		return $E_BADARGS
	fi
	
	if [ -e "$DBCONFDIR/$1.conf" ]
	then
		. $DBCONFDIR/$1.conf
	else
		log_err "Missing configuration"
		return $E_BADARGS
	fi
	
	if [ -z ${_DBC_DBNAME_+x} ]
	then
		log_err "Missing dbname"
		return $E_BADARGS
	fi
	
	if [ -z ${_DBC_DBUSER_+x} ]
	then
		log_err "Missing dbuser"
		return $E_BADARGS
	fi
	
	if [ -z ${_DBC_DBPASS_+x} ]
	then
		log_err "Missing db password"
		return $E_BADARGS
	fi
	
	local Q1="CREATE DATABASE IF NOT EXISTS $_DBC_DBNAME_;"
	local Q2="GRANT ALL ON $_DBC_DBNAME_.* TO '$_DBC_DBUSER_'@'localhost' IDENTIFIED BY '$_DBC_DBPASS_';"
	local Q3="FLUSH PRIVILEGES;"
	local SQL="${Q1}${Q2}${Q3}"
	
	$MYSQL -uroot -e "$SQL"
}


#
# Update/sync user password for db from config
#
# Usage updateuser "appname"
#
updateuser()
{
	log_debug "Synchronize password for $1"
	local EXPECTED_ARGS=1

	if ! dbrunning
	then
		log_debug "DB not running"
		return 0
	fi

	if [ $# -ne $EXPECTED_ARGS ]
	then
		log_err "Usage: $0 appname"
		return $E_BADARGS
	fi
	
	if [ -e "$DBCONFDIR/$1.conf" ]
	then
		. $DBCONFDIR/$1.conf
	else
		log_err "Missing configuration"
		return $E_BADARGS
	fi

	log_debug "Updating password for $_DBC_DBUSER_ on db $_DBC_DBNAME_"
	
	local query
read -d '' query << EOF
SET PASSWORD FOR '$_DBC_DBUSER_'@'localhost' = PASSWORD("$_DBC_DBPASS_");
FLUSH PRIVILEGES;
EOF
	
	#echo "Query: $query"
	
	$MYSQL -uroot -e "$query"
}
