FROM docker.elastic.co/elasticsearch/elasticsearch:5.4.3
LABEL maintainer "Radovan Šmitala <rado@choco3web.eu>"

# Install Lemmagen
RUN elasticsearch-plugin install https://github.com/vhyza/elasticsearch-analysis-lemmagen/releases/download/v5.4.3/elasticsearch-analysis-lemmagen-5.4.3-plugin.zip

# Install ICU
RUN elasticsearch-plugin install analysis-icu

# Install Hunspell
RUN wget --progress=bar:force https://github.com/LibreOffice/dictionaries/archive/cp-5.3-18.tar.gz \
  && tar -xf cp-5.3-18.tar.gz \
  && mv dictionaries-cp-5.3-18 config/hunspell \
  && rm cp-5.3-18.tar.gz

CMD ["/bin/bash", "bin/es-docker"]
EXPOSE 9200 9300
