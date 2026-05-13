FROM docker.elastic.co/elasticsearch/elasticsearch:9.4.0
LABEL org.opencontainers.image.authors="Radovan Šmitala <rado@choco3web.eu>"

ENV HUNSPELL_VERSION=26.2.3.2
ENV LEMMAGEN_VERSION=9.4.0

# Lemmagen lexicons:     github.com/vhyza/lemmagen-lexicons (recommended by the plugin's README)
# Hunspell dictionaries: github.com/LibreOffice/dictionaries (libreoffice-* release tags)
# Per-language list below: <hunspell-locale> <hunspell-path-in-libreoffice-repo> <lemmagen-lang-or-dash>
# Set the third column to "-" when a language has no lemmagen lexicon (de, es, it, pl).
# For those, use the ES built-in language analyzers instead:
#   de -> `german`, es -> `spanish`, it -> `italian` (built-in, no plugin needed)
#   pl -> `polish`     (provided by analysis-stempel,   installed below)
#   uk -> `ukrainian`  (provided by analysis-ukrainian, installed below)
RUN set -eux \
  && elasticsearch-plugin install --batch analysis-icu \
  && elasticsearch-plugin install --batch analysis-stempel \
  && elasticsearch-plugin install --batch analysis-ukrainian \
  && elasticsearch-plugin install --batch \
       "https://github.com/radeno/elasticsearch-analysis-lemmagen/releases/download/${LEMMAGEN_VERSION}/elasticsearch-analysis-lemmagen-${LEMMAGEN_VERSION}-plugin.zip" \
  && HUNSPELL_BASE="https://github.com/LibreOffice/dictionaries/raw/libreoffice-${HUNSPELL_VERSION}" \
  && LEMMAGEN_BASE="https://github.com/vhyza/lemmagen-lexicons/raw/v1.0/free/lexicons" \
  && mkdir config/hunspell config/lemmagen \
  && printf '%s\n' \
       'cs_CZ cs_CZ/cs_CZ cs' \
       'de_DE de/de_DE_frami -' \
       'en_US en/en_US     en' \
       'es_ES es/es_ES     -' \
       'fr_FR fr_FR/fr     fr' \
       'it_IT it_IT/it_IT  -' \
       'pl_PL pl_PL/pl_PL  -' \
       'sk_SK sk_SK/sk_SK  sk' \
     > /tmp/dicts.txt \
  && while read -r locale hunspell_path lemma; do \
       case "${locale}" in ''|\#*) continue ;; esac; \
       mkdir "config/hunspell/${locale}"; \
       curl -fsSL "${HUNSPELL_BASE}/${hunspell_path}.aff" -o "config/hunspell/${locale}/${locale}.aff"; \
       curl -fsSL "${HUNSPELL_BASE}/${hunspell_path}.dic" -o "config/hunspell/${locale}/${locale}.dic"; \
       printf 'ignore_case: true\n' > "config/hunspell/${locale}/settings.yml"; \
       if [ "${lemma}" != "-" ]; then \
         curl -fsSL "${LEMMAGEN_BASE}/${lemma}.lem" -o "config/lemmagen/${lemma}.lem"; \
       fi; \
     done < /tmp/dicts.txt \
  && rm -f /tmp/dicts.txt \
  && echo 'indices.analysis.hunspell.dictionary.lazy: true' >> config/elasticsearch.yml
