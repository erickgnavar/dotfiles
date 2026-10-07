# Strip prose punctuation, but preserve balanced URL delimiters.
{
  while (length($0)) {
    last = substr($0, length($0), 1)
    if (last !~ /^[.,;:"'`>]$/) {
      if (last == ")") {
        opening = "\\("
        closing = "\\)"
      } else if (last == "]") {
        opening = "\\["
        closing = "\\]"
      } else if (last == "}") {
        opening = "\\{"
        closing = "\\}"
      } else {
        break
      }
      left = right = $0
      if (gsub(closing, "", right) <= gsub(opening, "", left))
        break
    }
    $0 = substr($0, 1, length($0) - 1)
  }
  print
}
