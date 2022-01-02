FROM debian:10


#########
###### docker build -t base-builder-image .
#########

RUN echo 'debconf debconf/frontend select Noninteractive' | debconf-set-selections
RUN apt-get update
RUN apt-get install apt-utils -y
RUN apt-get install apt-transport-https ca-certificates -y 
RUN apt-get install curl gnupg2 software-properties-common -y
RUN apt-get install dialog openssh-client bash -y
RUN apt-get install zip -y

#terraform
ENV APT_KEY_DONT_WARN_ON_DANGEROUS_USAGE=DontWarn 
RUN curl -fsSL https://apt.releases.hashicorp.com/gpg | apt-key add -
RUN apt-add-repository \
    "deb [arch=$(dpkg --print-architecture)] https://apt.releases.hashicorp.com \
	$(lsb_release -cs) \
	main"
	
RUN apt-get update

RUN apt-get install packer=1.7.2 -y
RUN apt-get install terraform=1.1.2 -y










