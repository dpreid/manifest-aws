#!/bin/bash

# serve.sh is a script to help with loading
# and resetting the manifest at
# book.practable.io


export BOOK_SECRET=$(cat ./secret/book.pat)

#https://stackoverflow.com/questions/3601515/how-to-check-if-a-variable-is-set-in-bash
# want to check if it is empty, will always be set, so no +x
if [ -z ${BOOK_SECRET} ]; then
	echo "export BOOK_SECRET before running script";
    exit 1
fi

# pad base64URL encoded to base64
# from https://gist.github.com/angelo-v/e0208a18d455e2e6ea3c40ad637aac53
paddit() {
  input=$1
  l=`echo -n $input | wc -c`
  while [ `expr $l % 4` -ne 0 ]
  do
    input="${input}="
    l=`echo -n $input | wc -c`
  done
  echo $input
}

export BOOKTOKEN_SECRET=$BOOK_SECRET
export BOOKTOKEN_AUDIENCE=https://book.practable.io
export BOOKTOKEN_LIFETIME=86400
export BOOKTOKEN_GROUPS="everyone controls3 develop"
export BOOKTOKEN_ADMIN=true
export BOOKUPLOAD_TOKEN=$(./bin/book token)
echo "Admin token:"
echo ${BOOKUPLOAD_TOKEN}

# read and split the token and do some base64URL translation
read h p s <<< $(echo $BOOKUPLOAD_ADMINTOKEN | tr [-_] [+/] | sed 's/\./ /g')

h=`paddit $h`
p=`paddit $p`
# assuming we have jq installed
echo $h | base64 -d | jq
echo $p | base64 -d | jq

# generate user token
export BOOKTOKEN_ADMIN=false
export USERTOKEN=$(./bin/book token)
export BOOKJS_USERTOKEN=$(./bin/book token)
echo "User token:"
echo ${BOOKJS_USERTOKEN}

# read and split the token and do some base64URL translation
read h p s <<< $(echo $BOOKJS_USERTOKEN | tr [-_] [+/] | sed 's/\./ /g')

h=`paddit $h`
p=`paddit $p`
# assuming we have jq installed
echo $h | base64 -d | jq
echo $p | base64 -d | jq

# manifest upload settings
export BOOKUPLOAD_SCHEME=https
export BOOKUPLOAD_HOST=book.practable.io

#poolstore reset settings
export BOOKRESET_HOST=$BOOKUPLOAD_HOST
export BOOKRESET_SCHEME=$BOOKUPLOAD_SCHEME

# storestatus settings
export BOOKSTATUS_HOST=$BOOKUPLOAD_HOST
export BOOKSTATUS_SCHEME=$BOOKUPLOAD_SCHEME
export BOOKSTATUS_TOKEN=$BOOKUPLOAD_TOKEN

set | grep BOOK


echo "book server at https://book.practable.io"

echo "commands:"
echo "  g: start insecure chrome"
echo "  l: Lock bookings"
echo "  n: uNlock bookings"
echo "  r: reset the poolstore (has confirm)"
echo "  s: get the status of the poolstore)"
echo "  u: re-upload manifest"

for (( ; ; ))
do
	read -p 'What next? [l/n/r/s/u]:' command
if [ "$command" = "g" ];
then
	mkdir -p ~/tmp/chrome-user
	google-chrome --disable-web-security --user-data-dir="~/tmp/chrome-user" > chrome.log 2>&1 &	
elif [ "$command" = "l" ];
then
	export BOOKTOKEN_ADMIN=true
    export BOOKSTATUS_TOKEN=$(./bin/book token)
	read -p 'Enter lock message:' message
	./bin/book setstatus lock "$message"
elif [ "$command" = "n" ];
then
	export BOOKTOKEN_ADMIN=true
    export BOOKSTATUS_TOKEN=$(./bin/book token)
	read -p 'Enter unlock message:' message
	./bin/book setstatus unlock "$message"
elif [ "$command" = "r" ];
then
	export BOOKTOKEN_ADMIN=true
    export BOOKRESET_TOKEN=$(./bin/book token)
    ./bin/book reset
elif [ "$command" = "s" ];
then
	export BOOKTOKEN_ADMIN=true
    export BOOKSTATUS_TOKEN=$(./bin/book token)
	./bin/book getstatus

	status=$(./bin/book getstatus)
	lastbooking=$(echo $status | jq '.last_booking_ends')
    lastdate=$(date -d "@${lastbooking}")

	echo "last booking ends iat: ${lastdate}"
	
elif [ "$command" = "u" ];
then
	read -p "Definitely upload [y/N]?" confirm
	if ([ "$confirm" == "y" ] || [ "$confirm" == "Y" ]  || [ "$confirm" == "yes"  ] );
	then
		export BOOKTOKEN_ADMIN=true
		export BOOKUPLOAD_TOKEN=$(./bin/book token)
		./bin/book upload manifest.yaml
	else
		echo "wise choice, aborting"
	fi
else	
     echo -e "\nUnknown command ${command}."
fi
done


