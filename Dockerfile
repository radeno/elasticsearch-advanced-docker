FROM docker.elastic.co/elasticsearch/elasticsearch:6.4.1
LABEL maintainer "Radovan Šmitala <rado@choco3web.eu>"
ENV ELASTICSEARCH_VERSION 6.4.1

# Install Plugins
RUN elasticsearch-plugin install https://github.com/vhyza/elasticsearch-analysis-lemmagen/releases/download/v${ELASTICSEARCH_VERSION}/elasticsearch-analysis-lemmagen-${ELASTICSEARCH_VERSION}-plugin.zip --batch \
  && elasticsearch-plugin install analysis-icu --batch \
  && elasticsearch-plugin install ingest-attachment --batch

# ENV HUNSPELL_VERSION 5.3-22

# Install Hunspell
# RUN wget --progress=bar:force https://github.com/LibreOffice/dictionaries/archive/cp-$HUNSPELL_VERSION.tar.gz \
#   && tar -xf cp-$HUNSPELL_VERSION.tar.gz \
#   && mv dictionaries-cp-$HUNSPELL_VERSION config/hunspell \
#   && rm cp-$HUNSPELL_VERSION.tar.gz
