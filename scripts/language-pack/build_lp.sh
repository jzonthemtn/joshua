#!/bin/bash

# This script assembles a language pack.
# 

langpair=$1
config=$2
mem=$3
credits=$4
benchmark=$5
example=$6

date=$(date +%Y-%m-%d)

if [[ -z $6 ]]; then
    echo "Usage: $0 langpair config mem credits-file benchmark-file example"
    echo "where"
    echo "  langpair is the language pair, (e.g., es-en)"
    echo "  config is the tuned Joshua config, (1/tune/joshua.config.final)"
    echo "  mem is the amount of memory the decoder needs"
    echo "  credits-file is a file describing how the model was built (1/CREDITS"
    echo "  benchmark-file is a file describing model performance on test sets (1/BENCHMARK)"
    echo "  example is a path prefix to a pair of small (~10 lines) example files"
    exit 1
fi

set -u
set -e

JOSHUA=$(dirname $0)/../..
ISO=$JOSHUA/scripts/misc/iso639
date=$(date +%Y-%m-%d)
dest=releases/apache-joshua-$langpair-$date
source_abbr=$(echo $langpair | cut -d- -f1)
target_abbr=$(echo $langpair | cut -d- -f2)
source=$($ISO $source_abbr)
target=$($ISO $target_abbr)

# Create the jar file
(cd $JOSHUA && mvn clean compile assembly:single)

# Create the bundle
# ... --copy-config-options "-lower-case true -project-case true"
$JOSHUA/scripts/language-pack/copy_model.py \
    --force \
    --verbose \
    --mem $mem \
    --copy-config-options \
      '-top-n 1 -output-format %S -mark-oovs false -lower-case -project-case' \
    $config \
    $dest

copy_template() {
  cat $1 \
    | perl -pe "s/<SOURCE>/$source/g" \
    | perl -pe "s/<TARGET>/$target/g" \
    | perl -pe "s/<SRC>/$source_abbr/g" \
    | perl -pe "s/<TRG>/$target_abbr/g" \
    | perl -pe "s/<MEM>/$mem/g" \
    | perl -pe "s/<DATE>/$date/g" \
    > $2
}

# Create the target directory
[[ ! -d "$dest/target" ]] && mkdir -p "$dest/target"

# Copy over critical infrastructure files
cp $JOSHUA/target/joshua-*-jar-with-dependencies.jar $dest/target

# Copy over the example files
for ext in $source_abbr $target_abbr; do
    [[ ! -s $example.$ext ]] && echo "Can't find example file $example.$ext, quitting" && exit
    cp $example.$ext $dest/example.$ext
    chmod 444 $dest/example.$ext
done

# Copy over the web demonstration
cp -a $JOSHUA/demo $dest/web

# Copy over preprocessing scripts
cp -a $JOSHUA/scripts/preparation $dest/scripts
copy_template "$JOSHUA/scripts/language-pack/prepare.sh" "$dest/prepare.sh"
chmod 555 $dest/prepare.sh

# Copy the credits file
cat $credits > $dest/CREDITS
chmod 444 $dest/CREDITS

# Summarize test set performance for the README
cat $benchmark > $dest/BENCHMARK
chmod 444 $dest/BENCHMARK

# Create the README
copy_template "$JOSHUA/scripts/language-pack/README.template" "$dest/README"
chmod 444 $dest/README
