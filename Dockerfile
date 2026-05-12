FROM docker.elastic.co/elasticsearch/elasticsearch:8.19.15
LABEL org.opencontainers.image.authors="Radovan Šmitala <rado@choco3web.eu>"

ENV HUNSPELL_VERSION=26.2.3.2
ENV LEMMAGEN_VERSION=8.19.15

# Lemmagen lexicons:     github.com/vhyza/lemmagen-lexicons (recommended by the plugin's README)
# Hunspell dictionaries: github.com/LibreOffice/dictionaries (libreoffice-* release tags)
# To enable more languages, uncomment one variant per language in the printf list below.
RUN set -eux \
  && elasticsearch-plugin install --batch analysis-icu \
  && elasticsearch-plugin install --batch \
       "https://github.com/radeno/elasticsearch-analysis-lemmagen/releases/download/${LEMMAGEN_VERSION}/elasticsearch-analysis-lemmagen-${LEMMAGEN_VERSION}-plugin.zip" \
  && curl -fsSL "https://github.com/vhyza/lemmagen-lexicons/archive/v1.0.tar.gz" | tar xz \
  && mkdir config/lemmagen \
  && mv lemmagen-lexicons-1.0/free/lexicons/* config/lemmagen/ \
  && rm -rf lemmagen-lexicons-1.0 \
  && HUNSPELL_BASE="https://github.com/LibreOffice/dictionaries/raw/libreoffice-${HUNSPELL_VERSION}" \
  && mkdir config/hunspell \
  && printf '%s\n' \
       'cs_CZ cs_CZ/cs_CZ' \
       'de_DE de/de_DE_frami' \
       'en_US en/en_US' \
       'fr_FR fr_FR/fr' \
       'it_IT it_IT/it_IT' \
       'pl_PL pl_PL/pl_PL' \
       'sk_SK sk_SK/sk_SK' \
     > /tmp/hunspell.txt \
  && while read -r locale path; do \
       case "${locale}" in ''|\#*) continue ;; esac; \
       mkdir "config/hunspell/${locale}"; \
       curl -fsSL "${HUNSPELL_BASE}/${path}.aff" -o "config/hunspell/${locale}/${locale}.aff"; \
       curl -fsSL "${HUNSPELL_BASE}/${path}.dic" -o "config/hunspell/${locale}/${locale}.dic"; \
       printf 'ignore_case: true\n' > "config/hunspell/${locale}/settings.yml"; \
     done < /tmp/hunspell.txt \
  && rm -f /tmp/hunspell.txt \
  && echo 'indices.analysis.hunspell.dictionary.lazy: true' >> config/elasticsearch.yml
