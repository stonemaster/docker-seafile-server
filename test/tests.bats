#
# General startup
#

@test "Checking whether HTTP is up" {
	run curl http://localhost
	[ "$status" -eq 0 ]
}

@test "Checking whether HTTP (old seafile version) is up" {
	run curl http://localhost:81
	[ "$status" -eq 0 ]
}

@test "Checking whether HTTPs is up" {
	run curl -k https://localhost
	[ "$status" -eq 0 ]
}

#
# Login
#

# params:
# - base of service like http://localhost:80
# - username
# - password
# - file to write token to
# return authorization token
login() {
	base="$1"
	username="$2"
	password="$3"
	token_file="$4"
	json=$(curl -k -f -d "username=$username&password=$password" "$base/api2/auth-token/" 2> /tmp/debug-login.txt)
	[[ $? == 0 ]] || exit 1
	token=$(echo $json | jq -r .token)
	echo $token > $token_file
	echo $token
}


@test "Checking login on admin account for HTTP" {
	run login "http://localhost" "admin@seafile.com" "test123" "/tmp/http-token.txt"
	[ "$status" -eq 0 ]
	[ -n "$output" ]
}

@test "Checking invalid login on admin account for HTTP" {
	run login "http://localhost" "admin@seafile.com" "test12" "/tmp/invalid-token.txt"
	[ "$status" -ne 0 ]
}

@test "Checking login on admin account for HTTPS" {
	run login "https://localhost" "admin@seafile.com" "test123" "/tmp/https-token.txt"
	[ "$status" -eq 0 ]
	[ -n "$output" ]
}

#
# File handling
#

# params:
# - base of service like http://localhost:80
# - auth token
# - file to which repository ID is writen
# returns: repository ID
default_repo() {
	base="$1"
	token="$2"
	repo_file="$3"
	json=$(curl -vvvv -k -H "Authorization: Token $token" -f "$base/api2/default-repo/" 2> /tmp/debug-defaultrepo.txt)
	[[ $? == 0 ]] || exit 1
	repo_id=$(echo "$json" | jq -r .repo_id)
	echo $repo_id > $repo_file
	echo $repo_id
}

# params:
# - base of service like http://localhost:80
# - auth token
create_default_repo() {
	base="$1"
	token="$2"
	json=$(curl -vvvv -X POST -k -H "Authorization: Token $token" -f "$base/api2/default-repo/" 2> /tmp/debug-create-defaultrepo.txt)
	[[ $? == 0 ]] || exit 1
	[[ "$(echo $json | jq -r .exists)" == "true" ]] || exit 1
}

# params:
# - base of service like http://localhost:80
# - auth token
# - repo id
# - filename to upload
# - contents of file to upload
upload() {
	base="$1"
	token="$2"
	repo_id="$3"
	filename="$4"
	contents="$5"
	file="/tmp/$filename"
	echo -n "$contents" > $file
	json=$(curl -vvvv -k -H "Authorization: Token $token" -f "$base/api2/repos/$repo_id/upload-link/?p=/" 2> /tmp/debug-upload-api.txt)
	[[ $? == 0 ]] || exit 1
	upload_link=$(echo $json | jq -r .)
	echo $upload_link > /tmp/debug-uploadlink.txt
	curl -vvvv -k -H "Authorization: Token $token" -F file=@$file -F filename=$filename -F parent_dir=/ \
		-f "$upload_link" 2> /tmp/debug-upload-file.txt
}

# params:
# - base of service like http://localhost:80
# - auth token
# - repo id
# - file to download
# - contents of file to compare with
# returns: md5 sum of file to be downloaded
download_and_compare() {
	base="$1"
	token="$2"
	repo_id="$3"
	file="$4"
	content="$5"
	json=$(curl -vvvv -k -H "Authorization: Token $token" -f "$base/api2/repos/$repo_id/file/?p=$file" 2> /tmp/debug-download-api.txt)
	[[ $? == 0 ]] || exit 1
	download_link=$(echo $json | jq -r .)
	echo $download_link > /tmp/debug-downloadlink.txt
	remote_content=$(curl -vvvv -k -H "Authorization: Token $token" -f "$download_link" 2> /tmp/debug-download-file.txt)
	echo -n "$remote_content" > /tmp/debug-download-remote-content.txt
	md5sum=$(echo -n "$remote_content" | md5sum -)
	echo $md5sum > /tmp/debug-download-md5sum.txt
	local_md5sum=$(echo -n $content | md5sum -)
	[[ "$local_md5sum" == "$md5sum" ]] || exit 1
}

@test "Creating default repository (HTTP)" {
	run create_default_repo "http://localhost" $(cat /tmp/http-token.txt)
	[ "$status" -eq 0 ]
}

@test "Checking for default repository (HTTP)" {
	run default_repo "http://localhost" $(cat /tmp/http-token.txt) "/tmp/repo_id.txt"
	[ "$status" -eq 0 ]
	[ -n "$output" ]
}

@test "Uploading test.txt to Default repository (HTTP)" {
	run upload "http://localhost" $(cat /tmp/http-token.txt) $(cat "/tmp/repo_id.txt") "test.txt" "SeafileHTTP"
	[ "$status" -eq 0 ]
	[ -n "$output" ]
}

@test "Downloading test.txt from Default repository (HTTP)" {
	run download_and_compare "http://localhost" $(cat /tmp/http-token.txt) $(cat "/tmp/repo_id.txt") "/test.txt" "SeafileHTTP"
	[ "$status" -eq 0 ]
}

restart_and_check() {
	docker restart seafile_http
	sleep 20
	run login "http://localhost" "admin@seafile.com" "test123" "/tmp/http-token.txt"
	download_and_compare "http://localhost" $(cat /tmp/http-token.txt) $(cat "/tmp/repo_id.txt") "/test.txt" "SeafileHTTP" || exit 1
}

@test "Restarting Seafile (HTTP) and verifying persistence of data" {
	run restart_and_check
	[ "$status" -eq 0 ]
}

#
# Upgrade
#

prepare_old_instance() {
	login "http://localhost:81" "admin@seafile.com" "test123" "/tmp/http-token-old.txt"
	create_default_repo "http://localhost:81" $(cat /tmp/http-token-old.txt)
	default_repo "http://localhost:81" $(cat /tmp/http-token-old.txt) "/tmp/repo_id.txt"
	upload "http://localhost:81" $(cat /tmp/http-token-old.txt) $(cat "/tmp/repo_id.txt") "test_old.txt" "SeafileOldHTTP"
	download_and_compare "http://localhost:81" $(cat /tmp/http-token-old.txt) $(cat "/tmp/repo_id.txt") "/test_old.txt" "SeafileOldHTTP"
}

# stops current and old containers. Replaces the current container's
# data directory by that of the old container. Then restarts the current
# container which should then do the upgrade.
upgrade_old_instance() {
	docker stop seafile_http seafile_old_http > /tmp/debug-upgrade-dockerstop.txt 2>&1
	sudo rm -rfv /tmp/seafile_http/* > /tmp/debug-upgrade-remove.txt 2>&1
	sudo cp -rv /tmp/seafile_old_http/* /tmp/seafile_http > /tmp/debug-upgrade-copy.txt 2>&1
	docker start seafile_http
	sleep 20
}

verify_upgraded_instance() {
	login "http://localhost" "admin@seafile.com" "test123" "/tmp/http-token-upgraded.txt"
	default_repo "http://localhost" $(cat /tmp/http-token-upgraded.txt) "/tmp/repo_id.txt"
	download_and_compare "http://localhost" $(cat /tmp/http-token-upgraded.txt) $(cat "/tmp/repo_id.txt") "/test_old.txt" "SeafileOldHTTP"
}

@test "Preparing old Seafile instance" {
	run prepare_old_instance
	[ "$status" -eq 0 ]
}

@test "Upgrading Seafile instance" {
	run upgrade_old_instance
	[ "$status" -eq 0 ]
}

@test "Verify upgraded instance" {
	run verify_upgraded_instance
	[ "$status" -eq 0 ]
}

