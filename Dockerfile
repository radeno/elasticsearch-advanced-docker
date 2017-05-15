FROM docker.elastic.co/elasticsearch/elasticsearch:5.4.0
LABEL maintainer "Radovan Šmitala <rado@choco3web.eu>"

RUN elasticsearch-plugin install https://github.com/vhyza/elasticsearch-analysis-lemmagen/releases/download/v5.4.0/elasticsearch-analysis-lemmagen-5.4.0-plugin.zip

CMD ["/bin/bash", "bin/es-docker"]
EXPOSE 9200 9300
