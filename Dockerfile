FROM nginx
MAINTAINER John Boero <jboero@hashicorp.com>
RUN apt-get -y update; apt install -y curl jq
COPY run.sh /
CMD ["/run.sh"]
