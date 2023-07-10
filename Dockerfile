FROM elasticsearch:7.17.9
LABEL maintainer "Radovan Šmitala <rado@choco3web.eu>"
ENV ELASTICSEARCH_VERSION 7.17.9

# Install Plugins
RUN elasticsearch-plugin install --batch analysis-icu \
  && elasticsearch-plugin install --batch ingest-attachment \
  && elasticsearch-plugin install --batch https://github.com/vhyza/elasticsearch-analysis-lemmagen/releases/download/v$ELASTICSEARCH_VERSION/elasticsearch-analysis-lemmagen-$ELASTICSEARCH_VERSION-plugin.zip \
  && curl -L -O https://github.com/vhyza/lemmagen-lexicons/archive/v1.0.tar.gz \
  && tar zxf v1.0.tar.gz \
  && mkdir config/lemmagen && mv ./lemmagen-lexicons-1.0/free/lexicons/* config/lemmagen/ \
  && rm v1.0.tar.gz && rm -R ./lemmagen-lexicons-1.0 \

  # ENV HUNSPELL_VERSION 6.4-37

  # Install Hunspell
  # RUN wget --progress=bar:force https://github.com/LibreOffice/dictionaries/archive/cp-$HUNSPELL_VERSION.tar.gz \
  #   && tar -xf cp-$HUNSPELL_VERSION.tar.gz \
  #   && mv dictionaries-cp-$HUNSPELL_VERSION config/hunspell \
  #   && rm cp-$HUNSPELL_VERSION.tar.gz
