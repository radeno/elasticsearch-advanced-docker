FROM elasticsearch:7.17.16
LABEL maintainer "Radovan Šmitala <rado@choco3web.eu>"
ENV HUNSPELL_VERSION 23.05.7-5
ENV LEMMAGEN_VERSION 7.17.16

# Install Plugins
RUN elasticsearch-plugin install --batch analysis-icu \
  && elasticsearch-plugin install --batch ingest-attachment \
  && elasticsearch-plugin install --batch https://github.com/radeno/elasticsearch-analysis-lemmagen/releases/download/v$LEMMAGEN_VERSION/elasticsearch-analysis-lemmagen-$LEMMAGEN_VERSION-plugin.zip \
  && curl -L -O https://github.com/vhyza/lemmagen-lexicons/archive/v1.0.tar.gz \
  && tar zxf v1.0.tar.gz \
  && mkdir config/lemmagen && mv ./lemmagen-lexicons-1.0/free/lexicons/* config/lemmagen/ \
  && rm -R v1.0.tar.gz ./lemmagen-lexicons-1.0 \
  && curl -L -O https://github.com/LibreOffice/dictionaries/archive/cp-$HUNSPELL_VERSION.tar.gz \
  && tar -xf cp-$HUNSPELL_VERSION.tar.gz \
  && mkdir config/hunspell \
  && { \
  echo "de_AT de/de_AT_frami"; \
  echo "de_CH de/de_CH_frami"; \
  echo "de_DE de/de_DE_frami"; \
  echo "en_AU en/en_AU"; \
  echo "en_CA en/en_CA"; \
  echo "en_GB en/en_GB"; \
  echo "en_US en/en_US"; \
  echo "en_ZA en/en_ZA"; \
  echo "cs_CZ cs_CZ/cs_CZ"; \
  echo "sk_SK sk_SK/sk_SK"; \
  } > /tmp/hunspell.txt \
  && cat /tmp/hunspell.txt | while read line; do \
  localeName=$(echo $line | awk '{print $1}'); \
  localePath=$(echo $line | awk '{print $2}'); \
  mkdir "config/hunspell/${localeName}"; \
  mv "dictionaries-cp-${HUNSPELL_VERSION}/${localePath}.aff" "config/hunspell/${localeName}/${localeName}.aff"; \
  mv "dictionaries-cp-${HUNSPELL_VERSION}/${localePath}.dic" "config/hunspell/${localeName}/${localeName}.dic"; \
  # ls -al "${localeName}"; \
  echo -e "strict_affix_parsing: true\nignore_case: true" > "config/hunspell/${localeName}/settings.yml"; \
  done \
  && rm -R dictionaries-cp-$HUNSPELL_VERSION cp-$HUNSPELL_VERSION.tar.gz
