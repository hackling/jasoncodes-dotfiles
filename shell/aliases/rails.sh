alias zs='zeus start'
alias rc='$([ -S .zeus.sock ] && echo zeus console || echo bundle exec pry -r ./config/environment)'
alias rails='$([ -S .zeus.sock ] && echo zeus || echo rails_command)'
alias rs='rails server'
alias rg='rails generate'
alias rgm='rg migration'

zeus() {
  command zeus "$@"
  RETVAL=$?
  stty sane
  return $RETVAL
}

function rails_command
{
  local cmd=$1
  shift

  if [ -e script/rails ]; then
    script/rails "$cmd" "$@"
  elif [ -e "script/$cmd" ]; then
    "script/$cmd" "$@"
  else
    command rails "$cmd" "$@"
  fi
}

function rspec {
  if [ -S .zeus.sock ]; then
    local LAUNCHER='zeus'
  else
    local LAUNCHER='bundle exec'
  fi
  if egrep -q "^ {4}rails \(2\." Gemfile.lock; then
    local CMD='spec'
  else
    local CMD='rspec'
  fi
  if [[ $# == 0 ]]; then
    set -- spec "$@"
  fi
  if [ -z "$RSPEC_FORMAT" ]; then
    local FORMAT=''
  else
    local FORMAT="--format=$RSPEC_FORMAT"
  fi
  (
    [ -n "${ZSH_VERSION:-}" ] && setopt shwordsplit
    exec $LAUNCHER $CMD --color $FORMAT "$@"
  )
}
alias rspec-doc='RSPEC_FORMAT=doc rspec'

function _resolve_spec_files() {
  sed -e 's#^app/##' -e 's#^\([^.]*\)\..*$#spec/\1_spec.rb#' -e 's#^spec/\(spec/.*\)_spec\(_spec\.rb\)$#\1\2#' |
  grep '_spec\.rb$' |
  sort -u |
  xargs find 2> /dev/null
}

function rspec-branch {
  FILES="$(git diff $(git merge-base origin/HEAD HEAD).. --name-only | _resolve_spec_files)"
  if [ -z "$FILES" ]; then
    echo rspec-branch: no changes to test >&2
    return 1
  fi
  if [ -d spec/ratchets ]; then
    FILES="$FILES spec/ratchets"
  fi
  (
    [ -n "${ZSH_VERSION:-}" ] && setopt shwordsplit
    rspec $FILES "$@"
  )
}
alias rspec-branch-doc='RSPEC_FORMAT=doc rspec-branch'

function rspec-work {
  FILES="$(git status --porcelain -z --untracked-files=all | tr '\0' '\n' | cut -c 4- | _resolve_spec_files)"
  if [ -z "$FILES" ]; then
    echo rspec-work: no changes to test >&2
    return 1
  fi
  (
    [ -n "${ZSH_VERSION:-}" ] && setopt shwordsplit
    rspec $FILES "$@"
  )
}
alias rspec-work-doc='RSPEC_FORMAT=doc rspec-work'

function __database_yml {
  if [[ -f config/database.yml ]]; then
    ruby -ryaml -rerb -e "puts YAML::load(ERB.new(IO.read('config/database.yml')).result)['${RAILS_ENV:-development}']['$1']"
  fi
}

function psql
{
  if [[ "$(__database_yml adapter)" == 'postgresql' ]]; then
    PGDATABASE="$(__database_yml database)" command psql "$@"
    return $?
  fi
  command psql "$@"
}
export PSQL_EDITOR='vim +"set syntax=sql"'

function mysql
{
  if [[ $# == 0 && "$(__database_yml adapter)" =~ 'mysql' ]]; then
    mysql -uroot "$(__database_yml database)"
    return $?
  fi
  command mysql "$@"
}
