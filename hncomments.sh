#!/bin/bash
#
# Requires: jq, recode, sed, curl, mail
#
# Copyright (c) 2017 John Graham-Cumming

# Name of file in which to store the timestamp of the last comment downloaded
f="$HOME/.hnlast"

# The query string to be found in comments (e.g. q="cloudflare")
q="Cloudflare"

# Email to send found comments to (e.g. e="me@example.com")
e=""

if [[ -e $f ]]
then
  l=$( <$f )
else
  l=0
  touch $f
fi

j=$( curl -s https://hn.algolia.com/api/v1/search_by_date?query=$q&tags=comment&numericFilters=created_at_i\>$l )

if [[ -z $j ]]
then
  # This shouldn't happen.
  # Even if there is not result, the API returns a JSON object along with the query parameters.
  # $j is undefined if the server is unreachable.
  exit
fi

h=$( jq ' .nbHits ' <( echo $j ) )

if [[ $h -eq 0 ]]
then
  # The query result is empty.
  exit 0
else

  t=$( jq ' .hits | .[] | .created_at_i ' <( echo $j ) | sort -rn | head -n 1 )

  grep -q $q $f

  if [[ $? -eq 1 ]]
  then
    # No entry for this query, create one.
    echo "$q|$t" >> $f
  fi

  # We update the existing entry with the latest timestamp
  grep  $q $f | sed -ie "s/|.*/|$t/g" $f
  # As mentioned here http://stackoverflow.com/a/12887319,
  # sed doesn't support case-insensitive matching on OSX.
fi

jq -r '.hits | .[] | .author + "\nhttps://news.ycombinator.com/item?id=" + .objectID + "\n\n" + .comment_text + "\n\n---\n\n"' <(echo $j) | sed -e 's/<[^>]*>/ /g;' | recode -f html..ascii | mail -s "Latest $q HN comments" $e