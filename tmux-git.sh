# tmux-git
# Script for showing current Git branch in Tmux status bar
#
# Coded by Oliver Etchebarne - http://drmad.org/
#

# Position of the status on tmux bar: left or right
TMUX_STATUS_LOCATION='right'

# Status for when you are out of a repo
TMUX_OUTREPO_STATUS=''

# Function to build the status line. You need to define the $TMUX_STATUS 
# variable.
TMUX_STATUS_DEFINITION() {
    # You can use any tmux status variables, and $GIT_BRANCH, $GIT_DIRTY, 
    # $GIT_FLAGS ( which is an array of flags ), and pretty much any variable
    # used in this script :-)
    
    GIT_BRANCH="`basename $GIT_REPO` | branch: $GIT_BRANCH"
    
    TMUX_STATUS="$GIT_BRANCH$GIT_DIRTY"
    
    if [ ${#GIT_FLAGS[@]} -gt 0 ]; then
        TMUX_STATUS="$TMUX_STATUS [$(IFS=,; echo "${GIT_FLAGS[*]}")]"
    fi

}

### CONFIGURATION ENDS HERE.
### Now let me do the dirty work.

# Taken from http://aaroncrane.co.uk/2009/03/git_branch_prompt/
find_git_repo() {
    local dir=.
    until [ "$dir" -ef / ]; do
        if [ -f "$dir/.git/HEAD" ]; then
            GIT_REPO=`readlink -e $dir`
            return
        fi
        dir="../$dir"
    done
    GIT_REPO=''
    return
}

find_git_branch() {
    head=$(< "$1/.git/HEAD")
    if [[ $head == ref:\ refs/heads/* ]]; then
        GIT_BRANCH=${head#*/*/}
    elif [[ $head != '' ]]; then
        GIT_BRANCH='(detached)'
    else
        GIT_BRANCH='(unknown)'
    fi
}

# Taken from https://github.com/jimeh/git-aware-prompt
find_git_dirty() {
  local status=$(git status --porcelain 2> /dev/null)
  if [[ "$status" != "" ]]; then
    GIT_DIRTY='*'
  else
    GIT_DIRTY=''
  fi
}

find_git_stash() {
    if [ -e "$1/.git/refs/stash" ]; then    
        GIT_STASH='stash'
    else
        GIT_STASH=''
    fi
}

update_tmux() {
    
    # Check for tmux session
    if [ -n "$TMUX" ]; then     

        # This only work if the cwd is outside of the last branch
        CWD=$(readlink -e $(pwd))
        LASTREPO_LEN=${#TMUX_GIT_LASTREPO}
        if [ $TMUX_GIT_LASTREPO ] && [ "$TMUX_GIT_LASTREPO" = "${CWD:0:$LASTREPO_LEN}" ]; then
            GIT_REPO=$TMUX_GIT_LASTREPO
            if $TMUX_GIT_SLOW; then
                tmux set-window-option status-$TMUX_STATUS_LOCATION "Gathering info..." > /dev/null
            fi            

            # Let's check the time spend
            start_time=`date +"%s.%N"`

            find_git_branch $GIT_REPO
            find_git_stash $GIT_REPO
            find_git_dirty
            
            stop_time=`date +"%s.%N"`
            
            # If that spent more than a second, the next time we'll show
            # a message.
            if [ `echo "$stop_time - $start_time > 1" | bc` -eq '1' ]; then
                export TMUX_GIT_SLOW=true
            else
                export TMUX_GIT_SLOW=false
            fi
            
   
            GIT_FLAGS=($GIT_STASH)
            
            TMUX_STATUS_DEFINITION
            
            if [ "$GIT_DIRTY" ]; then 
                tmux set-window-option status-$TMUX_STATUS_LOCATION-attr bright > /dev/null
            else
                tmux set-window-option status-$TMUX_STATUS_LOCATION-attr none > /dev/null
            fi
            
            
            tmux set-window-option status-$TMUX_STATUS_LOCATION "$TMUX_STATUS" > /dev/null            

        else
            find_git_repo
            
            if [ "$GIT_REPO" ]; then
                export TMUX_GIT_LASTREPO=$GIT_REPO
                update_tmux
            else
                tmux set-window-option status-$TMUX_STATUS_LOCATION "$TMUX_OUTREPO_STATUS" > /dev/null
                            
            fi
        fi
        
        export GIT_REPO
    fi
}

tg_checkout() {
    if [ "$GIT_REPO" ]; then 
        tmux split-window -h -l 20
        tmux respawn-pane -k "~/.tmux-git/bin/tg-checkout.py $GIT_REPO"
    fi
}

PROMPT_COMMAND="update_tmux; $PROMPT_COMMAND"
