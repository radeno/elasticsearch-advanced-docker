ARG ELASTICSEARCH_VERSION=9.4.4
ARG OPENNLP_LEMMATIZER_VERSION=v0.3.0

# OpenNLP lemmatizer resources: github.com/radeno/opennlp-lemmatizer
# The plugin ships as a prebuilt release zip, so nothing is compiled here. This stage exists only to
# assemble its models, because `fetch-models.sh` needs python3 + gzip and the Elasticsearch image has
# neither. Three kinds of resource land in /opennlp:
#   <lang>-pos.bin + <lang>-lemmas.bin  official Apache OpenNLP models -> `opennlp_lemmatizer`
#   sk-mte-pos.txt                      MULTEXT-East form/POS/lemma    -> `pos_dictionary_lemmatizer`
#   sk-gender.bin + sk-gender-dict.txt  UPOS+gender POS model + dict   -> `pos_dictionary_lemmatizer`
# The sk-gender pair is a prebuilt release asset (not built from open data here — training it needs
# UDPipe and a large corpus). Its POS model emits a UPOS tagset extended with grammatical gender, so
# with "pos_format":"native" it splits homonyms the Penn-style sk-mte-pos.txt cannot, both readings
# being nouns: `z repy` -> `repa`, where the Penn dictionary yields `rep` (verified on a node here).
# It is net-positive, not a fix-all — upstream measures 13/15 vs Penn's 11/15 on its homonym set, and
# `hrady` -> `hrad` is still missed because the tagger mis-genders it. It costs ~65 MB and still needs
# sk-lemmas.bin as the backoff for unknown forms. Mind the trade-off: the shipped model was trained on
# lowercased text, so it mangles proper nouns the Penn dictionary keeps intact — measured here
# `Bratislava` -> `bratislav` and `Košice` -> `košiec`. So treat it as an alternative sk configuration
# to choose per field, not a drop-in upgrade over sk-mte-pos.txt; both ship, neither is wired up by
# default (the filters are named in index settings, not here).
# OpenNLP publishes models for 36 languages, which covers every language below except hu, so Hungarian
# stays on lemmagen. Its MULTEXT-East dictionary is not worth adding either: at 51k forms it is 18x
# smaller than the Slovak one, and agglutinative Hungarian needs far more forms per lemma, so it
# leaves common inflections untouched (`kertben`, `almákat`) that lemmagen's rules do lemmatize.
# Everything produced here is plain data, so the stage is pinned to $BUILDPLATFORM: on a multi-arch
# build it then runs once natively instead of once per target under qemu, which for the sk-mte-pos
# python pass is the difference between seconds and minutes.
FROM --platform=$BUILDPLATFORM python:3.13-slim AS opennlp-models
ARG OPENNLP_LEMMATIZER_VERSION
ARG OPENNLP_LANGS="cs de en es fr it pl ru sk uk sk-mte-pos sk-gender"
WORKDIR /src
RUN set -eux \
  && apt-get update \
  && apt-get install -y --no-install-recommends ca-certificates curl unzip \
  && rm -rf /var/lib/apt/lists/* \
  && curl -fsSL "https://github.com/radeno/opennlp-lemmatizer/archive/refs/tags/${OPENNLP_LEMMATIZER_VERSION}.tar.gz" \
       | tar -xz --strip-components=1 \
  && for lang in ${OPENNLP_LANGS}; do bash scripts/fetch-models.sh "${lang}" /opennlp; done


FROM docker.elastic.co/elasticsearch/elasticsearch:${ELASTICSEARCH_VERSION}
LABEL org.opencontainers.image.authors="Radovan Šmitala <rado@choco3web.eu>"

ARG ELASTICSEARCH_VERSION
ARG OPENNLP_LEMMATIZER_VERSION
ENV HUNSPELL_VERSION=26.2.5.2
ENV LEMMAGEN_VERSION=9.4.4

# Lemmagen lexicons:     github.com/vhyza/lemmagen-lexicons (recommended by the plugin's README)
# Hunspell dictionaries: github.com/LibreOffice/dictionaries (libreoffice-* release tags)
# Per-language list below: <hunspell-locale> <hunspell-path-in-libreoffice-repo> <lemmagen-lang-or-dash>
# Set the third column to "-" when a language has no lemmagen lexicon (de, es, it, pl, ru, uk).
# For those, use the ES built-in language analyzers instead:
#   de -> `german`, es -> `spanish`, it -> `italian`, ru -> `russian` (built-in, no plugin needed)
#   pl -> `polish`     (provided by analysis-stempel,   installed below)
#   uk -> `ukrainian`  (provided by analysis-ukrainian, installed below)
# Every language except hu also has an OpenNLP model in config/opennlp/ (see the stage above), which
# lemmatizes POS-aware rather than by rule — slower than lemmagen, but it disambiguates homonyms.
# sk additionally gets a POS-aware dictionary there, consulted ahead of the model, plus the
# gender-aware model+dictionary pair for homonyms that only gender tells apart.
RUN set -eux \
  && elasticsearch-plugin install --batch analysis-icu \
  && elasticsearch-plugin install --batch analysis-stempel \
  && elasticsearch-plugin install --batch analysis-ukrainian \
  && elasticsearch-plugin install --batch \
       "https://github.com/radeno/elasticsearch-analysis-lemmagen/releases/download/${LEMMAGEN_VERSION}/elasticsearch-analysis-lemmagen-${LEMMAGEN_VERSION}-plugin.zip" \
  && elasticsearch-plugin install --batch \
       "https://github.com/radeno/opennlp-lemmatizer/releases/download/${OPENNLP_LEMMATIZER_VERSION}/elasticsearch-analysis-opennlp-lemmatizer-${ELASTICSEARCH_VERSION}.zip" \
  && HUNSPELL_BASE="https://github.com/LibreOffice/dictionaries/raw/libreoffice-${HUNSPELL_VERSION}" \
  && LEMMAGEN_BASE="https://github.com/vhyza/lemmagen-lexicons/raw/v1.0/free/lexicons" \
  && mkdir config/hunspell config/lemmagen \
  && printf '%s\n' \
       'cs_CZ cs_CZ/cs_CZ cs' \
       'de_DE de/de_DE_frami -' \
       'en_US en/en_US     en' \
       'es_ES es/es_ES     -' \
       'fr_FR fr_FR/fr     fr' \
       'hu_HU hu_HU/hu_HU  hu' \
       'it_IT it_IT/it_IT  -' \
       'pl_PL pl_PL/pl_PL  -' \
       'ru_RU ru_RU/ru_RU  -' \
       'sk_SK sk_SK/sk_SK  sk' \
       'uk_UA uk_UA/uk_UA  -' \
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

COPY --from=opennlp-models --chown=1000:0 /opennlp/ config/opennlp/
