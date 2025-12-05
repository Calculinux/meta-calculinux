# Enable bash completion in interactive shells
if [ -n "${BASH_VERSION-}" ] && [ -f /etc/bash_completion ]; then
    . /etc/bash_completion
fi
