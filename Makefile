NAME = seafile

aLL: build run tests clean

build:
	docker build -t $(NAME) .
	docker build --build-arg SEAFILE_VERSION=5.1.4 \
		--build-arg SEAFILE_MAJOR=5.1 -t $(NAME):old .

run:
	docker run -d --name seafile_http \
		-p  "80:80" \
		-e SEAFILE_EXTERNAL_PORT=80 \
		-e SEAFILE_HOSTNAME=localhost \
		-e SEAFILE_SERVER_NAME=myseafile \
		-e SEAFILE_ADMIN_MAIL=admin@seafile.com \
		-e SEAFILE_ADMIN_PASSWORD=test123 \
		-v "/tmp/seafile_http:/data" \
		$(NAME)
	sleep 20
	docker run -d --name seafile_old_http \
		-p  "81:80" \
		-e SEAFILE_EXTERNAL_PORT=81 \
		-e SEAFILE_HOSTNAME=localhost \
		-e SEAFILE_SERVER_NAME=myseafile \
		-e SEAFILE_ADMIN_MAIL=admin@seafile.com \
		-e SEAFILE_ADMIN_PASSWORD=test123 \
		-v "/tmp/seafile_old_http:/data" \
		$(NAME):old
	sleep 20
	docker run -d --name seafile_https \
		-p  "443:443" \
		-e SEAFILE_EXTERNAL_PORT=443 \
		-e SEAFILE_HOSTNAME=localhost \
		-e SEAFILE_SERVER_NAME=myseafile \
		-e SEAFILE_ADMIN_MAIL=admin@seafile.com \
		-e SEAFILE_ADMIN_PASSWORD=test123 \
		-e USE_SSL=on \
		-v "/tmp/seafile_https:/data" \
		-v "`pwd`/test/ssl:/etc/ssl" \
		$(NAME)
	sleep 20

tests:
	./test/bats/bats ./test/tests.bats

clean:
	docker rm -f seafile_http \
		seafile_old_http \
		seafile_https
	sudo rm -rf /tmp/seafile_http /tmp/seafile_old_http /tmp/seafile_https
	docker rmi $(NAME) $(NAME):old
